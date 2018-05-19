import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

class FlutterSecureStorage {
  static const MethodChannel _channel =
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Future<void> write({@required String key, @required String value}) async =>
      _channel
          .invokeMethod('write', <String, String>{'key': key, 'value': value});

  Future<String> read({@required String key}) async {
    final String value =
        await _channel.invokeMethod('read', <String, String>{'key': key});
    return value;
  }

  Future<void> delete({@required String key}) =>
      _channel.invokeMethod('delete', <String, String>{'key': key});

  Future<Map<String, String>> readAll() async {
    final Map results = await _channel.invokeMethod('readAll');
    return results.cast<String, String>();
  }

  Future<void> deleteAll() => _channel.invokeMethod('deleteAll');
}
