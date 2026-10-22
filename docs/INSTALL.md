# التثبيت والبناء — مدير حياتي

## تثبيت التطبيق على الهاتف

1. انسخ الملف `app-release.apk` إلى الهاتف (بكابل USB، أو بإرساله لنفسك في تطبيق مراسلة).
2. افتح الملف من مدير الملفات. سيطلب أندرويد السماح بتثبيت التطبيقات من هذا المصدر. اسمح بذلك لمدير الملفات فقط.
3. اضغط «تثبيت». بعد الانتهاء يمكنك إلغاء ذلك السماح من الإعدادات.
4. عند التحديث لاحقاً ثبّت ملف APK الجديد فوق القديم. بياناتك تبقى، بشرط أن يكون الملف موقّعاً بنفس مفتاح التوقيع (انظر قسم التوقيع أدناه).

## أول تشغيل

1. اختر اللغة: العربية أو English أو کوردی. يمكنك تغييرها لاحقاً من الإعدادات.
2. اختر رمز PIN من 6 أرقام وأدخله مرتين.
3. فعّل البصمة إن أردت. يبقى الرمز يعمل دائماً كبديل.
4. اقرأ تحذير النسخ الاحتياطي وضع علامة على «فهمت»، ثم اضغط «ابدأ».

## ⚠️ النسخ الاحتياطي

بياناتك موجودة على هذا الهاتف فقط، ومشفّرة. إذا فقدت الهاتف أو حذفت التطبيق بدون نسخة احتياطية، تضيع كل البيانات ولا يمكن استرجاعها.

- من **الإعدادات ← النسخ الاحتياطي والاسترجاع** أنشئ نسخة بكلمة مرور قوية.
- احفظ الملف `.plmbackup` **خارج الهاتف**: على اللابتوب، أو ذاكرة USB، أو في تطبيق مراسلة.
- لا تنسَ كلمة مرور النسخة. بدونها لا يمكن فتح الملف، ولا يوجد أي طريقة لاسترجاعها.

## البناء من الكود (للمطوّر)

```bash
flutter pub get
dart run build_runner build -d
flutter test
flutter build apk --release
```

الملف الناتج: `build/app/outputs/flutter-apk/app-release.apk`.

### توقيع نسخة الإصدار

- مفتاح التوقيع موجود خارج المستودع في `C:\Users\pc\.keystores\life-manager-release.jks`.
- ملف `android/key.properties` مستثنى من git ويشير إلى المفتاح.
- إذا فُقد `key.properties`: انسخ `android/key.properties.example` إلى `android/key.properties` واكتب فيه كلمات المرور الصحيحة.
- **احتفظ بنسخة احتياطية من ملف `.jks` ومن كلمات مروره** في مكان آمن خارج هذا الجهاز. بدونها لن يتمكن أي تحديث مستقبلي من التثبيت فوق التطبيق، وستضطر لحذفه (وتفقد بياناته إلا إذا كانت لديك نسخة احتياطية).
- بدون `key.properties` يفشل بناء الإصدار عمداً برسالة تشير إلى هذا الملف.

### فحوصات على الجهاز

اختبارات التشفير وSQLCipher على الهاتف نفسه موجودة في `integration_test/`. تُشغّل والهاتف موصول بتصحيح USB:

```bash
flutter test integration_test -d <device-id>
```

الحالة: لم تُشغّل بعد على هاتف حقيقي (لا يوجد هاتف موصول أثناء بناء المرحلة 1).

---

# Install and build — My Life Manager

## Install on the phone

1. Copy `app-release.apk` to the phone (USB cable, or send it to yourself in a messenger).
2. Open it from the file manager. Android asks to allow installing apps from this source; allow it for the file manager only.
3. Tap Install. You can turn that permission off again afterwards.
4. To update later, install the new APK over the old one. Your data stays, as long as the APK is signed with the same release key (see signing below).

## First run

1. Pick a language: العربية, English or کوردی. You can change it later in Settings.
2. Choose a 6-digit PIN and enter it twice.
3. Turn on fingerprint unlock if you like. The PIN always works as a fallback.
4. Read the backup warning, tick "I understand", and tap Start.

## ⚠️ Backups

Your data lives only on this phone, encrypted. If you lose the phone or uninstall the app without a backup, everything is gone for good.

- In **Settings → Backup & restore**, create a backup with a strong password.
- Keep the `.plmbackup` file **off the phone**: a laptop, a USB stick, or a messenger.
- Don't forget the backup password. Without it the file can't be opened, and there is no recovery.

## Building from source

```bash
flutter pub get
dart run build_runner build -d
flutter test
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

### Release signing

- The release keystore lives outside the repo at `C:\Users\pc\.keystores\life-manager-release.jks`.
- `android/key.properties` is git-ignored and points to it.
- If `key.properties` is lost, copy `android/key.properties.example` to `android/key.properties` and fill in the real passwords.
- **Back up the `.jks` file and its passwords** somewhere safe off this machine. Without them no future update can install over the app; it would have to be uninstalled, losing its data unless you have a backup.
- Without `key.properties`, release builds fail on purpose with a message pointing here.

### On-device checks

The crypto and SQLCipher tests that must run on the phone itself are in `integration_test/`. Run them with the phone connected over USB debugging:

```bash
flutter test integration_test -d <device-id>
```

Status: not yet run on a real phone (no phone was connected while Phase 1 was built).
