
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterSecureStorageLinux {
  static const MethodChannel _channel =
      const MethodChannel('flutter_secure_storage_linux');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
