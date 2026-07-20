/// إعدادات البيئة — تُمرَّر وقت البناء عبر --dart-define أو ملف dart-define.
/// مثال تشغيل محليًّا:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ... \
///               --dart-define=TENANT_HOST=`slug`.moaatmat.com
///
/// طالما SUPABASE_URL فارغ، يعمل التطبيق في «الوضع التجريبي» (بيانات وهمية)
/// تمامًا كما هو الآن — دون أي اتصال بالشبكة.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// مضيف المستأجر لعزل RLS متعدّد الشركات (ترويسة x-tenant-host).
  static const tenantHost = String.fromEnvironment('TENANT_HOST');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
