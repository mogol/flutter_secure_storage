package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Log;

import androidx.annotation.NonNull;
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

public class FlutterSecureStoragePlugin implements MethodCallHandler, FlutterPlugin {

    private static final String TAG = "FlutterSecureStoragePl";
    private static final String SHARED_PREFERENCES_NAME = "FlutterSecureStorage";

    private MethodChannel channel;
    private SharedPreferences preferences;

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

            channel = new MethodChannel(messenger, "plugins.it_nomads.com/flutter_secure_storage");
            channel.setMethodCallHandler(this);
        } catch (Exception e) {
            Log.e(TAG, "Registration failed", e);
        }
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        initInstance(binding.getBinaryMessenger(), binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    @SuppressWarnings("unchecked")
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            Map<String, Object> arguments = (Map<String, Object>) call.arguments;
            switch (call.method) {
                case "write": {
                    String key =  (String) arguments.get("key");
                    String value = (String) arguments.get("value");

                    if (value != null) {
                        preferences.edit().putString(key,value).apply();
                        result.success(null);
                    } else {
                        result.error("null", null, null);
                    }
                    break;
                }
                case "read": {
                    String key = (String) arguments.get("key");

                    if (preferences.contains(key)) {
                        String value = preferences.getString(key, null);
                        result.success(value);
                    } else {
                        result.success(null);
                    }
                    break;
                }
                case "readAll": {
                    Map<String, String> value = (Map<String, String>) preferences.getAll();
                    result.success(value);
                    break;
                }
                case "containsKey": {
                    String key = (String) arguments.get("key");
                    boolean containsKey = preferences.contains(key);
                    result.success(containsKey);
                    break;
                }
                case "delete": {
                    String key = (String) arguments.get("key");

                    preferences.edit().remove(key).apply();
                    result.success(null);
                    break;
                }
                case "deleteAll": {
                    preferences.edit().clear().apply();

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

