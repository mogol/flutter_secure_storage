package com.it_nomads.fluttersecurestorage;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.RequiresApi;
import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;

import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher;
import com.it_nomads.fluttersecurestorage.ciphers.StorageCipher18Implementation;

import java.io.IOException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.HashMap;
import java.util.Map;

public class FlutterSecureStorage {

    private static final String TAG = "SecureStorageAndroid";
    private static final String SHARED_PREFERENCES_NAME = "FlutterSecureStorage";
    private static final String ELEMENT_PREFERENCES_KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";

    private final Charset charset;

    private final Context applicationContext;
    private final SharedPreferences nonEncryptedPreferences;
    private SharedPreferences preferences;
    private StorageCipher storageCipher;
    private boolean useEncryptedSharedPreferences = false;

    public FlutterSecureStorage(Context context) {
        applicationContext = context.getApplicationContext();
        nonEncryptedPreferences = context.getSharedPreferences(
                SHARED_PREFERENCES_NAME,
                Context.MODE_PRIVATE
        );
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            charset = StandardCharsets.UTF_8;
        } else {
            //noinspection CharsetObjectCanBeUsed
            charset = Charset.forName("UTF-8");
        }
    }

    public boolean containsKey(String key, boolean tryUseEncryptedSharedPreferences) {
        ensureInitialized(tryUseEncryptedSharedPreferences);
        String actualKey = addPrefixToKey(key);

        return preferences.contains(actualKey);
    }

    public String read(String key, boolean tryUseEncryptedSharedPreferences) throws Exception {
        ensureInitialized(tryUseEncryptedSharedPreferences);
        String actualKey = addPrefixToKey(key);

        String rawValue = preferences.getString(actualKey, null);
        if (useEncryptedSharedPreferences) {
            return rawValue;
        }
        return decodeRawValue(rawValue);
    }

    @SuppressWarnings("unchecked")
    public Map<String, String> readAll(boolean tryUseEncryptedSharedPreferences) throws Exception {
        ensureInitialized(tryUseEncryptedSharedPreferences);

        Map<String, String> raw = (Map<String, String>) preferences.getAll();

        Map<String, String> all = new HashMap<>();
        for (Map.Entry<String, String> entry : raw.entrySet()) {
            String keyWithPrefix = entry.getKey();
            if (keyWithPrefix.contains(ELEMENT_PREFERENCES_KEY_PREFIX)) {
                String key = entry.getKey().replaceFirst(ELEMENT_PREFERENCES_KEY_PREFIX + '_', "");
                if (useEncryptedSharedPreferences) {
                    all.put(key, entry.getValue());
                } else {
                    String rawValue = entry.getValue();
                    String value = decodeRawValue(rawValue);

                    all.put(key, value);
                }
            }
        }
        return all;
    }

    public void write(String key, String value, boolean tryUseEncryptedSharedPreferences) throws Exception {
        ensureInitialized(tryUseEncryptedSharedPreferences);
        String actualKey = addPrefixToKey(key);

        SharedPreferences.Editor editor = preferences.edit();

        if (useEncryptedSharedPreferences) {
            editor.putString(actualKey, value);
        } else {
            byte[] result = storageCipher.encrypt(value.getBytes(charset));
            editor.putString(actualKey, Base64.encodeToString(result, 0));
        }
        editor.apply();
    }

    public void delete(String key, boolean tryUseEncryptedSharedPreferences) {
        ensureInitialized(tryUseEncryptedSharedPreferences);
        String actualKey = addPrefixToKey(key);

        SharedPreferences.Editor editor = preferences.edit();
        editor.remove(actualKey);
        editor.apply();
    }

    public void deleteAll(boolean tryUseEncryptedSharedPreferences) {
        ensureInitialized(tryUseEncryptedSharedPreferences);

        preferences.edit().clear().apply();
    }

    private void ensureInitialized(boolean tryUseEncryptedSharedPreferences) {
        useEncryptedSharedPreferences = useEncryptedSharedPreferences(tryUseEncryptedSharedPreferences);
        if (storageCipher == null) {
            try {
                storageCipher = new StorageCipher18Implementation(applicationContext);
            } catch (Exception e) {
                Log.e(TAG, "StorageCipher initialization failed", e);
            }
        }
        if (useEncryptedSharedPreferences &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                preferences = initializeEncryptedSharedPreferencesManager(applicationContext);
            } catch (Exception e) {
                Log.e(TAG, "EncryptedSharedPreferences initialization failed", e);
            }

            checkAndMigrateToEncrypted(nonEncryptedPreferences, preferences);
        } else {
            preferences = nonEncryptedPreferences;
        }
    }

    private boolean useEncryptedSharedPreferences(boolean tryUseEncryptedSharedPreferences) {
        return tryUseEncryptedSharedPreferences && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    private SharedPreferences initializeEncryptedSharedPreferencesManager(Context context) throws GeneralSecurityException, IOException {
        MasterKey key = new MasterKey.Builder(context)
                .setKeyGenParameterSpec(
                        new KeyGenParameterSpec
                                .Builder(MasterKey.DEFAULT_MASTER_KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                                .setKeySize(256).build())
                .build();
        return EncryptedSharedPreferences.create(
                context,
                SHARED_PREFERENCES_NAME,
                key,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        );
    }

    private String addPrefixToKey(String key) {
        return ELEMENT_PREFERENCES_KEY_PREFIX + "_" + key;
    }

    private void checkAndMigrateToEncrypted(SharedPreferences source, SharedPreferences target) {
        for (Map.Entry<String, ?> entry : source.getAll().entrySet()) {
            Object v = entry.getValue();
            String key = entry.getKey();
            if (v instanceof String && key.contains(ELEMENT_PREFERENCES_KEY_PREFIX))
                try {
                    final String decodedValue = decodeRawValue((String) v);
                    target.edit().putString(key, (decodedValue)).apply();
                    source.edit().remove(key).apply();
                } catch (Exception e) {
                    Log.e(TAG, "Data migration failed", e);
                }
        }
    }

    private String decodeRawValue(String value) throws Exception {
        if (value == null) {
            return null;
        }
        byte[] data = Base64.decode(value, 0);
        byte[] result = storageCipher.decrypt(data);

        return new String(result, charset);
    }
}
