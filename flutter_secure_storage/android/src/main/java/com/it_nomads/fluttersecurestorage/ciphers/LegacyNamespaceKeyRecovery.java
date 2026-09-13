package com.it_nomads.fluttersecurestorage.ciphers;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Base64;
import android.util.Log;

import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig;

import java.security.Key;
import java.util.Map;

/**
 * Moves the wrapped AES key when an app switches between sharedPreferencesName
 * and storageNamespace with the same name. Only the key lives in a different
 * place; the data prefs file and algorithm markers already line up, so copying
 * the key across is enough. The source copy is left in place so switching back
 * keeps working. Non-biometric only; the wrapped key is unwrapped and rewrapped
 * with the same RSA algorithm it was already using (OAEP, or legacy PKCS1 for
 * installs that never went through the v10.0.0 OAEP migration), tried in that
 * order since OAEP is the common case. The entry is kept under whichever
 * preference name it was already stored under - v9.2.4 and v10+ each read a
 * different name, and whichever storage cipher decrypts the data later needs
 * to find it under the name it looks for.
 */
public final class LegacyNamespaceKeyRecovery {

    private static final String TAG = "LegacyNamespaceKeyRecovery";
    private static final String KEY_STORAGE_PREFIX = "FlutterSecureKeyStorage";
    private static final KeyCipherAlgorithm[] RECOVERY_ALGORITHMS = {
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
            KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
    };
    private static final String[] WRAPPED_KEY_PREF_NAMES = {
            StorageCipherImplementationGCM.WRAPPED_KEY_PREF,
            StorageCipherImplementationAES18.WRAPPED_KEY_PREF,
            StorageCipherImplementationGCM.LEGACY_V9_KEY,
    };

    /** Test seam. */
    interface KeyCipherProvider {
        KeyCipher forConfig(FlutterSecureStorageConfig config) throws Exception;
    }

    private LegacyNamespaceKeyRecovery() {}

    public static boolean recoverIfNeeded(Context context, FlutterSecureStorageConfig config) {
        KeyCipherProvider[] providers = new KeyCipherProvider[RECOVERY_ALGORITHMS.length];
        for (int i = 0; i < RECOVERY_ALGORITHMS.length; i++) {
            KeyCipherAlgorithm algorithm = RECOVERY_ALGORITHMS[i];
            providers[i] = c -> algorithm.keyCipher.apply(context, c);
        }
        return recoverIfNeeded(context, config, providers);
    }

    /** Tries each provider in order until one succeeds; each is a candidate RSA algorithm. */
    static boolean recoverIfNeeded(Context context, FlutterSecureStorageConfig config,
                                   KeyCipherProvider... keyCiphers) {
        for (KeyCipherProvider keyCipher : keyCiphers) {
            if (recoverIfNeededWithProvider(context, config, keyCipher)) {
                return true;
            }
        }
        return false;
    }

    private static boolean recoverIfNeededWithProvider(Context context, FlutterSecureStorageConfig config,
                                   KeyCipherProvider keyCiphers) {
        String name = config.getEffectiveDataPrefsName();
        SharedPreferences plainKeyPrefs = context.getSharedPreferences(
                KEY_STORAGE_PREFIX, Context.MODE_PRIVATE);
        SharedPreferences namespacedKeyPrefs = context.getSharedPreferences(
                KEY_STORAGE_PREFIX + ":" + name, Context.MODE_PRIVATE);

        final SharedPreferences source;
        final SharedPreferences target;
        final FlutterSecureStorageConfig sourceConfig;
        final FlutterSecureStorageConfig targetConfig;
        if (config.hasStorageNamespace()) {
            // adopt: plain -> namespaced
            source = plainKeyPrefs;
            target = namespacedKeyPrefs;
            sourceConfig = config.withoutStorageNamespace();
            targetConfig = config;
        } else {
            // recover: namespaced -> plain
            source = namespacedKeyPrefs;
            target = plainKeyPrefs;
            sourceConfig = config.withStorageNamespace(name);
            targetConfig = config;
        }

        String sourceKeyPrefName = findWrappedKeyPrefName(source);
        if (hasWrappedKey(target) || sourceKeyPrefName == null || !hasEncryptedData(context, name, config)) {
            return false;
        }

        try {
            byte[] wrapped = Base64.decode(source.getString(sourceKeyPrefName, null), Base64.DEFAULT);
            Key aesKey = keyCiphers.forConfig(sourceConfig)
                    .unwrap(wrapped, StorageCipherImplementationGCM.WRAPPED_KEY_ALGORITHM);
            byte[] rewrapped = keyCiphers.forConfig(targetConfig).wrap(aesKey);

            target.edit()
                    .putString(sourceKeyPrefName, Base64.encodeToString(rewrapped, Base64.DEFAULT))
                    .apply();

            Log.i(TAG, "Moved wrapped key for namespace '" + name + "'");
            return true;
        } catch (Throwable e) {
            if (e instanceof VirtualMachineError) {
                throw (VirtualMachineError) e;
            }
            Log.w(TAG, "Could not move wrapped key for namespace '" + name + "'", e);
            return false;
        }
    }

    private static boolean hasWrappedKey(SharedPreferences prefs) {
        return findWrappedKeyPrefName(prefs) != null;
    }

    /** Returns whichever known wrapped-key preference name is present, or null. */
    private static String findWrappedKeyPrefName(SharedPreferences prefs) {
        for (String prefName : WRAPPED_KEY_PREF_NAMES) {
            if (prefs.contains(prefName)) {
                return prefName;
            }
        }
        return null;
    }

    // Guards against pulling an unrelated instance's key into an empty store.
    private static boolean hasEncryptedData(Context context, String dataPrefsName,
                                            FlutterSecureStorageConfig config) {
        SharedPreferences dataPrefs = context.getSharedPreferences(dataPrefsName, Context.MODE_PRIVATE);
        String keyPrefix = config.getSharedPreferencesKeyPrefix();
        for (Map.Entry<String, ?> entry : dataPrefs.getAll().entrySet()) {
            if (entry.getValue() instanceof String && entry.getKey().contains(keyPrefix)) {
                return true;
            }
        }
        return false;
    }
}
