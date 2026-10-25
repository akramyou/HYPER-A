# إصلاح إعداد Gradle

عالج هذا التعديل خطأ إعداد Android الذي ظهر في GitHub Actions:
`No signature of method: org.gradle.initialization.DefaultProjectDescriptor.file()`.

السبب كان استدعاء `rootProject.file('local.properties')` داخل `android/settings.gradle`، حيث إن `rootProject` هناك هو ProjectDescriptor لا يوفّر الدالة `file()`. تم استبداله باستخدام `new File(settingsDir, 'local.properties')`.

بعد رفع الملفات إلى GitHub، شغّل GitHub Actions مجددًا. هذا الإصلاح يعالج الخطأ الظاهر فقط؛ ولا يؤكد نجاح بقية مراحل البناء دون تنفيذها فعليًا.
