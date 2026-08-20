import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // ⚠ لا `com.google.gms.google-services` هنا — تركُه قرارٌ لا نسيان.
    // التطبيق يُهيّئ Firebase برمجيًّا بـ`Firebase.initializeApp(options:)` من
    // قيم --dart-define (lib/data/push_service.dart)، ولا يقرأ
    // google-services.json إطلاقًا. والملحقُ يشترط وجودَ ذلك الملفّ فيُسقط
    // البناءَ بدونه، ويشترط التزامَه في المستودع فيربط الحزمةَ بمشروع Firebase
    // واحد. والاستعمالُ الوحيدُ الذي كان يُلزمنا به — مُعالجُ رسائلَ في الخلفيّة
    // يستدعي `Firebase.initializeApp()` بلا خيارات — غيرُ موجود هنا:
    // لا onBackgroundMessage ولا نقطةَ دخولٍ ثانية في lib/ (فُحصت).
}

// ============================================================================
// توقيع الإصدار — مفتاحٌ حقيقيّ أو سقوط. ولا رجوعَ صامتًا إلى مفتاح التصحيح.
// ----------------------------------------------------------------------------
// المصدران بالترتيب:
//   ① android/key.properties — يكتبه scripts/gen_android_signing.sh وقت البناء
//      من ANDROID_KEYSTORE_B64، وهو مُتجاهَلٌ في .gitignore فلا يدخل المستودع.
//   ② متغيّرات البيئة مباشرةً: ANDROID_KEYSTORE_PATH · ANDROID_KEYSTORE_PASSWORD
//      · ANDROID_KEY_ALIAS · ANDROID_KEY_PASSWORD — لمن يوقّع بمخزنٍ على الآلة.
//
// وكان السطرُ هنا `signingConfigs.getByName("debug")` من قالب Flutter. حزمةٌ
// موقّعةٌ بمفتاح التصحيح تُثبَّت وتعمل فلا شيء يُنبّه؛ ثمّ إنّ آلة البناء تولّد
// مفتاحَ تصحيحٍ جديدًا في كلّ بناء، فلا تُثبَّت حزمةٌ فوق سابقتها ولا يقبلها
// Google Play. عطلٌ لا يظهر في البناء بل بعده — كالذي سبقه في مفاتيح Firebase.
//
// ولبناءٍ محلّيٍّ بمفتاح التصحيح عمدًا: ALLOW_DEBUG_SIGNING=1
// ============================================================================
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) FileInputStream(keyPropertiesFile).use { load(it) }
}

// الملفّ أوّلًا ثمّ البيئة. والفراغُ كالغياب: متغيّرُ Codemagic غيرُ المضبوط يصل
// سلسلةً خاوية لا null، ولولا هذا لعُدّ «موجودًا» ثمّ سقط داخل Gradle برسالةٍ
// عن مخزنٍ اسمُه فراغ.
fun signingValue(fileKey: String, envKey: String): String? =
    (keyProperties.getProperty(fileKey) ?: System.getenv(envKey))?.takeIf { it.isNotBlank() }

val storePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val storePass = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPass = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")

val missingSigning = listOf(
    "storeFile / ANDROID_KEYSTORE_PATH" to storePath,
    "storePassword / ANDROID_KEYSTORE_PASSWORD" to storePass,
    "keyAlias / ANDROID_KEY_ALIAS" to releaseKeyAlias,
    "keyPassword / ANDROID_KEY_PASSWORD" to releaseKeyPass,
).filter { it.second == null }.map { it.first }

val hasReleaseKey = missingSigning.isEmpty()

android {
    namespace = "com.moaatmat.moaatmat_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // يشترطها flutter_local_notifications 18: تستعمل java.time على أندرويد
        // القديم. وبدونها يسقط البناءُ في dex بـ"desugaring is not enabled" —
        // لا في الشفرة، فيُقرأ كأنّ العطل في مكانٍ آخر.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.moaatmat.moaatmat_driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // يُنشأ عند اكتمال المفاتيح وحدَه؛ وناقصًا لا يُنشأ أصلًا فيسقط الحارسُ
        // أدناه بدل أن يُنشأ إعدادُ توقيعٍ نصفَ ممتلئ يفشل داخل apksigner.
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(storePath!!)
                storePassword = storePass
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

// الحارس: لا يُرمى وقتَ التهيئة كي لا ينكسر بناءُ التصحيح ولا `flutter run`،
// بل حين يدخل هدفُ إصدارٍ فعليٌّ خطّةَ التنفيذ — وذلك قبل تشغيل أيّ مهمّة، فلا
// يُنتج البناءُ حزمةً ثمّ يعتذر عنها.
//
// وهو يسقط ولو نُزعت خطوةُ gen_android_signing.sh من codemagic.yaml: الفحصُ في
// آخر نقطةٍ تعرف بماذا ستُوقَّع الحزمةُ فعلًا، لا في الخطوة التي تُحضّر المفتاح.
//
// وتُكتب `Action` كائنًا صريحًا لا دالّةً مجهولة: لـ`whenReady` حِملان، فتذهب
// الدالّةُ المجهولة إلى حِمل `Closure` القديم (أو إلى صيغة المستقبِل) وتسقط
// الترجمةُ بـ«Unresolved reference 'allTasks'» — وهو ما وقع فعلًا مرّتين قبل
// هذه الصيغة.
gradle.taskGraph.whenReady(object : Action<TaskExecutionGraph> {
    override fun execute(graph: TaskExecutionGraph) {
        val releaseTask = graph.allTasks.map { task -> task.path }.firstOrNull { path ->
            Regex("^:app:(assemble|bundle|package)[A-Za-z]*Release$").matches(path)
        }
        if (releaseTask == null || hasReleaseKey) return
        if (System.getenv("ALLOW_DEBUG_SIGNING") == "1") {
            println("⚠️  $releaseTask يُوقَّع بمفتاح التصحيح بطلبٍ صريح (ALLOW_DEBUG_SIGNING=1)")
            println("    تُثبَّت وتُجرَّب، ولا يقبلها Google Play، ولا تُثبَّت فوق حزمةٍ من بناءٍ آخر.")
            return
        }
        throw GradleException(
            "ينقص إعدادُ توقيع الإصدار: " + missingSigning.joinToString("، ") + "\n" +
                "  المصدر: android/key.properties — يكتبه scripts/gen_android_signing.sh\n" +
                "  من ANDROID_KEYSTORE_B64 في مجموعة Codemagic «platform_shared».\n" +
                "  أو مباشرةً: ANDROID_KEYSTORE_PATH · ANDROID_KEYSTORE_PASSWORD ·\n" +
                "  ANDROID_KEY_ALIAS · ANDROID_KEY_PASSWORD.\n" +
                "  ولبناءٍ محلّيٍّ بمفتاح التصحيح عمدًا: ALLOW_DEBUG_SIGNING=1"
        )
    }
})

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
