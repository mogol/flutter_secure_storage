part of flutter_secure_storage;

class AndroidOptions extends Options {
  const AndroidOptions({bool encryptedSharedPreferences = false})
      : _encryptedSharedPreferences = encryptedSharedPreferences;

  /// EncryptedSharedPrefences are only available on API 23 and greater
  final bool _encryptedSharedPreferences;

  static const AndroidOptions defaultOptions = const AndroidOptions();

  @override
  Map<String, String> toMap() => <String, String>{
        'encryptedSharedPreferences': '$_encryptedSharedPreferences'
      };

  AndroidOptions copyWith({
    bool? encryptedSharedPreferences,
  }) =>
      AndroidOptions(
        encryptedSharedPreferences:
            encryptedSharedPreferences ?? _encryptedSharedPreferences,
      );
}
