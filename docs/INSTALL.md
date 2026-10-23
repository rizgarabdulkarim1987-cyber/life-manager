# التثبيت والبناء — مدير حياتي

## تثبيت التطبيق على الهاتف

1. انسخ الملف `app-arm64-v8a-release.apk` إلى الهاتف (بكابل USB، أو بإرساله لنفسك في تطبيق مراسلة). إذا رفض الهاتف التثبيت لأنه «غير متوافق» فهو هاتف قديم بنظام 32-bit؛ استخدم `app-armeabi-v7a-release.apk` بدلاً منه.
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
flutter build apk --release --split-per-abi
```

الملفات الناتجة في `build/app/outputs/flutter-apk/`، ملف لكل نوع معالج. للهاتف استخدم `app-arm64-v8a-release.apk` (حوالي 47 MB). أما `flutter build apk --release` بدون `--split-per-abi` فيبني ملفاً واحداً لكل الأنواع حجمه حوالي 150 MB.

استمر على `--split-per-abi`: يضيف فلاتر 2000 إلى رقم الإصدار في ملف arm64 (مثلاً 2002 بدل 2)، فإذا ثبّتّ بعده الملف الشامل يرفضه أندرويد لأن رقمه أقل.

إذا بنيت نسخة debug قبلها، فقد يفشل بناء الإصدار بخطأ `package dev.flutter.plugins.integration_test does not exist`. السبب ملف مولَّد قديم؛ نفّذ `flutter clean` (أو احذف `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`) ثم أعد البناء.

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

## المرحلة 2: الذكاء الاصطناعي والصوت

- **التحديث فوق المرحلة 1:** ثبّت الـ APK الجديد فوق القديم؛ بياناتك تبقى لأن التوقيع واحد. ومع ذلك أنشئ نسخة احتياطية قبل التحديث.
- **مفتاح Groq (اختياري):** أنشئ مفتاحاً مجانياً من موقع Groq، ثم ألصقه في **الإعدادات ← الذكاء الاصطناعي**. يُحفظ في التخزين الآمن للهاتف فقط، ويدخل داخل النسخة الاحتياطية المشفّرة، ولا يظهر في أي سجل.
- **النموذج الصوتي بدون إنترنت:** من نفس الشاشة نزّل النموذج عبر Wi-Fi. النموذج `small` حجمه نحو 465 ميغابايت و`base` نحو 141 ميغابايت. يُتحقق من سلامة الملف بعد التنزيل، ويمكن حذفه في أي وقت.
- **ما الذي يُرسل إلى Groq؟** فقط تسجيلك الصوتي (عند التفريغ عبر Groq)، ونص ما قلته أو كتبته مع التاريخ والوقت وأسماء حساباتك ومساحات العمل والفئات والصناديق. لا أرصدة ولا معاملات سابقة ولا PIN ولا نسخ احتياطية ولا الخزنة. يسألك التطبيق قبل أول إرسال، ويمكنك الرفض فيبقى كل شيء على الهاتف.
- **إيقاف الذكاء الاصطناعي عبر الإنترنت:** من **الإعدادات ← الذكاء الاصطناعي** أوقف «استخدام الذكاء الاصطناعي عبر الإنترنت»؛ يبقى المحلل المحلي والنموذج الصوتي على الهاتف يعملان، وتختفي أزرار «أكمل بالذكاء الاصطناعي».
- **الأذونات:** الإنترنت، والميكروفون، والبصمة فقط.
- **اختبارات الجهاز:** `whisper_device_test` وبقية اختبارات `integration_test` لم تُشغّل بعد على هاتف حقيقي: كان هاتف موصولاً أثناء بناء المرحلة 2 لكن لم تُشغَّل عليه لأن الاختبار يثبّت نسخة debug بتوقيع مختلف فوق تطبيقك المثبّت. شغّلها على هاتف اختبار.

## المرحلة 3: الخزنة

- **التحديث فوق المرحلة 2:** ثبّت الـ APK الجديد (الإصدار 1.2.0) فوق القديم؛ بياناتك تبقى. أنشئ نسخة احتياطية قبل التحديث. تتحوّل قاعدة البيانات إلى الإصدار 3 تلقائياً وتُضاف إليها جداول خزنة فارغة.
- **إنشاء الخزنة:** افتح تبويب **الخزنة** ← «ابدأ». اختر **كلمة مرور رئيسية** (10 أحرف على الأقل؛ الجملة الطويلة أفضل). هي غير الـ PIN، ولا يمكن استرجاعها.
- **مفتاح الاسترداد:** يظهر مرة واحدة (8 مجموعات من 4 أحرف). **اكتبه على ورقة واحفظها في مكان آمن خارج الهاتف**، ثم اكتبه في التطبيق لتأكيده. إذا نسيت كلمة المرور الرئيسية فهو الطريقة الوحيدة لفتح الخزنة، وعندها يُطلب منك اختيار كلمة مرور جديدة. إذا فقدت الاثنين معاً فالخزنة تبقى مقفلة إلى الأبد: لا يوجد حذف ولا استرجاع في هذه المرحلة.
- **الفتح بالبصمة (اختياري):** من آخر خطوة في الإعداد أو من **إعدادات الخزنة**. يتوقف تلقائياً عند إضافة بصمة جديدة للهاتف وبعد استرجاع نسخة احتياطية؛ افتح بكلمة المرور الرئيسية ثم فعّله من جديد. رمز قفل الجهاز وحده لا يفتح الخزنة.
- **القفل:** تُقفل الخزنة بعد دقيقتين بلا لمس (يمكن تغييرها: 1 أو 2 أو 5 أو 10 دقائق)، وفور الخروج من التطبيق، وعند قفل التطبيق. عرض كلمة المرور أو نسخها يطلب منك التأكيد من جديد (بصمة أو كلمة المرور الرئيسية) إن مرّت أكثر من 30 ثانية على آخر تأكيد، وتختفي القيمة المعروضة بعد 30 ثانية.
- **الحافظة:** عند نسخ كلمة مرور يعلّمها التطبيق «حساسة» ويمسحها بعد 30 ثانية حيثما يسمح أندرويد. إذا أُغلق التطبيق قسراً خلال هذه الثواني فلن تُمسح.
- **كلمة مرور خاطئة:** 5 محاولات مجانية، ثم انتظار 30 ثانية يتضاعف حتى ساعة. لا تُحذف أي بيانات أبداً.
- **استيراد من الملاحظات:** من قائمة الخزنة ← «استيراد من الملاحظات»: ألصق نص ملاحظاتك، يقترح التطبيق عناصر (محلياً بلا إنترنت)، تراجعها ثم تحفظ ما تريد. **احذف الملاحظة الأصلية بنفسك بعد ذلك**.
- **النسخ الاحتياطي:** الخزنة تدخل مشفّرة في النسخة الاحتياطية وتُفتح على أي هاتف بكلمة المرور الرئيسية أو مفتاح الاسترداد.
- **⚠️ استخدم كلمات مرور تجريبية فقط** إلى أن تقرأ مراجعة الأمان (`docs/superpowers/specs/2026-10-23-phase-3-vault-security-review.md`) وتنفّذ فحوص الهاتف المذكورة فيها. نقل كلمات المرور الحقيقية قرارك أنت.
- **اختبارات الجهاز:** مفتاح البصمة في Keystore، وإبطاله عند إضافة بصمة، ومسح الحافظة في أندرويد 13 وما بعده، وتوقيت Argon2id على الهاتف: كلها لم تُجرَّب بعد على هاتف حقيقي (لا هاتف موصول أثناء البناء).

---

## المرحلة 4: المهام والتذكيرات

- **التحديث فوق المرحلة 3:** ثبّت الـ APK الجديد (الإصدار 1.3.0) فوق القديم؛ بياناتك تبقى. أنشئ نسخة احتياطية قبل التحديث. تُضاف جداول المهام فارغة تلقائياً.
- **المهام:** تبويب **المهام**: أضف مهمة بسرعة من الحقل العلوي، أو من زر «+» لنموذج كامل (الأولوية، مساحة العمل، الموعد والوقت، التذكير، التكرار، الوسوم، الخطوات). العروض: الوارد، اليوم، غداً، هذا الأسبوع، القادمة، المتأخرة، المكتملة، الكل، مع تصفية حسب مساحة العمل وترتيب حسب الموعد أو الأولوية. زر التقويم يعرض الشهر وعدد المهام في كل يوم.
- **التكرار:** عند إتمام مهمة متكررة تُنشأ المهمة التالية تلقائياً بموعد في المستقبل، وتُنسخ خطواتها مفتوحة.
- **التذكيرات:** منبهات أندرويد المحلية بدون أي خدمة من Google. عند أول تذكير يطلب التطبيق إذن الإشعارات. إذا لم يُسمح بالمنبهات الدقيقة فقد يتأخر التذكير بضع دقائق، وتظهر في شاشة المهام ملاحظة بزر لفتح إعداداتها. على الإشعار: **تمّت** و**تأجيل 10 دقائق** و**تأجيل ساعة**، ولمس الإشعار يفتح المهمة. يتكرر الإشعار كل ساعة حتى تنهي المهمة أو تؤجلها (حتى 72 مرة). **«ذكّرني غداً 9 صباحاً»** زر داخل شاشة المهمة. تُعاد جدولة التذكيرات بعد إعادة تشغيل الهاتف أو تغيير الوقت أو المنطقة الزمنية أو تحديث التطبيق.
- **المشاركة من واتساب وغيره:** شارك نصاً إلى «مدير حياتي» فيُفتح في مراجعة الالتقاط مقسّماً إلى مهام (سطر أو جملة لكل مهمة) تُبقي منها ما تريد. لا يُرسل شيء إلى الإنترنت في هذه الخطوة.
- **ملاحظات الاجتماعات:** من المهام ← أيقونة الاجتماعات: اكتب الملاحظة ثم «استخراج نقاط العمل» لتحويل ما تريد منها إلى مهام مرتبطة بالملاحظة.
- **أذونات جديدة:** الإشعارات، والمنبهات الدقيقة، وبدء التشغيل لإعادة جدولة التذكيرات.
- **اختبارات الجهاز:** المنبهات والإشعارات وأزرارها وإعادة الجدولة بعد التشغيل والمشاركة من تطبيقات أخرى لم تُجرَّب بعد على هاتف حقيقي (لا هاتف موصول أثناء البناء). جرّبها بمهمة تذكيرها بعد دقيقتين قبل أن تعتمد عليها.

---

---

# Install and build — My Life Manager

## Install on the phone

1. Copy `app-arm64-v8a-release.apk` to the phone (USB cable, or send it to yourself in a messenger). If the phone refuses it as "not compatible", it is an old 32-bit phone; use `app-armeabi-v7a-release.apk` instead.
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
flutter build apk --release --split-per-abi
```

Output: one APK per processor type in `build/app/outputs/flutter-apk/`. For the phone use `app-arm64-v8a-release.apk` (about 47 MB). Plain `flutter build apk --release` builds one APK for every type, about 150 MB.

Stick with `--split-per-abi`: Flutter adds 2000 to the arm64 APK's version code (2002 instead of 2), so Android refuses a later full APK as a downgrade.

If you built a debug APK first, the release build can fail with `package dev.flutter.plugins.integration_test does not exist`. A stale generated file causes it: run `flutter clean` (or delete `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`) and build again.

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

## Phase 2: AI and voice

- **Updating over Phase 1:** install the new APK over the old one. Your data stays because the signing key is the same; take a backup first anyway.
- **Groq key (optional):** create a free key on the Groq website and paste it in **Settings → AI**. It is stored only in the phone's secure storage, travels inside the encrypted backup, and is never logged.
- **Offline speech model:** download it from the same screen over Wi-Fi. `small` is about 465 MB and `base` about 141 MB. The file is verified after download and can be deleted at any time.
- **What is sent to Groq:** only your voice recording (when transcribing with Groq), and the text you said or typed with today's date and time and the names of your accounts, workspaces, categories and buckets. Never balances, past transactions, the PIN, backups or the vault. The app asks before the first send; if you decline, everything stays on the phone.
- **Turning online AI off:** in **Settings → AI** switch off "Use online AI". The on-phone parser and speech model keep working, and the "Finish with AI" buttons disappear.
- **Permissions:** internet, microphone and biometrics only.
- **On-device tests:** `whisper_device_test` and the rest of `integration_test` have not been run on a real phone yet. A phone was connected while Phase 2 was built, but the run installs a debug-signed build that would clash with an installed release app, so run them on a test phone.

## Phase 3: Vault

- **Updating over Phase 2:** install the new APK (version 1.2.0) over the old one; your data stays. Take a backup first. The database moves to schema 3 on its own and gains empty vault tables.
- **Setting up:** open the **Vault** tab and tap Start. Choose a **master password** (at least 10 characters; a long passphrase is better). It is separate from your PIN and cannot be recovered.
- **Recovery key:** shown once (8 groups of 4 characters). **Write it on paper and keep the paper somewhere safe, away from the phone**, then type it back to confirm. It is the only way in if you forget the master password, and unlocking with it makes you choose a new one. If you lose both, the vault stays locked for good: this phase has no erase and no recovery.
- **Fingerprint unlock (optional):** the last setup step, or **Vault settings**. It turns itself off when a fingerprint is added to the phone and after a backup is restored; unlock with the master password and turn it on again. The phone's PIN alone never opens the vault.
- **Locking:** after 2 minutes without a touch (choose 1, 2, 5 or 10), as soon as you leave the app, and whenever the app locks. Revealing or copying a password asks you to confirm again (fingerprint or master password) if the last confirmation is older than 30 seconds; a revealed value hides after 30 seconds.
- **Clipboard:** a copied password is marked sensitive and cleared after 30 seconds where Android allows it. If the app is killed during those seconds, it is not cleared.
- **Wrong password:** 5 free tries, then a 30-second wait that doubles up to an hour. Nothing is ever deleted.
- **Import from notes:** Vault menu → Import from notes. Paste your notes; the app proposes items (on the phone, no internet), you review them and save the ones you want. **Delete the original note yourself afterwards.**
- **Backups:** the vault travels encrypted inside the backup and opens on any phone with the master password or the recovery key.
- **⚠️ Use test passwords only** until you have read the security review (`docs/superpowers/specs/2026-10-23-phase-3-vault-security-review.md`) and run the on-phone checks it lists. Moving real passwords in is your decision.
- **On-device checks:** the Keystore fingerprint key, its invalidation on a new fingerprint, clipboard clearing on Android 13+ and Argon2id timing on the phone have not been run on a real phone yet (none was connected while Phase 3 was built).

## Phase 4: Tasks and reminders

- **Updating over Phase 3:** install the new APK (version 1.3.0) over the old one; your data stays. Take a backup first. The task tables are added empty.
- **Tasks:** the **Tasks** tab. Add one fast from the field at the top, or with "+" for the full form (priority, workspace, due date and time, reminder, repeat, tags, steps). Views: Inbox, Today, Tomorrow, This week, Upcoming, Overdue, Completed, All, with a workspace filter and a sort by due date or priority. The calendar button shows the month with the number of tasks on each day.
- **Repeating:** finishing a repeating task creates the next one, always dated in the future, with its steps copied as open.
- **Reminders:** local Android alarms, no Google service. The first reminder asks for the notification permission. If exact alarms are not allowed a reminder can be a few minutes late, and the Tasks screen shows a note with a button to those settings. The notification has **Done**, **Snooze 10 min** and **Snooze 1 h**; tapping it opens the task. It repeats every hour until you finish or snooze the task (up to 72 times). *Remind tomorrow 9:00* is a button inside the task. Reminders are rescheduled after a reboot, a time or time-zone change, and an app update.
- **Sharing from WhatsApp and others:** share text to My Life Manager and it opens in Capture Review split into tasks (one per line or sentence); keep, edit or drop each. Nothing is sent to the internet in this step.
- **Meeting notes:** Tasks → the meetings icon: write the note, then *Extract action points* to turn the ones you want into tasks linked to the note.
- **New permissions:** notifications, exact alarms, and run-at-boot (to reschedule reminders).
- **On-device checks:** alarms, notifications and their buttons, rescheduling after a reboot and sharing from other apps have not been run on a real phone yet (none was connected while Phase 4 was built). Try a task with a reminder two minutes away before relying on it.
