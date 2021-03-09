import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FlutterSecureStorage {
  const FlutterSecureStorage();

  static const MethodChannel _channel =
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// Encrypts and saves the [key] with the given [value].
  ///
  /// If the key was already in the storage, its associated value is changed.
  /// If the value is null, deletes associated value for the given [key].
  /// [key] shouldn't be null.
  /// [value] required value
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// Can throw a [PlatformException].
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions = IOSOptions.defaultOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
  }) =>
      value != null
          ? _channel.invokeMethod('write', <String, dynamic>{
              'key': key,
              'value': value,
              'options': _selectOptions(iOptions, aOptions, lOptions)
            })
          : delete(key: key, iOptions: iOptions, aOptions: aOptions);

  /// Decrypts and returns the value for the given [key] or null if [key] is not in the storage.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// Can throw a [PlatformException].
  Future<String?> read({
    required String key,
    IOSOptions? iOptions = IOSOptions.defaultOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
  }) async {
    final String? value = await _channel.invokeMethod('read', <String, dynamic>{
      'key': key,
      'options': _selectOptions(iOptions, aOptions, lOptions)
    });
    return value;
  }

  /// Returns true if the storage contains the given [key].
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// Can throw a [PlatformException].
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions = IOSOptions.defaultOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
  }) async {
    final String? value =
        await read(key: key, iOptions: iOptions, aOptions: aOptions);
    return value != null;
  }

  /// Deletes associated value for the given [key].
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// Can throw a [PlatformException].
  Future<void> delete({
    required String key,
    IOSOptions? iOptions = IOSOptions.defaultOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
  }) =>
      _channel.invokeMethod('delete', <String, dynamic>{
        'key': key,
        'options': _selectOptions(iOptions, aOptions, lOptions)
      });

  /// Decrypts and returns all keys with associated values.
  ///
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// Can throw a [PlatformException].
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions = IOSOptions.defaultOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
  }) async {
    final Map? results = await _channel.invokeMethod<Map>(
        'readAll', <String, dynamic>{
      'options': _selectOptions(iOptions, aOptions, lOptions)
    });
    return results?.cast<String, String>() ?? <String, String>{};
  }

  /// Deletes all keys with associated values.
  ///
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// Can throw a [PlatformException].
  Future<void> deleteAll({
    IOSOptions? iOptions = IOSOptions.defaultOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
  }) =>
      _channel.invokeMethod('deleteAll', <String, dynamic>{
        'options': _selectOptions(iOptions, aOptions, lOptions)
      });

  /// Select correct options based on current platform
  Map<String, String>? _selectOptions(
      IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions) {
    if (Platform.isLinux) {
      return lOptions?.params;
    }
    return Platform.isIOS ? iOptions?.params : aOptions?.params;
  }
}

abstract class Options {
  const Options();

  Map<String, String> get params => _toMap();

  Map<String, String> _toMap() {
    throw Exception('Missing implementation');
  }
}

// KeyChain accessibility attributes as defined here:
// https://developer.apple.com/documentation/security/ksecattraccessible?language=objc
enum IOSAccessibility {
  // The data in the keychain can only be accessed when the device is unlocked.
  // Only available if a passcode is set on the device.
  // Items with this attribute do not migrate to a new device.
  passcode,

  // The data in the keychain item can be accessed only while the device is unlocked by the user.
  unlocked,

  // The data in the keychain item can be accessed only while the device is unlocked by the user.
  // Items with this attribute do not migrate to a new device.
  unlocked_this_device,

  // The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
  first_unlock,

  // The data in the keychain item cannot be accessed after a restart until the device has been unlocked once by the user.
  // Items with this attribute do not migrate to a new device.
  first_unlock_this_device,
}

class IOSOptions extends Options {
  const IOSOptions({
    String? groupId,
    String? accountName = IOSOptions.defaultAccountName,
    IOSAccessibility accessibility = IOSAccessibility.unlocked,
  })  : _groupId = groupId,
        _accessibility = accessibility,
        _accountName = accountName;

  static const defaultAccountName = 'flutter_secure_storage_service';

  static const IOSOptions defaultOptions = IOSOptions();

  final String? _groupId;
  final String? _accountName;
  final IOSAccessibility _accessibility;

  @override
  Map<String, String> _toMap() => <String, String>{
        'accessibility': describeEnum(_accessibility),
        if (_accountName != null) 'accountName': _accountName!,
        if (_groupId != null) 'groupId': _groupId!,
      };

  IOSOptions copyWith({
    String? groupId,
    String? accountName,
    IOSAccessibility? accessibility,
  }) =>
      IOSOptions(
        groupId: groupId ?? _groupId,
        accountName: accountName ?? _accountName,
        accessibility: accessibility ?? _accessibility,
      );
}

class AndroidOptions extends Options {
  @override
  Map<String, String> _toMap() => <String, String>{};
}

class LinuxOptions extends Options {
  @override
  Map<String, String> _toMap() {
    return <String, String>{};
  }
}
