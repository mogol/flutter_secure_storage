// Ignore name convention for constants for backwards compatibility
// ignore_for_file: constant_identifier_names

part of '../flutter_secure_storage.dart';

/// Algorithm used to encrypt/wrap the secret key in Android KeyStore.
enum KeyCipherAlgorithm {
  /// RSA/ECB/OAEPWithSHA-256AndMGF1Padding (default, API 23+).
  RSA_ECB_OAEPwithSHA_256andMGF1Padding,

  /// AES/GCM/NoPadding for KeyStore-based key wrapping (supports biometrics).
  AES_GCM_NoPadding,
}

/// Algorithm used to encrypt stored data.
enum StorageCipherAlgorithm {
  /// AES/GCM/NoPadding (default, API 23+).
  AES_GCM_NoPadding,
}

/// Controls which authentication methods are accepted when biometric
/// authentication is used.
enum AndroidBiometricType {
  /// Only Class 3 (strong) biometrics are accepted — e.g. fingerprint or
  /// hardware-backed face recognition. Device credentials (PIN, pattern,
  /// password) are explicitly rejected.
  strongBiometricOnly,

  /// Strong biometrics **or** device credentials (PIN, pattern, password) are
  /// accepted. This is the default.
  biometricOrDeviceCredential,
}

/// Specific options for Android platform.
class AndroidOptions extends Options {
  /// Standard secure storage using AES-GCM with RSA OAEP key wrapping.
  ///
  /// This is the default constructor with strong security:
  /// - RSA/ECB/OAEPWithSHA-256AndMGF1Padding for key protection
  /// - AES/GCM/NoPadding for data encryption
  /// - No biometric authentication required
  /// - API 23+ (Android 6.0+)
  ///
  /// For biometric authentication, use `AndroidOptions.biometric()`.
  ///
  /// Advanced users can customize cipher algorithms for specific use cases:
  /// - AES_GCM_NoPadding storage + RSA key ciphers (standard RSA wrapping)
  /// - AES_GCM_NoPadding storage + AES_GCM_NoPadding key
  ///   (KeyStore-based, supports biometrics)
  const AndroidOptions({
    bool resetOnError = true,
    bool migrateOnAlgorithmChange = true,
    bool migrateWithBackup = false,
    bool enforceBiometrics = false,
    bool requireBiometricsPerOperation = false,
    KeyCipherAlgorithm keyCipherAlgorithm =
        KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
    StorageCipherAlgorithm storageCipherAlgorithm =
        StorageCipherAlgorithm.AES_GCM_NoPadding,
    AndroidBiometricType biometricType =
        AndroidBiometricType.biometricOrDeviceCredential,
    bool requireBiometricConfirmation = true,
    this.preferencesKeyPrefix,
    this.storageNamespace,
    this.biometricPromptTitle,
    this.biometricPromptSubtitle,
    this.biometricPromptNegativeButton,
  }) : _resetOnError = resetOnError,
       _migrateOnAlgorithmChange = migrateOnAlgorithmChange,
       _migrateWithBackup = migrateWithBackup,
       _enforceBiometrics = enforceBiometrics,
       _requireBiometricsPerOperation = requireBiometricsPerOperation,
       _keyCipherAlgorithm = keyCipherAlgorithm,
       _storageCipherAlgorithm = storageCipherAlgorithm,
       _biometricType = biometricType,
       _requireBiometricConfirmation = requireBiometricConfirmation;

  /// Maximum security storage with optional biometric authentication.
  /// - Optionally requires biometric authentication
  ///   (set enforceBiometrics=true)
  /// - Strong authenticated encryption (AES/GCM/NoPadding 256-bit)
  /// - Hardware-backed AES key with optional user presence requirement
  /// - API 28+ (Android 9.0+)
  /// - When enforceBiometrics=false, gracefully degrades if biometrics
  ///   unavailable
  const AndroidOptions.biometric({
    bool resetOnError = true,
    bool migrateOnAlgorithmChange = true,
    bool migrateWithBackup = false,
    bool enforceBiometrics = false,
    bool requireBiometricsPerOperation = false,
    AndroidBiometricType biometricType =
        AndroidBiometricType.biometricOrDeviceCredential,
    bool requireBiometricConfirmation = true,
    this.preferencesKeyPrefix,
    this.storageNamespace,
    this.biometricPromptTitle,
    this.biometricPromptSubtitle,
    this.biometricPromptNegativeButton,
  }) : _resetOnError = resetOnError,
       _migrateOnAlgorithmChange = migrateOnAlgorithmChange,
       _migrateWithBackup = migrateWithBackup,
       _enforceBiometrics = enforceBiometrics,
       _requireBiometricsPerOperation = requireBiometricsPerOperation,
       _keyCipherAlgorithm = KeyCipherAlgorithm.AES_GCM_NoPadding,
       _storageCipherAlgorithm = StorageCipherAlgorithm.AES_GCM_NoPadding,
       _biometricType = biometricType,
       _requireBiometricConfirmation = requireBiometricConfirmation;

  /// When an error is detected, automatically reset all data. This will prevent
  /// fatal errors regarding an unknown key however keep in mind that it will
  /// PERMANENTLY erase the data when an error occurs.
  ///
  /// Defaults to true.
  final bool _resetOnError;

  /// When the encryption algorithm changes, automatically migrate existing data
  /// to the new algorithm. This preserves data across algorithm upgrades.
  /// If false, data will be lost when algorithm changes unless resetOnError
  /// is true.
  ///
  /// Defaults to true.
  final bool _migrateOnAlgorithmChange;

  /// Enable crash-resistant migration with backup protection.
  /// Creates backup copies of encrypted data before migration starts.
  /// If migration fails or crashes, data can be recovered from backup.
  /// Works in conjunction with migrateOnAlgorithmChange.
  ///
  /// Defaults to false.
  final bool _migrateWithBackup;

  /// Whether to enforce biometric/PIN authentication.
  ///
  /// When `true`, the plugin will throw an exception if the device
  /// has no PIN, pattern, password, or biometric enrolled. The key will
  /// be generated with setUserAuthenticationRequired(true).
  ///
  /// When `false` (default), the plugin will gracefully degrade
  /// to storing data without biometric protection if unavailable.
  /// The key will be generated with setUserAuthenticationRequired(false).
  ///
  /// **Security note:** Set to `true` for highly sensitive data
  /// that must never be stored without authentication.
  ///
  /// Defaults to false.
  final bool _enforceBiometrics;

  /// Whether a fresh biometric/PIN authentication is required for every
  /// `read`/`readAll`/`write` call, instead of only the first one.
  ///
  /// By default, once the app key has been unlocked (on the first call after
  /// the app starts), it is kept in memory and reused for later calls
  /// without prompting again. Setting this to `true` disables that reuse:
  /// the app key is decrypted fresh for each call and never cached, so a
  /// biometric prompt appears every time.
  ///
  /// Only takes effect when biometric authentication is actually active
  /// (i.e. combined with `AndroidOptions.biometric()` on a device that has
  /// biometrics/device credentials enrolled); otherwise this is a no-op.
  ///
  /// Defaults to false.
  final bool _requireBiometricsPerOperation;

  /// Algorithm used to encrypt the secret key.
  /// By default RSA/ECB/OAEPWithSHA-256AndMGF1Padding is used (API 23+).
  final KeyCipherAlgorithm _keyCipherAlgorithm;

  /// Algorithm used to encrypt stored data.
  /// By default AES/GCM/NoPadding is used (API 23+).
  final StorageCipherAlgorithm _storageCipherAlgorithm;

  /// Controls which authentication methods are accepted during biometric
  /// prompts.
  final AndroidBiometricType _biometricType;

  /// Whether the user must press an explicit confirmation button after
  /// passive biometric authentication (e.g. face recognition) succeeds.
  ///
  /// When `false`, passive biometrics can authenticate without requiring
  /// an additional button press, enabling lower-friction implicit flows.
  /// See [setConfirmationRequired](https://developer.android.com/identity/sign-in/biometric-auth#no-explicit-user-action).
  ///
  /// Only takes effect on Android 10 (API 29) and higher.
  ///
  /// Defaults to true.
  final bool _requireBiometricConfirmation;

  /// The prefix for a shared preference key. The prefix is used to make sure
  /// the key is unique to your application. An underscore (_) is added to the
  /// end of the prefix automatically. If not provided, a default prefix will
  /// be used.
  ///
  /// Example: preferencesKeyPrefix: "my_app" will result in a key like
  /// "my_app_key1".
  ///
  /// WARNING: If you change this you can't retrieve already saved preferences.
  final String? preferencesKeyPrefix;

  /// Provides full namespace isolation for this storage instance.
  ///
  /// When set, **all** storage artifacts are namespaced:
  /// - Data SharedPreferences
  /// - Config/algorithm markers
  /// - Android KeyStore aliases
  /// - Wrapped-key SharedPreferences
  ///
  /// This allows multiple `FlutterSecureStorage` instances to use different
  /// cipher algorithms without conflicting KeyStore entries or key storage.
  ///
  /// Prefer this over the legacy `sharedPreferencesName` (removed in v11)
  /// for namespace isolation.
  final String? storageNamespace;

  /// The title shown in the biometric authentication prompt.
  final String? biometricPromptTitle;

  /// The subtitle shown in the biometric authentication prompt.
  final String? biometricPromptSubtitle;

  /// The label for the negative (cancel) button shown in the biometric prompt.
  ///
  /// Required when [AndroidBiometricType.strongBiometricOnly] is used, or on
  /// Android 10 (API level 29) and lower, because device-credential fallback
  /// is unavailable and the system needs an explicit dismiss action.
  final String? biometricPromptNegativeButton;

  /// Default Android options with standard secure configuration.
  static const AndroidOptions defaultOptions = AndroidOptions();

  @override
  Map<String, String> toMap() => <String, String>{
    'resetOnError': '$_resetOnError',
    'migrateOnAlgorithmChange': '$_migrateOnAlgorithmChange',
    'migrateWithBackup': '$_migrateWithBackup',
    'enforceBiometrics': '$_enforceBiometrics',
    'requireBiometricsPerOperation': '$_requireBiometricsPerOperation',
    'keyCipherAlgorithm': _keyCipherAlgorithm.name,
    'storageCipherAlgorithm': _storageCipherAlgorithm.name,
    'biometricType': _biometricType.name,
    'requireBiometricConfirmation': '$_requireBiometricConfirmation',
    'preferencesKeyPrefix': preferencesKeyPrefix ?? '',
    'storageNamespace': storageNamespace ?? '',
    'biometricPromptTitle': biometricPromptTitle ?? 'Authenticate to access',
    'biometricPromptSubtitle':
        biometricPromptSubtitle ?? 'Use biometrics or device credentials',
    'biometricPromptNegativeButton': biometricPromptNegativeButton ?? 'Cancel',
  };

  /// Creates a copy of this AndroidOptions with the given fields replaced.
  AndroidOptions copyWith({
    bool? resetOnError,
    bool? migrateOnAlgorithmChange,
    bool? migrateWithBackup,
    bool? enforceBiometrics,
    bool? requireBiometricsPerOperation,
    KeyCipherAlgorithm? keyCipherAlgorithm,
    StorageCipherAlgorithm? storageCipherAlgorithm,
    AndroidBiometricType? biometricType,
    bool? requireBiometricConfirmation,
    String? preferencesKeyPrefix,
    String? storageNamespace,
    String? biometricPromptTitle,
    String? biometricPromptSubtitle,
    String? biometricPromptNegativeButton,
  }) => AndroidOptions(
    resetOnError: resetOnError ?? _resetOnError,
    migrateOnAlgorithmChange:
        migrateOnAlgorithmChange ?? _migrateOnAlgorithmChange,
    migrateWithBackup: migrateWithBackup ?? _migrateWithBackup,
    enforceBiometrics: enforceBiometrics ?? _enforceBiometrics,
    requireBiometricsPerOperation:
        requireBiometricsPerOperation ?? _requireBiometricsPerOperation,
    keyCipherAlgorithm: keyCipherAlgorithm ?? _keyCipherAlgorithm,
    storageCipherAlgorithm: storageCipherAlgorithm ?? _storageCipherAlgorithm,
    biometricType: biometricType ?? _biometricType,
    requireBiometricConfirmation:
        requireBiometricConfirmation ?? _requireBiometricConfirmation,
    preferencesKeyPrefix: preferencesKeyPrefix ?? this.preferencesKeyPrefix,
    storageNamespace: storageNamespace ?? this.storageNamespace,
    biometricPromptTitle: biometricPromptTitle ?? this.biometricPromptTitle,
    biometricPromptSubtitle:
        biometricPromptSubtitle ?? this.biometricPromptSubtitle,
    biometricPromptNegativeButton:
        biometricPromptNegativeButton ?? this.biometricPromptNegativeButton,
  );
}
