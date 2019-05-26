import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

class FlutterSecureStorage {
  const FlutterSecureStorage();

  static const MethodChannel _channel = const MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// Encrypts and saves the [key] with the given [value].
  ///
  /// If the key was already in the storage, its associated value is changed.
  /// [value] and [key] shoudn't be null.
  /// [groupId] optional group id for iOS keychain sharing
  /// Can throw a [PlatformException].
  Future<void> write({@required String key, @required String value, String groupId}) async =>
      _channel.invokeMethod('write', <String, String>{'key': key, 'value': value, 'groupId': groupId});

  /// Decrypts and returns the value for the given [key] or null if [key] is not in the storage.
  ///
  /// [key] shoudn't be null.
  /// [groupId] optional group id for iOS keychain sharing
  /// Can throw a [PlatformException].
  Future<String> read({@required String key, String groupId}) async {
    final String value = await _channel.invokeMethod('read', <String, String>{'key': key, 'groupId': groupId});
    return value;
  }

  /// Deletes associated value for the given [key].
  ///
  /// [key] shoudn't be null.
  /// Can throw a [PlatformException].
  Future<void> delete({@required String key, String groupId}) =>
      _channel.invokeMethod('delete', <String, String>{'key': key, 'groupId': groupId});

  /// Decrypts and returns all keys with associated values.
  ///
  /// [groupId] optional group id for iOS keychain sharing
  /// Can throw a [PlatformException].
  Future<Map<String, String>> readAll({String groupId}) async {
    final Map results = await _channel.invokeMethod('readAll', <String, String>{'groupId': groupId});
    return results.cast<String, String>();
  }

  /// Deletes all keys with associated values.
  ///
  /// [groupId] optional group id for iOS keychain sharing
  /// Can throw a [PlatformException].
  Future<void> deleteAll({String groupId}) => _channel.invokeMethod('deleteAll', <String, String>{'groupId': groupId});
}
