package com.it_nomads.fluttersecurestorage.ciphers;

import android.content.Context;
import android.content.SharedPreferences;

import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class BiometricNamespaceKeyRecoveryTest {

    private static final String NAME = "FlutterSecureStorage";
    private static final String PLAIN_KEY_PREFS = "FlutterSecureKeyStorage";
    private static final String NS_KEY_PREFS = "FlutterSecureKeyStorage:" + NAME;
    private static final String APP_KEY_PREF = StorageCipherImplementationAES23.APP_KEY_PREF;
    // Default FlutterSecureStorageConfig key prefix.
    private static final String KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";

    private Context context;
    private SharedPreferences plainKeyPrefs;
    private SharedPreferences namespacedKeyPrefs;
    private SharedPreferences dataPrefs;

    @Before
    public void setUp() {
        context = RuntimeEnvironment.getApplication();
        plainKeyPrefs = context.getSharedPreferences(PLAIN_KEY_PREFS, Context.MODE_PRIVATE);
        namespacedKeyPrefs = context.getSharedPreferences(NS_KEY_PREFS, Context.MODE_PRIVATE);
        dataPrefs = context.getSharedPreferences(NAME, Context.MODE_PRIVATE);
        plainKeyPrefs.edit().clear().commit();
        namespacedKeyPrefs.edit().clear().commit();
        dataPrefs.edit().clear().commit();
    }

    private FlutterSecureStorageConfig plainConfig() {
        return new FlutterSecureStorageConfig(new HashMap<>());
    }

    private FlutterSecureStorageConfig namespacedConfig() {
        Map<String, Object> options = new HashMap<>();
        options.put(FlutterSecureStorageConfig.PREF_OPTION_STORAGE_NAMESPACE, NAME);
        return new FlutterSecureStorageConfig(options);
    }

    private void storeData() {
        dataPrefs.edit().putString(KEY_PREFIX + "_token", "ciphertext").commit();
    }

    private static Cipher encryptCipher(SecretKey key) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key);
        return cipher;
    }

    private static Cipher decryptCipher(SecretKey key, byte[] iv) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, iv));
        return cipher;
    }

    // -------------------------------------------------------------------------
    // isRecoveryNeeded guards
    // -------------------------------------------------------------------------

    @Test
    public void needsRecoveryWhenSourceHasAppKeyAndTargetDoesNot() {
        plainKeyPrefs.edit().putString(APP_KEY_PREF, "QUJD").commit();
        storeData();

        assertTrue(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, namespacedConfig()));
    }

    @Test
    public void doesNotNeedRecoveryWhenTargetAlreadyHasAppKey() {
        plainKeyPrefs.edit().putString(APP_KEY_PREF, "QUJD").commit();
        namespacedKeyPrefs.edit().putString(APP_KEY_PREF, "existing").commit();
        storeData();

        assertFalse(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, namespacedConfig()));
    }

    @Test
    public void doesNotNeedRecoveryWithoutSourceAppKey() {
        storeData();

        assertFalse(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, namespacedConfig()));
    }

    @Test
    public void doesNotNeedRecoveryWhenDataPrefsAreEmpty() {
        plainKeyPrefs.edit().putString(APP_KEY_PREF, "QUJD").commit();

        assertFalse(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, namespacedConfig()));
    }

    @Test
    public void recoverDirectionAlsoDetected() {
        namespacedKeyPrefs.edit().putString(APP_KEY_PREF, "QUJD").commit();
        storeData();

        assertTrue(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, plainConfig()));
    }

    // -------------------------------------------------------------------------
    // sourceConfig
    // -------------------------------------------------------------------------

    @Test
    public void sourceConfigStripsNamespaceWhenAdopting() {
        FlutterSecureStorageConfig source = BiometricNamespaceKeyRecovery.sourceConfig(namespacedConfig());

        assertFalse(source.hasStorageNamespace());
    }

    @Test
    public void sourceConfigAddsNamespaceWhenRecovering() {
        FlutterSecureStorageConfig source = BiometricNamespaceKeyRecovery.sourceConfig(plainConfig());

        assertTrue(source.hasStorageNamespace());
    }

    // -------------------------------------------------------------------------
    // decrypt/store round trip
    // -------------------------------------------------------------------------

    @Test
    public void movesAppKeyFromOldLocationToNewOneUsingAuthenticatedCiphers() throws Exception {
        KeyGenerator keyGenerator = KeyGenerator.getInstance("AES");
        keyGenerator.init(256, new SecureRandom());
        SecretKey oldKeystoreKey = keyGenerator.generateKey();
        SecretKey newKeystoreKey = keyGenerator.generateKey();
        byte[] appKey = new byte[32];
        new SecureRandom().nextBytes(appKey);

        // Simulate what StorageCipherImplementationAES23 already stored at the old location.
        Cipher seedCipher = encryptCipher(oldKeystoreKey);
        byte[] iv = seedCipher.getIV();
        byte[] wrapped = seedCipher.doFinal(appKey);
        plainKeyPrefs.edit()
                .putString(APP_KEY_PREF, android.util.Base64.encodeToString(wrapped, android.util.Base64.DEFAULT))
                .commit();
        storeData();

        FlutterSecureStorageConfig config = namespacedConfig();
        assertTrue(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, config));

        Cipher oldCipher = decryptCipher(oldKeystoreKey, iv);
        byte[] decrypted = BiometricNamespaceKeyRecovery.decryptSourceAppKey(context, config, oldCipher);
        assertArrayEquals(appKey, decrypted);

        Cipher newCipher = encryptCipher(newKeystoreKey);
        BiometricNamespaceKeyRecovery.storeTargetAppKey(context, config, newCipher, decrypted);

        assertTrue(namespacedKeyPrefs.contains(APP_KEY_PREF));
        // Old copy is left in place, same as LegacyNamespaceKeyRecovery.
        assertTrue(plainKeyPrefs.contains(APP_KEY_PREF));
    }

    @Test
    public void movesAppKeyFromNamespacedLocationBackToPlainOne() throws Exception {
        KeyGenerator keyGenerator = KeyGenerator.getInstance("AES");
        keyGenerator.init(256, new SecureRandom());
        SecretKey oldKeystoreKey = keyGenerator.generateKey();
        SecretKey newKeystoreKey = keyGenerator.generateKey();
        byte[] appKey = new byte[32];
        new SecureRandom().nextBytes(appKey);

        // Simulate what StorageCipherImplementationAES23 already stored at the
        // namespaced location (the app previously had storageNamespace set).
        Cipher seedCipher = encryptCipher(oldKeystoreKey);
        byte[] iv = seedCipher.getIV();
        byte[] wrapped = seedCipher.doFinal(appKey);
        namespacedKeyPrefs.edit()
                .putString(APP_KEY_PREF, android.util.Base64.encodeToString(wrapped, android.util.Base64.DEFAULT))
                .commit();
        storeData();

        FlutterSecureStorageConfig config = plainConfig();
        assertTrue(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, config));

        Cipher oldCipher = decryptCipher(oldKeystoreKey, iv);
        byte[] decrypted = BiometricNamespaceKeyRecovery.decryptSourceAppKey(context, config, oldCipher);
        assertArrayEquals(appKey, decrypted);

        Cipher newCipher = encryptCipher(newKeystoreKey);
        BiometricNamespaceKeyRecovery.storeTargetAppKey(context, config, newCipher, decrypted);

        assertTrue(plainKeyPrefs.contains(APP_KEY_PREF));
        // Old copy is left in place, same as LegacyNamespaceKeyRecovery.
        assertTrue(namespacedKeyPrefs.contains(APP_KEY_PREF));
        assertFalse(BiometricNamespaceKeyRecovery.isRecoveryNeeded(context, config));
    }

    @Test(expected = Exception.class)
    public void decryptThrowsWhenSourceHasNoAppKey() throws Exception {
        storeData();
        Cipher anyCipher = encryptCipher(KeyGenerator.getInstance("AES").generateKey());

        BiometricNamespaceKeyRecovery.decryptSourceAppKey(context, namespacedConfig(), anyCipher);
    }
}
