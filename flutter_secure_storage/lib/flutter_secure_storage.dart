library flutter_secure_storage;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

part './options/android_options.dart';
part './options/apple_options.dart';
part './options/ios_options.dart';
part './options/linux_options.dart';
part './options/macos_options.dart';
part './options/web_options.dart';
part './options/windows_options.dart';

class FlutterSecureStorage {
  final IOSOptions iOptions;
  final AndroidOptions aOptions;
  final LinuxOptions lOptions;
  final WindowsOptions wOptions;
  final WebOptions webOptions;
  final MacOsOptions mOptions;

  const FlutterSecureStorage({
    this.iOptions = IOSOptions.defaultOptions,
    this.aOptions = AndroidOptions.defaultOptions,
    this.lOptions = LinuxOptions.defaultOptions,
    this.wOptions = WindowsOptions.defaultOptions,
    this.webOptions = WebOptions.defaultOptions,
    this.mOptions = MacOsOptions.defaultOptions,
  });

  static const UNSUPPORTED_PLATFORM = 'unsupported_platform';
  static final _platform = FlutterSecureStoragePlatform.instance;

  /// Encrypts and saves the [key] with the given [value].
  ///
  /// If the key was already in the storage, its associated value is changed.
  /// If the value is null, deletes associated value for the given [key].
  /// [key] shouldn't be null.
  /// [value] required value
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      value == null
          ? _platform.delete(
              key: key,
              options: _selectOptions(
                iOptions,
                aOptions,
                lOptions,
                webOptions,
                mOptions,
                wOptions,
              ),
            )
          : _platform.write(
              key: key,
              value: value,
              options: _selectOptions(
                iOptions,
                aOptions,
                lOptions,
                webOptions,
                mOptions,
                wOptions,
              ),
            );

  /// Decrypts and returns the value for the given [key] or null if [key] is not in the storage.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _platform.read(
        key: key,
        options: _selectOptions(
          iOptions,
          aOptions,
          lOptions,
          webOptions,
          mOptions,
          wOptions,
        ),
      );

  /// Returns true if the storage contains the given [key].
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _platform.containsKey(
        key: key,
        options: _selectOptions(
          iOptions,
          aOptions,
          lOptions,
          webOptions,
          mOptions,
          wOptions,
        ),
      );

  /// Deletes associated value for the given [key].
  ///
  /// If the given [key] does not exist, nothing will happen.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _platform.delete(
        key: key,
        options: _selectOptions(
          iOptions,
          aOptions,
          lOptions,
          webOptions,
          mOptions,
          wOptions,
        ),
      );

  /// Decrypts and returns all keys with associated values.
  ///
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _platform.readAll(
        options: _selectOptions(
          iOptions,
          aOptions,
          lOptions,
          webOptions,
          mOptions,
          wOptions,
        ),
      );

  /// Deletes all keys with associated values.
  ///
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) =>
      _platform.deleteAll(
        options: _selectOptions(
          iOptions,
          aOptions,
          lOptions,
          webOptions,
          mOptions,
          wOptions,
        ),
      );

  /// Select correct options based on current platform
  Map<String, String> _selectOptions(
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  ) {
    if (kIsWeb) {
      return webOptions?.params ?? this.webOptions.params;
    } else if (Platform.isLinux) {
      return lOptions?.params ?? this.lOptions.params;
    } else if (Platform.isIOS) {
      return iOptions?.params ?? this.iOptions.params;
    } else if (Platform.isAndroid) {
      return aOptions?.params ?? this.aOptions.params;
    } else if (Platform.isWindows) {
      return wOptions?.params ?? this.wOptions.params;
    } else if (Platform.isMacOS) {
      return mOptions?.params ?? this.mOptions.params;
    } else {
      throw UnsupportedError(UNSUPPORTED_PLATFORM);
    }
  }
}
