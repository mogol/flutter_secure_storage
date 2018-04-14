package com.it_nomads.fluttersecurestorage;

import android.app.Activity;
import android.content.Context;
import android.util.Base64;
import android.util.Log;

import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher18Implementation;

import java.nio.charset.Charset;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class FlutterSecureStoragePlugin implements MethodCallHandler {

  private final android.content.SharedPreferences preferences;
  private final android.content.SharedPreferences.Editor editor;
  private final Charset charset;
  private final StorageCipher storageCipher;

  public static void registerWith(Registrar registrar) {
    try {
      FlutterSecureStoragePlugin plugin = new FlutterSecureStoragePlugin(registrar.activity());
      final MethodChannel channel = new MethodChannel(registrar.messenger(), "plugins.it_nomads.com/flutter_secure_storage");
      channel.setMethodCallHandler(plugin);
    } catch (Exception e) {
      Log.e("FlutterSecureStoragePl", "Registration failed", e);
    }
  }

  private FlutterSecureStoragePlugin(Activity activity) throws Exception {
    preferences = activity.getSharedPreferences(Constants.SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
    editor = preferences.edit();
    charset = Charset.forName("UTF-8");
    storageCipher = new StorageCipher18Implementation(activity);
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    try {
      Map arguments = (Map) call.arguments;
      String rawKey = (String) arguments.get("key");
      String key = addPrefixToKey(rawKey);

      switch (call.method) {
        case "write": {
          String value = (String) arguments.get("value");
          write(key, value);
          result.success(null);
          break;
        }
        case "read": {
          String value = read(key);
          result.success(value);
          break;
        }
        case "delete": {
          delete(key);
          result.success(null);
          break;
        }
        default:
          result.notImplemented();
          break;
      }

    } catch (Exception e) {
      result.error("Exception encountered", call.method, e);
    }
  }

  private void write(String key, String value) throws Exception {
    byte[] result = storageCipher.encrypt(value.getBytes(charset));
    editor.putString(key, Base64.encodeToString(result, 0));
    editor.apply();
  }

  private String read(String key) throws Exception {
    String encoded = preferences.getString(key, null);
    if (encoded == null) {
      return null;
    }

    byte[] data = Base64.decode(encoded, 0);
    byte[] result = storageCipher.decrypt(data);

    return new String(result, charset);
  }

  private void delete(String key) throws Exception {
    editor.remove(key);
    editor.apply();
  }

  private String addPrefixToKey(String key) {
    return Constants.ELEMENT_KEY_PREFIX + "_" + key;
  }
}
