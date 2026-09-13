// Pairs with harness_biometric_v11_write.dart. Bare AndroidOptions.biometric(),
// no storageNamespace: this only correctly targets the same data prefs file
// because the write side used storageNamespace='FlutterSecureStorage' (the
// literal default name). Exercises BiometricNamespaceKeyRecovery's real
// two-BiometricPrompt flow (decrypt with the old location's key, then
// re-encrypt with the new location's key) on an actual device, on v11.x.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tag = 'MIGTEST';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
        body: Center(child: Text('migtest harness (biometric v11 verify)'))),
  ));

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(),
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
