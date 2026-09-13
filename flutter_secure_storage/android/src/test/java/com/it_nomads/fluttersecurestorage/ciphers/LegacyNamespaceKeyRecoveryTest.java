package com.it_nomads.fluttersecurestorage.ciphers;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;

import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import java.security.Key;
import java.util.HashMap;
import java.util.Map;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 34)
public class LegacyNamespaceKeyRecoveryTest {

    private static final String NAME = "FlutterSecureStorage";
    private static final String PLAIN_KEY_PREFS = "FlutterSecureKeyStorage";
    private static final String NS_KEY_PREFS = "FlutterSecureKeyStorage:" + NAME;
    private static final String WRAPPED = StorageCipherImplementationGCM.WRAPPED_KEY_PREF;
    // Default FlutterSecureStorageConfig key prefix.
    private static final String KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";

    private Context context;
    private SharedPreferences plainKeyPrefs;
    private SharedPreferences namespacedKeyPrefs;
    private SharedPreferences dataPrefs;

    /** Round-trips raw key bytes so recovery runs without Android KeyStore. */
    private static class FakeKeyCipher implements KeyCipher {
        @Override public byte[] wrap(Key key) { return key.getEncoded(); }
        @Override public Key unwrap(byte[] wrappedKey, String algorithm) {
            return new SecretKeySpec(wrappedKey, algorithm);
        }
        @Override public Cipher getCipher(Context context) { return null; }
        @Override public void deleteKey() {}
    }

    private final LegacyNamespaceKeyRecovery.KeyCipherProvider fakeProvider = c -> new FakeKeyCipher();

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

    private void storeKey(SharedPreferences prefs, String base64) {
        prefs.edit().putString(WRAPPED, base64).commit();
    }

    private void storeData() {
        dataPrefs.edit().putString(KEY_PREFIX + "_token", "ciphertext").commit();
    }

    private boolean run(FlutterSecureStorageConfig config) {
        return LegacyNamespaceKeyRecovery.recoverIfNeeded(context, config, fakeProvider);
    }

    private static byte[] decode(SharedPreferences prefs) {
        return Base64.decode(prefs.getString(WRAPPED, null), Base64.DEFAULT);
    }

    // -------------------------------------------------------------------------
    // recover: namespaced -> plain (downgrade)
    // -------------------------------------------------------------------------

    @Test
    public void recoversNamespacedKeyIntoPlainLocation() {
        storeKey(namespacedKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");
        storeData();

        assertTrue(run(plainConfig()));

        assertArrayEquals(decode(namespacedKeyPrefs), decode(plainKeyPrefs));
        assertEquals("AAECAwQFBgcICQoLDA0ODw==", namespacedKeyPrefs.getString(WRAPPED, null));
    }

    @Test
    public void recoverDoesNothingWhenPlainKeyAlreadyPresent() {
        storeKey(plainKeyPrefs, "existing");
        storeKey(namespacedKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");
        storeData();

        assertFalse(run(plainConfig()));
        assertEquals("existing", plainKeyPrefs.getString(WRAPPED, null));
    }

    @Test
    public void recoverDoesNothingWithoutNamespacedKey() {
        storeData();

        assertFalse(run(plainConfig()));
        assertNull(plainKeyPrefs.getString(WRAPPED, null));
    }

    // -------------------------------------------------------------------------
    // adopt: plain -> namespaced (added storageNamespace over existing data)
    // -------------------------------------------------------------------------

    @Test
    public void adoptsPlainKeyIntoNamespacedLocation() {
        storeKey(plainKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");
        storeData();

        assertTrue(run(namespacedConfig()));

        assertArrayEquals(decode(plainKeyPrefs), decode(namespacedKeyPrefs));
        assertEquals("AAECAwQFBgcICQoLDA0ODw==", plainKeyPrefs.getString(WRAPPED, null));
    }

    @Test
    public void adoptDoesNothingWhenNamespacedKeyAlreadyPresent() {
        storeKey(plainKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");
        storeKey(namespacedKeyPrefs, "existing");
        storeData();

        assertFalse(run(namespacedConfig()));
        assertEquals("existing", namespacedKeyPrefs.getString(WRAPPED, null));
    }

    // -------------------------------------------------------------------------
    // shared guards
    // -------------------------------------------------------------------------

    @Test
    public void doesNothingWhenDataPrefsAreEmpty() {
        storeKey(plainKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");

        assertFalse(run(namespacedConfig()));
        assertNull(namespacedKeyPrefs.getString(WRAPPED, null));
    }

    @Test
    public void isIdempotent() {
        storeKey(namespacedKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");
        storeData();

        assertTrue(run(plainConfig()));
        String afterFirst = plainKeyPrefs.getString(WRAPPED, null);
        assertFalse(run(plainConfig()));
        assertEquals(afterFirst, plainKeyPrefs.getString(WRAPPED, null));
    }

    @Test
    public void leavesTargetUntouchedWhenUnwrapFails() {
        storeKey(namespacedKeyPrefs, "AAECAwQFBgcICQoLDA0ODw==");
        storeData();
        LegacyNamespaceKeyRecovery.KeyCipherProvider failing = c -> {
            throw new IllegalStateException("no key");
        };

        assertFalse(LegacyNamespaceKeyRecovery.recoverIfNeeded(context, plainConfig(), failing));
        assertNull(plainKeyPrefs.getString(WRAPPED, null));
    }

    // -------------------------------------------------------------------------
    // public entry point: falls back from OAEP to legacy PKCS1
    // -------------------------------------------------------------------------

    /** Only unwraps bytes it wrapped itself; mimics a real algorithm mismatch. */
    private static class AlgorithmBoundKeyCipher implements KeyCipher {
        private final String algorithmTag;

        AlgorithmBoundKeyCipher(String algorithmTag) {
            this.algorithmTag = algorithmTag;
        }

        @Override
        public byte[] wrap(Key key) {
            return (algorithmTag + ":" + Base64.encodeToString(key.getEncoded(), Base64.NO_WRAP))
                    .getBytes();
        }

        @Override
        public Key unwrap(byte[] wrappedKey, String algorithm) throws Exception {
            String wrapped = new String(wrappedKey);
            String prefix = algorithmTag + ":";
            if (!wrapped.startsWith(prefix)) {
                throw new Exception("BAD_DECRYPT: wrong RSA algorithm for wrapped key");
            }
            byte[] raw = Base64.decode(wrapped.substring(prefix.length()), Base64.NO_WRAP);
            return new SecretKeySpec(raw, algorithm);
        }

        @Override public Cipher getCipher(Context context) { return null; }
        @Override public void deleteKey() {}
    }

    @Test
    public void fallsBackToNextProviderWhenFirstUnwrapFails() {
        AlgorithmBoundKeyCipher oaepCipher = new AlgorithmBoundKeyCipher("OAEP");
        AlgorithmBoundKeyCipher pkcs1Cipher = new AlgorithmBoundKeyCipher("PKCS1");
        byte[] wrapped = pkcs1Cipher.wrap(new SecretKeySpec(new byte[16], "AES"));
        storeKey(namespacedKeyPrefs, Base64.encodeToString(wrapped, Base64.DEFAULT));
        storeData();

        boolean recovered = LegacyNamespaceKeyRecovery.recoverIfNeeded(context, plainConfig(),
                c -> oaepCipher, c -> pkcs1Cipher);

        assertTrue(recovered);
        assertArrayEquals(decode(namespacedKeyPrefs), decode(plainKeyPrefs));
    }

    // -------------------------------------------------------------------------
    // true v9.2.4 installs: wrapped key stored under AES18's legacy name, not
    // the v10+ GCM name recoverIfNeeded originally only looked for.
    // -------------------------------------------------------------------------

    @Test
    public void adoptsLegacyV9KeyNameAndKeepsItUnderTheSameName() {
        String legacyName = StorageCipherImplementationAES18.WRAPPED_KEY_PREF;
        plainKeyPrefs.edit().putString(legacyName, "AAECAwQFBgcICQoLDA0ODw==").commit();
        storeData();

        assertTrue(run(namespacedConfig()));

        assertEquals("AAECAwQFBgcICQoLDA0ODw==", plainKeyPrefs.getString(legacyName, null));
        assertArrayEquals(
                Base64.decode(plainKeyPrefs.getString(legacyName, null), Base64.DEFAULT),
                Base64.decode(namespacedKeyPrefs.getString(legacyName, null), Base64.DEFAULT));
        // Must not also write it under the unrelated v10+ GCM name.
        assertNull(namespacedKeyPrefs.getString(WRAPPED, null));
    }

    @Test
    public void failsWhenNoProviderCanUnwrap() {
        AlgorithmBoundKeyCipher oaepCipher = new AlgorithmBoundKeyCipher("OAEP");
        AlgorithmBoundKeyCipher pkcs1Cipher = new AlgorithmBoundKeyCipher("PKCS1");
        AlgorithmBoundKeyCipher unrelatedCipher = new AlgorithmBoundKeyCipher("SOMETHING_ELSE");
        byte[] wrapped = unrelatedCipher.wrap(new SecretKeySpec(new byte[16], "AES"));
        storeKey(namespacedKeyPrefs, Base64.encodeToString(wrapped, Base64.DEFAULT));
        storeData();

        boolean recovered = LegacyNamespaceKeyRecovery.recoverIfNeeded(context, plainConfig(),
                c -> oaepCipher, c -> pkcs1Cipher);

        assertFalse(recovered);
        assertNull(plainKeyPrefs.getString(WRAPPED, null));
    }

    // -------------------------------------------------------------------------
    // observed on a real device: RSA/OAEP unwrap of PKCS1 ciphertext with an
    // unrelated, already-existing OAEP key didn't throw - it just returned
    // garbage. A wrong-algorithm attempt must be caught even when it doesn't
    // throw, or the garbage gets committed as if it were the real key.
    // -------------------------------------------------------------------------

    /** Never throws; returns garbage-sized "key" material for the wrong algorithm. */
    private static class SilentlyWrongSizeKeyCipher implements KeyCipher {
        private final String algorithmTag;

        SilentlyWrongSizeKeyCipher(String algorithmTag) {
            this.algorithmTag = algorithmTag;
        }

        @Override
        public byte[] wrap(Key key) {
            return (algorithmTag + ":" + Base64.encodeToString(key.getEncoded(), Base64.NO_WRAP))
                    .getBytes();
        }

        @Override
        public Key unwrap(byte[] wrappedKey, String algorithm) {
            String wrapped = new String(wrappedKey);
            String prefix = algorithmTag + ":";
            if (!wrapped.startsWith(prefix)) {
                // Wrong algorithm, but doesn't throw - returns something AES-labeled
                // and the wrong size instead, like the real provider quirk did.
                return new SecretKeySpec(new byte[3], algorithm);
            }
            byte[] raw = Base64.decode(wrapped.substring(prefix.length()), Base64.NO_WRAP);
            return new SecretKeySpec(raw, algorithm);
        }

        @Override public Cipher getCipher(Context context) { return null; }
        @Override public void deleteKey() {}
    }

    @Test
    public void fallsBackWhenFirstProviderSilentlyReturnsWrongSizedKey() {
        SilentlyWrongSizeKeyCipher oaepCipher = new SilentlyWrongSizeKeyCipher("OAEP");
        SilentlyWrongSizeKeyCipher pkcs1Cipher = new SilentlyWrongSizeKeyCipher("PKCS1");
        byte[] wrapped = pkcs1Cipher.wrap(new SecretKeySpec(new byte[16], "AES"));
        storeKey(namespacedKeyPrefs, Base64.encodeToString(wrapped, Base64.DEFAULT));
        storeData();

        boolean recovered = LegacyNamespaceKeyRecovery.recoverIfNeeded(context, plainConfig(),
                c -> oaepCipher, c -> pkcs1Cipher);

        assertTrue(recovered);
        assertArrayEquals(decode(namespacedKeyPrefs), decode(plainKeyPrefs));
    }

    @Test
    public void failsWhenEveryProviderSilentlyReturnsWrongSizedKey() {
        SilentlyWrongSizeKeyCipher oaepCipher = new SilentlyWrongSizeKeyCipher("OAEP");
        SilentlyWrongSizeKeyCipher pkcs1Cipher = new SilentlyWrongSizeKeyCipher("PKCS1");
        SilentlyWrongSizeKeyCipher unrelatedCipher = new SilentlyWrongSizeKeyCipher("SOMETHING_ELSE");
        byte[] wrapped = unrelatedCipher.wrap(new SecretKeySpec(new byte[16], "AES"));
        storeKey(namespacedKeyPrefs, Base64.encodeToString(wrapped, Base64.DEFAULT));
        storeData();

        boolean recovered = LegacyNamespaceKeyRecovery.recoverIfNeeded(context, plainConfig(),
                c -> oaepCipher, c -> pkcs1Cipher);

        assertFalse(recovered);
        assertNull(plainKeyPrefs.getString(WRAPPED, null));
    }
}
