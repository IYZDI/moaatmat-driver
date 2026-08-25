/// إعدادات البيئة. المفتاح العلني (anon) آمن للتضمين في التطبيق كما في تطبيق
/// العميل. يمكن تجاوزه وقت البناء عبر --dart-define عند الحاجة.
///
/// نموذج المندوب الجديد: «رمز المؤسسة + الجوال + OTP» ورمز جلسة (session_token)
/// — لا يحتاج ترويسة x-tenant-host لأن رمز المؤسسة يحمل المؤسسة.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oikyrjfctznnjhimkagh.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pa3lyamZjdHpubmpoaW1rYWdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM5NTg1NzYsImV4cCI6MjA5OTUzNDU3Nn0.jURO-8QedMsZlRjskXJlYN43Z6XnRNBQb68BKStW8V4',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  // ---------- Firebase (الإشعارات الفورية) ----------
  // تُحقن وقت البناء عبر --dart-define من متغيّرات Codemagic.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId =
      String.fromEnvironment('FIREBASE_DRIVER_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');

// ---------- خرائط جوجل ----------
  // ⛔ **لا يُثبَّت المفتاح في الشيفرة.** كان مكتوبًا نصًّا في
  // `AndroidManifest.xml` و`AppDelegate.swift`، والمستودعُ منشور — فالمفتاحُ
  // منشورٌ معه، ويُحمَّل استهلاكُه على حسابٍ واحد لمن وجده.
  //
  // ⚠ وغيابُه على iOS **انهيارٌ لا خريطةٌ رماديّة**: `GMSMapView` بلا
  //   `provideAPIKey` تُسقط التطبيق بـGMSServicesException، وهو انهيارٌ
  //   أصليٌّ لا يمرّ بمعالجات Flutter. فالحارسُ في Dart (`hasMaps`) هو ما
  //   يمنع إنشاءها — لا فرعٌ في Swift.
  static const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  static bool get hasMaps => mapsApiKey.trim().isNotEmpty;

  static bool get hasFirebase =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;
}
