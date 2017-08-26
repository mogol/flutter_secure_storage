package com.it_nomads.fluttersecurestorage;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.security.KeyPairGeneratorSpec;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.util.Log;

import java.math.BigInteger;
import java.nio.charset.Charset;
import java.security.InvalidAlgorithmParameterException;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.NoSuchAlgorithmException;
import java.security.NoSuchProviderException;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.spec.AlgorithmParameterSpec;
import java.security.spec.RSAKeyGenParameterSpec;
import java.util.Calendar;
import java.util.Map;

import javax.crypto.Cipher;
import javax.security.auth.x500.X500Principal;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

public class FlutterSecureStoragePlugin implements MethodCallHandler {
  private static final String SHARED_PREFERENCES_NAME = "FlutterSecureStorage";
  private static final String KEY_ALIAS = "FlutterSecureStoragePluginKey";
  private static final String KEYSTORE_PROVIDER_ANDROID_KEYSTORE = "AndroidKeyStore";
  private static final String TYPE_RSA = "RSA";
  private static final String KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";

  private final android.content.SharedPreferences preferences;
  private final android.content.SharedPreferences.Editor editor;
  private final Charset charset;

  public static void registerWith(Registrar registrar) {
    try {
      FlutterSecureStoragePlugin plugin = new FlutterSecureStoragePlugin(registrar.activity());
      createKeysIfNeeded(registrar.activity());

      final MethodChannel channel = new MethodChannel(registrar.messenger(), "plugins.it_nomads.com/flutter_secure_storage");
      channel.setMethodCallHandler(plugin);
    } catch (Exception e) {
      Log.e("FlutterSecureStoragePl", "Registration failed", e);
    }
  }

  private FlutterSecureStoragePlugin(Activity activity) throws InvalidAlgorithmParameterException, NoSuchAlgorithmException, NoSuchProviderException {
    preferences = activity.getSharedPreferences(SHARED_PREFERENCES_NAME, Context.MODE_PRIVATE);
    editor = preferences.edit();
    charset = Charset.forName("UTF-8");
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
          result.success("success");
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
    byte[] result = encrypt(value.getBytes(charset));
    editor.putString(key, Base64.encodeToString(result, 0));
    editor.apply();
  }

  private String read(String key) throws Exception {
    String encoded = preferences.getString(key, null);
    if (encoded == null) {
      return null;
    }

    byte[] data = Base64.decode(encoded, 0);
    byte[] result = decrypt(data);

    return new String(result, charset);
  }

  private void delete(String key) throws Exception {
    editor.remove(key);
    editor.apply();
  }

  private byte[] encrypt(byte[] input) throws Exception {
    PublicKey publicKey = getEntry().getCertificate().getPublicKey();
    Cipher cipher = getCipher();
    cipher.init(Cipher.ENCRYPT_MODE, publicKey);

    return cipher.doFinal(input);
  }

  private byte[] decrypt(byte[] input) throws Exception {
    PrivateKey privateKey = getEntry().getPrivateKey();
    Cipher cipher = getCipher();
    cipher.init(Cipher.DECRYPT_MODE, privateKey);

    return cipher.doFinal(input);
  }

  private KeyStore.PrivateKeyEntry getEntry() throws Exception {
    KeyStore ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID_KEYSTORE);
    ks.load(null);

    KeyStore.Entry entry = ks.getEntry(KEY_ALIAS, null);
    if (entry == null) {
      throw new Exception("No key found under alias: " + KEY_ALIAS);
    }

    if (!(entry instanceof KeyStore.PrivateKeyEntry)) {
      throw new Exception("Not an instance of a PrivateKeyEntry");
    }

    return (KeyStore.PrivateKeyEntry) entry;
  }

  private Cipher getCipher() throws Exception {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      return Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidOpenSSL"); // error in android 6: InvalidKeyException: Need RSA private or public key
    } else {
      return Cipher.getInstance("RSA/ECB/PKCS1Padding", "AndroidKeyStoreBCWorkaround"); // error in android 5: NoSuchProviderException: Provider not available: AndroidKeyStoreBCWorkaround
    }
  }

  private String addPrefixToKey(String key) {
    return KEY_PREFIX + "_" + key;
  }

  static private void createKeysIfNeeded(Context context) throws Exception {
    KeyStore ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID_KEYSTORE);
    ks.load(null);

    KeyStore.Entry entry = ks.getEntry(KEY_ALIAS, null);
    if (entry == null) {
      createKeys(context);
    }
  }

  @SuppressLint("NewApi")
  static private void createKeys(Context context) throws Exception {
    Calendar start = Calendar.getInstance();
    Calendar end = Calendar.getInstance();
    end.add(Calendar.YEAR, 25);

    KeyPairGenerator kpGenerator = KeyPairGenerator.getInstance(TYPE_RSA, KEYSTORE_PROVIDER_ANDROID_KEYSTORE);

    AlgorithmParameterSpec spec;

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR2) {
      spec = new RSAKeyGenParameterSpec(1024, RSAKeyGenParameterSpec.F4);
    } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      //noinspection deprecation
      spec = new KeyPairGeneratorSpec.Builder(context)
          .setAlias(KEY_ALIAS)
          .setSubject(new X500Principal("CN=" + KEY_ALIAS))
          .setSerialNumber(BigInteger.valueOf(1))
          .setStartDate(start.getTime())
          .setEndDate(end.getTime())
          .build();


    } else {
      spec = new KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_DECRYPT | KeyProperties.PURPOSE_ENCRYPT)
          .setCertificateSubject(new X500Principal("CN=" + KEY_ALIAS))
          .setDigests(KeyProperties.DIGEST_SHA256)
          .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_PKCS1)
          .setCertificateSerialNumber(BigInteger.valueOf(1))
          .setCertificateNotBefore(start.getTime())
          .setCertificateNotAfter(end.getTime())
          .build();
    }
    kpGenerator.initialize(spec);
    kpGenerator.generateKeyPair();
  }
}
