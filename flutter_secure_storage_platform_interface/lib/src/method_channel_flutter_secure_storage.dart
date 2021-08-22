part of flutter_secure_storage_platform_interface;

const MethodChannel _channel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class MethodChannelFlutterSecureStorage extends FlutterSecureStoragePlatform {
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      (await _channel.invokeMethod<bool>(
        'containsKey',
        {
          'key': key,
          'options': options,
        },
      ))!;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) =>
      _channel.invokeMethod<void>(
        'delete',
        {
          'key': key,
          'options': options,
        },
      );

  @override
  Future<void> deleteAll({
    required Map<String, String> options,
  }) =>
      _channel.invokeMethod<void>(
        'deleteAll',
        {
          'options': options,
        },
      );

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) =>
      _channel.invokeMethod<String?>(
        'read',
        {
          'key': key,
          'options': options,
        },
      );

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final results = await _channel.invokeMethod<Map>(
      'readAll',
      {
        'options': options,
      },
    );

    return results?.cast<String, String>() ?? <String, String>{};
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) =>
      _channel.invokeMethod<void>('write', {
        'key': key,
        'value': value,
        'options': options,
      });
}
