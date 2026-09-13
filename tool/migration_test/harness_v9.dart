// Migration-test harness overlay for pre-storageNamespace versions (v9.x, v10.0.x).
//
// Not part of the plugin; copied over example/lib/main.dart by
// tool/migration_test/run.sh before building each stage. Self-determines
// write-vs-verify: a null read means nothing was written yet (fresh install),
// a non-null read means data survived from a previous stage and gets checked
// against the expected value. Never overwrites existing data.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tag = 'MIGTEST';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(body: Center(child: Text('migtest harness (v9)'))),
  ));

  final profiles = <String, FlutterSecureStorage>{
    'default': const FlutterSecureStorage(),
    // v9.x/v10.0.x predate storageNamespace; sharedPreferencesName is the
    // option a real app would have been using at this stage.
    'namespace_migtest': const FlutterSecureStorage(
      aOptions: AndroidOptions(sharedPreferencesName: 'migtest_ns'),
    ),
  };

  final expected = <String, Map<String, String>>{
    'default': {
      'k1': 'default_value_1',
      'k2': 'default_value_2',
    },
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
