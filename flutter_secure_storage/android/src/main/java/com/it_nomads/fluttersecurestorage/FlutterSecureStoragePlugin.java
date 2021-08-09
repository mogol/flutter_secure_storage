package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;

import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher18Implementation;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.charset.Charset;
import java.security.GeneralSecurityException;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class FlutterSecureStoragePlugin implements MethodCallHandler, FlutterPlugin {

    private static final String TAG = "FlutterSecureStoragePl";

    private MethodChannel channel;
    private SharedPreferences preferences;
    private Charset charset;
    private StorageCipher storageCipher;
    // Necessary for deferred initialization of storageCipher.
    private Context applicationContext;
    private HandlerThread workerThread;
    private Handler workerThreadHandler;

    private static final String ELEMENT_PREFERENCES_KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";
    private static final String SHARED_PREFERENCES_NAME = "FlutterSecureStorage";

    private boolean useEncryptedSharedPreferences = false;
    private boolean resetOnError = false;

    public void initInstance(BinaryMessenger messenger, Context context) {
      try {
          applicationContext = context.getApplicationContext();
          preferences = context.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
          charset = Charset.forName("UTF-8");

          workerThread = new HandlerThread("com.it_nomads.fluttersecurestorage.worker");
          workerThread.start();
          workerThreadHandler = new Handler(workerThread.getLooper());

          StorageCipher18Implementation.moveSecretFromPreferencesIfNeeded(preferences, context);

          channel = new MethodChannel(messenger, "plugins.it_nomads.com/flutter_secure_storage");
          channel.setMethodCallHandler(this);
      } catch (Exception e) {
          Log.e(TAG, "Registration failed", e);
      }
    }

    @SuppressWarnings("unchecked")
    private void ensureInitialized(Map<String, Object> arguments) {
        Map<String, Object> options = (Map<String, Object>) arguments.get("options");
        if (options != null) {
            useEncryptedSharedPreferences = useEncryptedSharedPreferences(options);
            resetOnError = resetOnError(options);
            if(useEncryptedSharedPreferences &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.M){
                if(!(preferences instanceof EncryptedSharedPreferences)){
                    try {
                        preferences = createEncryptedSharedPreferences(applicationContext);
                    } catch (Exception e){
                        Log.e("FlutterSecureStoragePl", "EncryptedSharedPreferences initialization failed", e);
                    }
                }
            }
        }

        if (storageCipher == null && !useEncryptedSharedPreferences) {
            try {
                storageCipher = new StorageCipher18Implementation(applicationContext);
            } catch (Exception e) {
                Log.e(TAG, "StorageCipher initialization failed", e);
            }
        }
    }

    private boolean resetOnError(Map<String, Object> arguments) {
        return arguments.containsKey("resetOnError") && arguments.get("resetOnError").equals("true");
    }

    private boolean useEncryptedSharedPreferences(Map<String, Object> arguments) {
        return arguments.containsKey("encryptedSharedPreferences") && arguments.get("encryptedSharedPreferences").equals("true");
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    private SharedPreferences createEncryptedSharedPreferences(Context context) throws GeneralSecurityException, IOException {
        MasterKey key = new MasterKey.Builder(context)
                .setKeyGenParameterSpec(
                        new KeyGenParameterSpec
                                .Builder(MasterKey.DEFAULT_MASTER_KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                                .setKeySize(256).build())
                .build();
        return EncryptedSharedPreferences.create(context, SHARED_PREFERENCES_NAME, key, EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM);
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
      initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
      if (channel != null) {
        workerThread.quitSafely();
        workerThread = null;

        channel.setMethodCallHandler(null);
        channel = null;
      }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result rawResult) {
        MethodResultWrapper result = new MethodResultWrapper(rawResult);
        // Run all method calls inside the worker thread instead of the platform thread.
        workerThreadHandler.post(new MethodRunner(call, result));
    }

    @SuppressWarnings("unchecked")
    private String getKeyFromCall(MethodCall call) {
        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
        String rawKey = (String) arguments.get("key");
        return addPrefixToKey(rawKey);
    }

    @SuppressWarnings("unchecked")
    private Map<String, String> readAll(boolean useEncryptedSharedPreference) throws Exception {
        Map<String, String> raw = (Map<String, String>) preferences.getAll();

        Map<String, String> all = new HashMap<>();
        for (Map.Entry<String, String> entry : raw.entrySet()) {
            String key = entry.getKey().replaceFirst(ELEMENT_PREFERENCES_KEY_PREFIX + '_', "");

            if (useEncryptedSharedPreference) {
                all.put(key, entry.getValue());
            } else {
                String rawValue = entry.getValue();
                String value = decodeRawValue(rawValue);

                all.put(key, value);
            }
        }
        return all;
    }

    private void deleteAll() {
        SharedPreferences.Editor editor = preferences.edit();

        editor.clear();
        editor.apply();
    }

    private void write(String key, String value, boolean useEncryptedSharedPreference) throws Exception {
        SharedPreferences.Editor editor = preferences.edit();

        if(useEncryptedSharedPreference){
            editor.putString(key, value);
        } else {
            byte[] result = storageCipher.encrypt(value.getBytes(charset));
            editor.putString(key, Base64.encodeToString(result, 0));
        }
        editor.apply();
    }

    private String read(String key, boolean useEncryptedSharedPreference) throws Exception {
        String rawValue = preferences.getString(key, null);
        if(useEncryptedSharedPreference){
            return rawValue;
        }
        return decodeRawValue(rawValue);
    }

    private void delete(String key) {
        SharedPreferences.Editor editor = preferences.edit();
        editor.remove(key);
        editor.apply();
    }

    private String addPrefixToKey(String key) {
        return ELEMENT_PREFERENCES_KEY_PREFIX + "_" + key;
    }

    private String decodeRawValue(String value) throws Exception {
        if (value == null) {
            return null;
        }
        byte[] data = Base64.decode(value, 0);
        byte[] result = storageCipher.decrypt(data);

        return new String(result, charset);
    }

    /**
     * Wraps the functionality of onMethodCall() in a Runnable for execution in the worker thread.
     */
    class MethodRunner implements Runnable {
        private final MethodCall call;
        private final Result result;

        MethodRunner(MethodCall call, Result result) {
            this.call = call;
            this.result = result;
        }

        @Override
        @SuppressWarnings("unchecked")
        public void run() {
            try {
                switch (call.method) {
                    case "write": {
                        String key = getKeyFromCall(call);
                        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
                        ensureInitialized(arguments);
                        String value = (String) arguments.get("value");
                        if (value != null) {
                            write(key, value, useEncryptedSharedPreferences);
                            result.success(null);
                        } else {
                            result.error("null", null, null);
                        }
                        break;
                    }
                    case "read": {
                        String key = getKeyFromCall(call);
                        Map<String, Object> arguments = (Map<String, Object>) call.arguments;

                        if (preferences.contains(key)) {
                            ensureInitialized(arguments);
                            String value = read(key, useEncryptedSharedPreferences);
                            result.success(value);
                        } else {
                            result.success(null);
                        }
                        break;
                    }
                    case "readAll": {
                        Map<String, Object> arguments = (Map<String, Object>) call.arguments;
                        ensureInitialized(arguments);

                        Map<String, String> value = readAll(useEncryptedSharedPreferences);
                        result.success(value);
                        break;
                    }
                    case "containsKey": {
                        String key = getKeyFromCall(call);

                        boolean containsKey = preferences.contains(key);
                        result.success(containsKey);
                        break;
                    }
                    case "delete": {
                        String key = getKeyFromCall(call);

                        delete(key);
                        result.success(null);
                        break;
                    }
                    case "deleteAll": {
                        deleteAll();
                        result.success(null);
                        break;
                    }
                    default:
                        result.notImplemented();
                        break;
                }

            } catch (Exception e) {
                if (resetOnError) {
                    deleteAll();
                    result.success("Data has been reset");
                } else {
                    StringWriter stringWriter = new StringWriter();
                    e.printStackTrace(new PrintWriter(stringWriter));
                    result.error("Exception encountered", call.method, stringWriter.toString());
                }
            }
        }
    }

    /**
     * MethodChannel.Result wrapper that responds on the platform thread.
     */
    static class MethodResultWrapper implements Result {

        private final Result methodResult;
        private final Handler handler = new Handler(Looper.getMainLooper());

        MethodResultWrapper(Result methodResult) {
            this.methodResult = methodResult;
        }

        @Override
        public void success(final Object result) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    methodResult.success(result);
                }
            });
        }

        @Override
        public void error(final String errorCode, final String errorMessage, final Object errorDetails) {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    methodResult.error(errorCode, errorMessage, errorDetails);
                }
            });
        }

        @Override
        public void notImplemented() {
            handler.post(new Runnable() {
                @Override
                public void run() {
                    methodResult.notImplemented();
                }
            });
        }
    }
}
