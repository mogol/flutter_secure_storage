// Biometric namespace-switch harness for v11.x, write side. sharedPreferencesName
// doesn't exist on v11, so the only way to give the write side a distinct legacy
// shape is storageNamespace='FlutterSecureStorage' (the literal DEFAULT_PREF_NAME) -
// same trick as harness_v11_recover_write.dart. Pair with
// harness_biometric_v11_verify.dart (bare AndroidOptions.biometric(), no
// storageNamespace) on the SAME ref/build to exercise BiometricNamespaceKeyRecovery's
// real two-BiometricPrompt flow on an actual device. Requires a real fingerprint/PIN
// confirmation - not automatable, run manually.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tag = 'MIGTEST';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
        body: Center(child: Text('migtest harness (biometric v11 write)'))),
  ));

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      storageNamespace: 'FlutterSecureStorage',
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
