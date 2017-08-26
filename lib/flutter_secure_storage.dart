import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

class FlutterSecureStorage {
  static const MethodChannel _channel =
  const MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Future write({@required String key, @required String value}) =>
      _channel.invokeMethod("write", <String, String>{
        "key": key,
        "value": value});

  Future read({@required String key}) =>
      _channel.invokeMethod("read", <String, String>{
        "key": key
      });

  Future delete({@required String key}) =>
      _channel.invokeMethod("delete", <String, String>{
        "key": key
      });
}
