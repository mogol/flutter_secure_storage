## [3.2.1+2]
* Fix Gradle version in `gradle-wrapper.properties`. 

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
