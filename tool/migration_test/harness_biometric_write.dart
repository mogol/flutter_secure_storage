// Biometric namespace-switch harness, write side: AndroidOptions.biometric()
// with sharedPreferencesName set. Pair with harness_biometric_verify.dart
// (same value, switched to storageNamespace) on the SAME ref/build to
// exercise BiometricNamespaceKeyRecovery's real two-BiometricPrompt flow on
// an actual device. Requires a real fingerprint/PIN confirmation - not
// automatable, run manually (see tool/migration_test/run.sh header for the
// general pattern; this pair isn't wired into its automatic harness
// selection).
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tag = 'MIGTEST';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home:
        Scaffold(body: Center(child: Text('migtest harness (biometric write)'))),
  ));

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      sharedPreferencesName: 'migtest_bio',
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
