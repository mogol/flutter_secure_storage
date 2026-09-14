package com.it_nomads.fluttersecurestorage;

import org.junit.Test;

import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

public class FlutterSecureStorageConfigTest {

    private FlutterSecureStorageConfig emptyConfig() {
        return new FlutterSecureStorageConfig(new HashMap<>());
    }

    private FlutterSecureStorageConfig configFrom(String key, String value) {
        Map<String, Object> options = new HashMap<>();
        options.put(key, value);
        return new FlutterSecureStorageConfig(options);
    }

    // -------------------------------------------------------------------------
    // Default values
    // -------------------------------------------------------------------------

    @Test
    public void defaults_sharedPreferencesName() {
        assertEquals("FlutterSecureStorage", emptyConfig().getSharedPreferencesName());
    }

    @Test
    public void defaults_sharedPreferencesKeyPrefix() {
        assertEquals(
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg",
            emptyConfig().getSharedPreferencesKeyPrefix()
        );
    }

    @Test
    public void defaults_deleteOnFailure_isFalse() {
        assertFalse(emptyConfig().shouldDeleteOnFailure());
    }

    @Test
    public void defaults_migrateOnAlgorithmChange_isTrue() {
        assertTrue(emptyConfig().shouldMigrateOnAlgorithmChange());
    }

    @Test
    public void defaults_enforceBiometrics_isFalse() {
        assertFalse(emptyConfig().getEnforceBiometrics());
    }

    @Test
    public void defaults_requireBiometricsPerOperation_isFalse() {
        assertFalse(emptyConfig().getRequireBiometricsPerOperation());
    }

    @Test
    public void defaults_isStrongBiometricOnly_isFalse() {
        assertFalse(emptyConfig().isStrongBiometricOnly());
    }

    @Test
    public void defaults_biometricPromptTitle() {
        assertEquals("Authenticate to access", emptyConfig().getBiometricPromptTitle());
    }

    @Test
    public void defaults_biometricPromptSubtitle() {
        assertEquals(
            "Use biometrics or device credentials",
            emptyConfig().getPrefOptionBiometricPromptSubtitle()
        );
    }

    @Test
    public void defaults_storageCipherAlgorithm() {
        assertEquals("AES_GCM_NoPadding", emptyConfig().getPrefOptionStorageCipherAlgorithm());
    }

    @Test
    public void defaults_keyCipherAlgorithm() {
        assertEquals("RSA_ECB_OAEPwithSHA_256andMGF1Padding", emptyConfig().getPrefOptionKeyCipherAlgorithm());
    }

    // -------------------------------------------------------------------------
    // Custom values
    // -------------------------------------------------------------------------

    @Test
    public void custom_sharedPreferencesName() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_NAME, "MyPrefs");
        assertEquals("MyPrefs", config.getSharedPreferencesName());
    }

    @Test
    public void custom_sharedPreferencesKeyPrefix() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_PREFIX, "myPrefix");
        assertEquals("myPrefix", config.getSharedPreferencesKeyPrefix());
    }

    @Test
    public void custom_deleteOnFailure_true() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_DELETE_ON_FAILURE, "true");
        assertTrue(config.shouldDeleteOnFailure());
    }

    @Test
    public void custom_migrateOnAlgorithmChange_false() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_MIGRATE_ON_ALGORITHM_CHANGE, "false");
        assertFalse(config.shouldMigrateOnAlgorithmChange());
    }

    @Test
    public void custom_enforceBiometrics_true() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_ENFORCE_BIOMETRICS, "true");
        assertTrue(config.getEnforceBiometrics());
    }

    @Test
    public void custom_requireBiometricsPerOperation_true() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_REQUIRE_BIOMETRICS_PER_OPERATION, "true");
        assertTrue(config.getRequireBiometricsPerOperation());
    }

    @Test
    public void custom_biometricType_strongBiometricOnly() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_TYPE,
                "strongBiometricOnly");
        assertTrue(config.isStrongBiometricOnly());
    }

    @Test
    public void custom_biometricType_biometricOrDeviceCredential() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_TYPE,
                "biometricOrDeviceCredential");
        assertFalse(config.isStrongBiometricOnly());
    }

    @Test
    public void biometricType_invalidValue_throwsIllegalArgumentException() {
        try {
            configFrom(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_TYPE, "invalidType");
            fail("Expected IllegalArgumentException");
        } catch (IllegalArgumentException e) {
            assertTrue(e.getMessage().contains("invalidType"));
        }
    }

    @Test
    public void defaults_biometricPromptNegativeButton() {
        assertEquals("Cancel", emptyConfig().getBiometricPromptNegativeButton());
    }

    @Test
    public void custom_biometricPromptNegativeButton() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_PROMPT_NEGATIVE_BUTTON, "Dismiss");
        assertEquals("Dismiss", config.getBiometricPromptNegativeButton());
    }

    @Test
    public void custom_biometricPromptTitle() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_PROMPT_TITLE, "Please authenticate");
        assertEquals("Please authenticate", config.getBiometricPromptTitle());
    }

    @Test
    public void custom_biometricPromptSubtitle() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_PROMPT_SUBTITLE, "Touch the sensor");
        assertEquals("Touch the sensor", config.getPrefOptionBiometricPromptSubtitle());
    }

    @Test
    public void custom_storageCipherAlgorithm() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_STORAGE_CIPHER_ALGORITHM, "AES_GCM_NoPadding");
        assertEquals("AES_GCM_NoPadding", config.getPrefOptionStorageCipherAlgorithm());
    }

    @Test
    public void custom_keyCipherAlgorithm() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_KEY_CIPHER_ALGORITHM, "AES_GCM_NoPadding");
        assertEquals("AES_GCM_NoPadding", config.getPrefOptionKeyCipherAlgorithm());
    }

    // -------------------------------------------------------------------------
    // Legacy biometric prompt key fallback
    // -------------------------------------------------------------------------

    @Test
    public void legacy_biometricPromptTitle_usedAsFallback() {
        FlutterSecureStorageConfig config = configFrom(
            FlutterSecureStorageConfig.LEGACY_PREF_OPTION_BIOMETRIC_PROMPT_TITLE, "Legacy Title"
        );
        assertEquals("Legacy Title", config.getBiometricPromptTitle());
    }

    @Test
    public void legacy_biometricPromptSubtitle_usedAsFallback() {
        FlutterSecureStorageConfig config = configFrom(
            FlutterSecureStorageConfig.LEGACY_PREF_OPTION_BIOMETRIC_PROMPT_SUBTITLE, "Legacy Subtitle"
        );
        assertEquals("Legacy Subtitle", config.getPrefOptionBiometricPromptSubtitle());
    }

    @Test
    public void primary_biometricPromptTitle_overridesLegacy() {
        Map<String, Object> options = new HashMap<>();
        options.put(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_PROMPT_TITLE, "Primary Title");
        options.put(FlutterSecureStorageConfig.LEGACY_PREF_OPTION_BIOMETRIC_PROMPT_TITLE, "Legacy Title");
        FlutterSecureStorageConfig config = new FlutterSecureStorageConfig(options);
        assertEquals("Primary Title", config.getBiometricPromptTitle());
    }

    @Test
    public void primary_biometricPromptSubtitle_overridesLegacy() {
        Map<String, Object> options = new HashMap<>();
        options.put(FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_PROMPT_SUBTITLE, "Primary Subtitle");
        options.put(FlutterSecureStorageConfig.LEGACY_PREF_OPTION_BIOMETRIC_PROMPT_SUBTITLE, "Legacy Subtitle");
        FlutterSecureStorageConfig config = new FlutterSecureStorageConfig(options);
        assertEquals("Primary Subtitle", config.getPrefOptionBiometricPromptSubtitle());
    }

    // -------------------------------------------------------------------------
    // Boolean option parsing
    // -------------------------------------------------------------------------

    @Test
    public void booleanOption_parsesTrue() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_DELETE_ON_FAILURE, "true");
        assertTrue(config.shouldDeleteOnFailure());
    }

    @Test
    public void booleanOption_parsesFalse() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_MIGRATE_ON_ALGORITHM_CHANGE, "false");
        assertFalse(config.shouldMigrateOnAlgorithmChange());
    }

    @Test
    public void booleanOption_missingKey_usesDefault() {
        // migrateOnAlgorithmChange defaults to true; omitting it should keep the default
        assertFalse(emptyConfig().shouldDeleteOnFailure());
        assertTrue(emptyConfig().shouldMigrateOnAlgorithmChange());
    }

    // -------------------------------------------------------------------------
    // String option empty-value handling
    // -------------------------------------------------------------------------

    @Test
    public void stringOption_emptyValue_usesDefault() {
        // Empty strings are treated as absent, so the default should be returned
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_NAME, "");
        assertEquals("FlutterSecureStorage", config.getSharedPreferencesName());
    }

    @Test
    public void stringOption_emptyPrefix_usesDefault() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_PREFIX, "");
        assertEquals(
            "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg",
            config.getSharedPreferencesKeyPrefix()
        );
    }

    // -------------------------------------------------------------------------
    // toString
    // -------------------------------------------------------------------------

    @Test
    public void toString_containsSharedPreferencesName() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_NAME, "TestPrefs");
        assertTrue(config.toString().contains("TestPrefs"));
    }

    @Test
    public void toString_containsMigrateOnAlgorithmChange() {
        FlutterSecureStorageConfig config = configFrom(
            FlutterSecureStorageConfig.PREF_OPTION_MIGRATE_ON_ALGORITHM_CHANGE, "false"
        );
        assertTrue(config.toString().contains("migrateOnAlgorithmChange=false"));
    }

    @Test
    public void toString_containsEnforceBiometrics() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_ENFORCE_BIOMETRICS, "true");
        assertTrue(config.toString().contains("enforceBiometrics=true"));
    }

    @Test
    public void toString_containsRequireBiometricsPerOperation() {
        FlutterSecureStorageConfig config = configFrom(FlutterSecureStorageConfig.PREF_OPTION_REQUIRE_BIOMETRICS_PER_OPERATION, "true");
        assertTrue(config.toString().contains("requireBiometricsPerOperation=true"));
    }

    // -------------------------------------------------------------------------
    // storageNamespace
    // -------------------------------------------------------------------------

    private FlutterSecureStorageConfig configWithNamespace(String namespace) {
        Map<String, Object> options = new HashMap<>();
        options.put(FlutterSecureStorageConfig.PREF_OPTION_STORAGE_NAMESPACE, namespace);
        return new FlutterSecureStorageConfig(options);
    }

    @Test
    public void storageNamespace_parsedFromOptions() {
        assertEquals("MyNamespace", configWithNamespace("MyNamespace").getStorageNamespace());
    }

    @Test
    public void storageNamespace_emptyString_treatedAsNull() {
        assertNull(configWithNamespace("").getStorageNamespace());
    }

    @Test
    public void storageNamespace_nullValue_treatedAsAbsent() {
        // Covers the `value instanceof String` = false branch when a null is placed in the map
        Map<String, Object> options = new HashMap<>();
        options.put(FlutterSecureStorageConfig.PREF_OPTION_STORAGE_NAMESPACE, null);
        assertNull(new FlutterSecureStorageConfig(options).getStorageNamespace());
    }

    @Test
    public void defaults_storageNamespace_isNull() {
        assertNull(emptyConfig().getStorageNamespace());
    }

    @Test
    public void hasStorageNamespace_trueWhenSet() {
        assertTrue(configWithNamespace("MyNamespace").hasStorageNamespace());
    }

    @Test
    public void hasStorageNamespace_falseWhenNotSet() {
        assertFalse(emptyConfig().hasStorageNamespace());
    }

    @Test
    public void getEffectiveDataPrefsName_returnsNamespace_whenSet() {
        assertEquals("MyNamespace", configWithNamespace("MyNamespace").getEffectiveDataPrefsName());
    }

    @Test
    public void getEffectiveDataPrefsName_returnsSharedPreferencesName_whenNoNamespace() {
        assertEquals("FlutterSecureStorage", emptyConfig().getEffectiveDataPrefsName());
    }

    @Test
    public void getEffectiveKeyStoragePrefsName_withNamespace() {
        assertEquals(
            "FlutterSecureKeyStorage:MyNamespace",
            configWithNamespace("MyNamespace").getEffectiveKeyStoragePrefsName()
        );
    }

    @Test
    public void getEffectiveKeyStoragePrefsName_withoutNamespace() {
        assertEquals("FlutterSecureKeyStorage", emptyConfig().getEffectiveKeyStoragePrefsName());
    }

    @Test
    public void getKeyAliasSuffix_withNamespace() {
        assertEquals(".MyNamespace", configWithNamespace("MyNamespace").getKeyAliasSuffix());
    }

    @Test
    public void getKeyAliasSuffix_withoutNamespace() {
        assertEquals("", emptyConfig().getKeyAliasSuffix());
    }

    // -------------------------------------------------------------------------
    // isBiometricConfirmationRequired
    // -------------------------------------------------------------------------

    @Test
    public void defaults_isBiometricConfirmationRequired_isTrue() {
        assertTrue(emptyConfig().isBiometricConfirmationRequired());
    }

    @Test
    public void custom_isBiometricConfirmationRequired_false() {
        FlutterSecureStorageConfig config = configFrom(
            FlutterSecureStorageConfig.PREF_OPTION_BIOMETRIC_CONFIRMATION_REQUIRED, "false"
        );
        assertFalse(config.isBiometricConfirmationRequired());
    }

    // -------------------------------------------------------------------------
    // migrateWithBackup
    // -------------------------------------------------------------------------

    @Test
    public void shouldMigrateWithBackup_defaultIsFalse() {
        assertFalse(new FlutterSecureStorageConfig(new HashMap<>()).shouldMigrateWithBackup());
    }

    @Test
    public void shouldMigrateWithBackup_trueWhenSet() {
        FlutterSecureStorageConfig config = configFrom(
            FlutterSecureStorageConfig.PREF_OPTION_MIGRATE_WITH_BACKUP, "true"
        );
        assertTrue(config.shouldMigrateWithBackup());
    }

    @Test
    public void toString_containsMigrateWithBackup() {
        FlutterSecureStorageConfig config = configFrom(
            FlutterSecureStorageConfig.PREF_OPTION_MIGRATE_WITH_BACKUP, "true"
        );
        assertTrue(config.toString().contains("migrateWithBackup=true"));
    }
}
