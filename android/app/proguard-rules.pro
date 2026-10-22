# Flutter's own rules are added by the Flutter Gradle plugin, and the plugins
# (local_auth, flutter_secure_storage, file_picker, cryptography_flutter) ship
# consumer rules. SQLCipher is reached through Dart FFI, not Java, so it needs none.

# BiometricPrompt callbacks are created reflectively by AndroidX.
-keep class androidx.biometric.** { *; }
