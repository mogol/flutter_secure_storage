// Isolated variant of harness_v9.dart: only the namespace-switch profile,
// no 'default' profile alongside it. v9.x has no storageNamespace concept, so
// every FlutterSecureStorage instance in an app shares ONE global (non
// namespaced) RSA key; a 'default' profile's migration completing first can
// delete that shared key before this profile's migration gets to use it -
// a real, separate bug, but a confound when isolating the namespace-switch
// path itself. This variant removes that confound.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tag = 'MIGTEST';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(body: Center(child: Text('migtest harness (v9, ns-only)'))),
  ));

  final profiles = <String, FlutterSecureStorage>{
    'namespace_migtest': const FlutterSecureStorage(
      aOptions: AndroidOptions(sharedPreferencesName: 'migtest_ns'),
    ),
  };

  final expected = <String, Map<String, String>>{
    'namespace_migtest': {
      'nk1': 'namespace_value_1',
    },
  };

  await runMigtest(profiles, expected);
}

Future<void> runMigtest(
  Map<String, FlutterSecureStorage> profiles,
  Map<String, Map<String, String>> expected,
) async {
  var pass = 0;
  var fail = 0;
  var wrote = 0;

  for (final profileName in profiles.keys) {
    final storage = profiles[profileName]!;
    final data = expected[profileName]!;
    for (final entry in data.entries) {
      try {
        final existing = await storage.read(key: entry.key);
        if (existing == null) {
          await storage.write(key: entry.key, value: entry.value);
          wrote++;
          debugPrint(
              '$_tag WRITE profile=$profileName key=${entry.key} result=OK');
        } else if (existing == entry.value) {
          pass++;
          debugPrint(
              '$_tag VERIFY profile=$profileName key=${entry.key} result=PASS');
        } else {
          fail++;
          debugPrint('$_tag VERIFY profile=$profileName key=${entry.key} '
              'result=FAIL expected=${entry.value} actual=$existing');
        }
      } catch (e) {
        fail++;
        debugPrint(
            '$_tag VERIFY profile=$profileName key=${entry.key} result=ERROR error=$e');
      }
    }
  }

  debugPrint('$_tag DONE wrote=$wrote pass=$pass fail=$fail');
}
