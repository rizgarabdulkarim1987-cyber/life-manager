# Flutter's own rules are added by the Flutter Gradle plugin, and the plugins
# (local_auth, flutter_secure_storage, file_picker, cryptography_flutter) ship
# consumer rules. SQLCipher is reached through Dart FFI, not Java, so it needs none.

# BiometricPrompt callbacks are created reflectively by AndroidX.
-keep class androidx.biometric.** { *; }

# whisper_ggml (on-device speech) loads a forked ffmpeg-kit through JNI and reflection; its README
# documents these rules, and the plugin also ships them as consumer rules. Kept here so a release
# build does not depend on the plugin's rules being merged.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**
-keepclasseswithmembernames class * {
    native <methods>;
}
