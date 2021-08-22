part of flutter_secure_storage;

class AndroidOptions extends Options {
  const AndroidOptions(
      {bool encryptedSharedPreferences = false, bool resetOnError = false})
      : _encryptedSharedPreferences = encryptedSharedPreferences,
        _resetOnError = resetOnError;

  /// EncryptedSharedPrefences are only available on API 23 and greater
  final bool _encryptedSharedPreferences;

  /// When an error is detected, automatically reset all data. This will prevent
  /// fatal errors regarding an unknown key however keep in mind that it will
  /// PERMANENLTY erase the data when an error occurs.
  ///
  /// Defaults to false.
  final bool _resetOnError;

  static const AndroidOptions defaultOptions = AndroidOptions();

  @override
  Map<String, String> toMap() => <String, String>{
        'encryptedSharedPreferences': '$_encryptedSharedPreferences',
        'resetOnError': '$_resetOnError'
      };

  AndroidOptions copyWith(
          {bool? encryptedSharedPreferences, bool? resetOnError}) =>
      AndroidOptions(
          encryptedSharedPreferences:
              encryptedSharedPreferences ?? _encryptedSharedPreferences,
          resetOnError: resetOnError ?? _resetOnError);
}
