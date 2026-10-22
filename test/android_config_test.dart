import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android hardening from being lost in a later edit (spec §9, §15).
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('MainActivity blocks screenshots and supports BiometricPrompt', () {
    final activity = read('android/app/src/main/kotlin/com/personal/lifemanager/MainActivity.kt');
    expect(activity, contains('FlutterFragmentActivity'));
    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
  });

  test('manifest: internet over TLS only, no auto-backup, localized label, biometric permission', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    // Phase 2: online AI (Groq) needs the network; plain HTTP stays off.
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:label="@string/app_name"'));
    expect(manifest, contains('android.permission.USE_BIOMETRIC'));
  });

  test('app name resources exist in Arabic and English', () {
    expect(read('android/app/src/main/res/values/strings.xml'), contains('My Life Manager'));
    expect(read('android/app/src/main/res/values-ar/strings.xml'), contains('مدير حياتي'));
  });

  test('release signing comes from key.properties', () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('key.properties'));
    expect(gradle, contains('minSdk = 26'));
    expect(gradle, contains('docs/INSTALL.md'));
  });

  test('signing secrets are ignored by git', () {
    final ignore = read('.gitignore');
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('*.jks'));
  });
}
