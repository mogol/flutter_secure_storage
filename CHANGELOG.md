## [3.3.5]
* Fixes thread safety issues in android code to close [161](https://github.com/mogol/flutter_secure_storage/issues/161). Thanks [koskimas](https://github.com/koskimas)

## [3.3.4]
* Fix Android hanging UI on StorageCipher initialization [#116](https://github.com/mogol/flutter_secure_storage/issues/116) by [morrica](https://github.com/morrica)
* Fix crash only observed for v2 apps [#124](https://github.com/mogol/flutter_secure_storage/pull/124) by [lidongze91](https://github.com/lidongze91)
* Fix crash when generating keys in android with RTL locales [#132](https://github.com/mogol/flutter_secure_storage/pull/132) by [iassal](https://github.com/iassal)
* Fix returning the error as String rather than Exception [#134](https://github.com/mogol/flutter_secure_storage/issues/134) by [wytesk133](https://github.com/wytesk133)s
* Fix Android crash onDetachedFromEngine when init fails [#144](https://github.com/mogol/flutter_secure_storage/issues/144) by [iassal](https://github.com/iassal)
* Handle null value at write function [#95](https://github.com/mogol/flutter_secure_storage/issues/95) by [ewertonrp](https://github.com/ewertonrp)    
*  Add support for containsKey [#139](https://github.com/mogol/flutter_secure_storage/issues/139) by [iassal](https://github.com/iassal)    

## [3.3.3]
* Fix compatibility with non-AndroidX project. [AndroidX Migration](https://flutter.dev/docs/development/androidx-migration) is recommended.

## [3.3.2]
* Migrate to Android v2 embedder.
* Adds support for specifying [iOS Keychain Item Accessibility](https://developer.apple.com/documentation/security/keychain_services/keychain_items/restricting_keychain_item_accessibility?language=objc).

## [3.3.1+2]
* Fix iOS build warning [Issue 30](https://github.com/mogol/flutter_secure_storage/issues/30)

## [3.3.1+1]
* Fix Android Manifest error [Issue 77](https://github.com/mogol/flutter_secure_storage/issues/77) and [Issue 79](https://github.com/mogol/flutter_secure_storage/issues/79). Thanks [nate-eisner](https://github.com/nate-eisner).

## [3.3.1]
* Fix crash without [iOSOptions](https://github.com/mogol/flutter_secure_storage/issues/73).

## [3.3.0]
* Added groupId for iOS keychain sharing. Thanks [Maleandr](https://github.com/Maleandr). 
* Fix Gradle version in `gradle-wrapper.properties`. Thanks [blasten](https://github.com/blasten). 
* Added minimum sdk requirement on AndroidManifest. Thanks [lidongze91](https://github.com/lidongze91). 

## [3.2.1]
* Fix Android 9.0 Pie [KeyStore exception](https://github.com/mogol/flutter_secure_storage/issues/46). 

## [3.2.0]
* **Breaking change**. Migrate from the deprecated original Android Support Library to AndroidX. This shouldn't result in any functional changes, but it requires any Android apps using this plugin to [also migrate](https://developer.android.com/jetpack/androidx/migrate) if they're using the original support library. Thanks [I-am-original](https://github.com/I-am-original).
* Enable StrongBox on Android devices that support it. Thanks [bbedward](https://github.com/bbedward).

## [3.1.3]
* Fix Android 9.0 Pie KeyStore exception. Thanks [hacker1024](https://github.com/hacker1024)

## [3.1.2]
* Added recreating secretKey if its decoding failed. Fix for [unwrap key](https://github.com/mogol/flutter_secure_storage/issues/13). Thanks [hnvn](https://github.com/hnvn).

## [3.1.1]
* Suppress warning about unchecked operations when compiling for Android.

## [3.1.0]
* Added `readAll` and `deleteAll`.

## [3.0.0]
* **Breaking change**. Changed payloads encryption for Android from RSA to AES, AES secret key is encrypted with RSA. 

## [2.0.0]````
* **Breaking change**. Changed key alias to fix Android 4.4.2 issue. The plugin isn't able to get previous stored data. 

## [1.0.0]
* Bump version

## [0.0.1]

* Initial release
