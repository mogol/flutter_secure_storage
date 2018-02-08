package com.it_nomads.fluttersecurestorage.ciphers;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;

import java.math.BigInteger;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.spec.AlgorithmParameterSpec;
import java.util.Calendar;

import javax.crypto.Cipher;
import javax.security.auth.x500.X500Principal;

public class StorageCipher18Implementation implements StorageCipher {

  private static final String KEY_ALIAS = "FlutterSecureStoragePluginKey";
  private static final String KEYSTORE_PROVIDER_ANDROID = "AndroidKeyStore";
  private static final String TYPE_RSA = "RSA";


  public StorageCipher18Implementation(Context context) throws Exception {
    createKeysIfNeeded(context);
  }

  @Override
  public byte[] encrypt(byte[] input) throws Exception {
    PublicKey publicKey = getEntry().getCertificate().getPublicKey();
    Cipher cipher = getCipher();
    cipher.init(Cipher.ENCRYPT_MODE, publicKey);

    return cipher.doFinal(input);
  }

  @Override
  public byte[] decrypt(byte[] input) throws Exception {
    PrivateKey privateKey = getEntry().getPrivateKey();
    Cipher cipher = getCipher();
    cipher.init(Cipher.DECRYPT_MODE, privateKey);

    return cipher.doFinal(input);
  }

  private KeyStore.PrivateKeyEntry getEntry() throws Exception {
    KeyStore ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID);
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

  private void createKeysIfNeeded(Context context) throws Exception {
    KeyStore ks = KeyStore.getInstance(KEYSTORE_PROVIDER_ANDROID);
    ks.load(null);

    KeyStore.Entry entry = ks.getEntry(KEY_ALIAS, null);
    if (entry == null) {
      createKeys(context);
    }
  }

  @SuppressLint("NewApi")
  @SuppressWarnings("deprecation")
  private void createKeys(Context context) throws Exception {
    Calendar start = Calendar.getInstance();
    Calendar end = Calendar.getInstance();
    end.add(Calendar.YEAR, 25);

    KeyPairGenerator kpGenerator = KeyPairGenerator.getInstance(TYPE_RSA, KEYSTORE_PROVIDER_ANDROID);

    AlgorithmParameterSpec spec;

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      //noinspection deprecation
      spec = new android.security.KeyPairGeneratorSpec.Builder(context)
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

  static public boolean isAvailable() {
    return Build.VERSION.SDK_INT > Build.VERSION_CODES.JELLY_BEAN_MR2;
  }
}
