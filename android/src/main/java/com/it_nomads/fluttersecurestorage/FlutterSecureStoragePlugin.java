package com.it_nomads.fluttersecurestorage;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Log;

import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;


import java.io.PrintWriter;
import java.io.StringWriter;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

@SuppressLint("ApplySharedPref")
public class FlutterSecureStoragePlugin implements MethodCallHandler, FlutterPlugin {

    private MethodChannel channel;
    private SharedPreferences preferences;
    private HandlerThread workerThread;
    private Handler workerThreadHandler;

    private static final String SHARED_PREFERENCES_NAME = "FlutterSecureStorage";

    public static void registerWith(Registrar registrar) {
        FlutterSecureStoragePlugin instance = new FlutterSecureStoragePlugin();
        instance.initInstance(registrar.messenger(), registrar.context());
    }

    public void initInstance(BinaryMessenger messenger, Context context) {
        try {
            MasterKey key = new MasterKey.Builder(context)
                    .setKeyGenParameterSpec(
                            new KeyGenParameterSpec
                                    .Builder(MasterKey.DEFAULT_MASTER_KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                                    .setKeySize(256).build())
                    .build();
            preferences = EncryptedSharedPreferences.create(context, SHARED_PREFERENCES_NAME, key, EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM);

            workerThread = new HandlerThread("com.it_nomads.fluttersecurestorage.worker");
            workerThread.start();
            workerThreadHandler = new Handler(workerThread.getLooper());


            channel = new MethodChannel(messenger, "plugins.it_nomads.com/flutter_secure_storage");
            channel.setMethodCallHandler(this);
        } catch (Exception e) {
            Log.e("FlutterSecureStoragePl", "Registration failed", e);
        }
    }


    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (channel != null) {
            workerThread.quitSafely();
            workerThread = null;

            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    public void onMethodCall(MethodCall call, Result rawResult) {
        MethodResultWrapper result = new MethodResultWrapper(rawResult);
        // Run all method calls inside the worker thread instead of the platform thread.
        workerThreadHandler.post(new MethodRunner(call, result));
    }

    private String getKeyFromCall(MethodCall call) {
        Map arguments = (Map) call.arguments;
        return (String) arguments.get("key");
    }

    @SuppressWarnings("unchecked")
    private Map<String, String> readAll() {
        return (Map<String, String>) preferences.getAll();
    }

    private void deleteAll() {
        SharedPreferences.Editor editor = preferences.edit();

        editor.clear();
        editor.commit();
    }

    private void write(String key, String value) {
        SharedPreferences.Editor editor = preferences.edit();
        editor.putString(key, value);
        editor.apply();
    }

    private String read(String key) {
        return preferences.getString(key, null);
    }

    private void delete(String key) {
        SharedPreferences.Editor editor = preferences.edit();

        editor.remove(key);
        editor.commit();
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
        public void run() {
            try {
                switch (call.method) {
                    case "write": {
                        String key = getKeyFromCall(call);
                        Map arguments = (Map) call.arguments;

                        String value = (String) arguments.get("value");
                        write(key, value);
                        result.success(null);
                        break;
                    }
                    case "read": {
                        String key = getKeyFromCall(call);

                        String value = read(key);
                        result.success(value);
                        break;
                    }
                    case "readAll": {
                        Map<String, String> value = readAll();
                        result.success(value);
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
                StringWriter stringWriter = new StringWriter();
                e.printStackTrace(new PrintWriter(stringWriter));
                result.error("Exception encountered", call.method, stringWriter.toString());
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
