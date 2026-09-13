// Pairs with harness_biometric_write.dart: same value, storageNamespace
// instead of sharedPreferencesName. Exercises BiometricNamespaceKeyRecovery's
// real two-BiometricPrompt flow (decrypt with the old location's key, then
// re-encrypt with the new location's key) on an actual device.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tag = 'MIGTEST';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
        body: Center(child: Text('migtest harness (biometric verify)'))),
  ));

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      storageNamespace: 'migtest_bio',
    ),
  );

  const key = 'bk1';
  const expected = 'biometric_value_1';

  try {
    final existing = await storage.read(key: key);
    if (existing == null) {
      await storage.write(key: key, value: expected);
      debugPrint('$_tag WRITE profile=biometric_migtest key=$key result=OK');
    } else if (existing == expected) {
      debugPrint('$_tag VERIFY profile=biometric_migtest key=$key result=PASS');
    } else {
      debugPrint('$_tag VERIFY profile=biometric_migtest key=$key '
          'result=FAIL expected=$expected actual=$existing');
    }
  } catch (e) {
    debugPrint('$_tag VERIFY profile=biometric_migtest key=$key result=ERROR error=$e');
  }

  debugPrint('$_tag DONE');
}
