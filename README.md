# flutter_secure_storage

A Flutter plugin to store data in secure storage:
* [Keychain](https://developer.apple.com/library/content/documentation/Security/Conceptual/keychainServConcepts/01introduction/introduction.html#//apple_ref/doc/uid/TP30000897-CH203-TP1) is used for iOS 
* AES encryption is used for Android. AES secret key is encrypted with RSA and RSA key is stored in [KeyStore](https://developer.android.com/training/articles/keystore.html)

*Note* KeyStore was introduced in Android 4.3 (API level 18). The plugin wouldn't work for earlier versions.

## Getting Started
```dart
// Create storage
final storage = new FlutterSecureStorage();

// Read value 
String value = await storage.read(key: key);

// Read all values
Map<String, String> allValues = await storage.readAll();

// Delete value 
await storage.delete(key: key);

// Delete all 
await storage.deleteAll();

// Write value 
await storage.write(key: key, value: value);

```

### Configure Android version 
In `[project]/android/app/build.gradle` set `minSdkVersion` to >= 18.
```
android {
    ...
    
    defaultConfig {
        ...
        minSdkVersion 18
        ...
    }

}
```
*Note* By default Android backups data on Google Drive. It can cause exception java.security.InvalidKeyException:Failed to unwrap key. 
You need to [disable backup](https://developer.android.com/guide/topics/data/autobackup#EnablingAutoBackup) to fix this issue or to [exclude sharedprefs](https://developer.android.com/guide/topics/data/autobackup#IncludingFiles) `FlutterSecureStorage` used by the plugin.

