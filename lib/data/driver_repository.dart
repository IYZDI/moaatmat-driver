import '../models.dart';

/// نوعُ الخطأ يقرّر ما يُفعل به — لا نصُّه:
///   session   ⇒ الجلسةُ ماتت (خروجٌ من جهازٍ آخر أو تعطيلُ الحساب) ⇒ خروجٌ محلّيّ.
///   permanent ⇒ الخادمُ رفض بسببٍ يقوله للمندوب ⇒ يُعرض حرفيًّا ولا يُعاد.
///   transient ⇒ شبكةٌ أو خادمٌ متعثّر ⇒ يُعاد لاحقًا والفعلُ محفوظ.
enum DriverErrorKind { session, permanent, transient }

class DriverActionError implements Exception {
  const DriverActionError(this.kind, this.message);
  const DriverActionError.session([this.message = 'انتهت جلستك — سجّل الدخول من جديد'])
      : kind = DriverErrorKind.session;
  const DriverActionError.permanent(this.message) : kind = DriverErrorKind.permanent;
  const DriverActionError.transient([this.message = 'لا اتصال بالخادم — سيُعاد الإرسال تلقائيًّا'])
      : kind = DriverErrorKind.transient;

  final DriverErrorKind kind;

  /// نصٌّ عربيٌّ موجّهٌ للمندوب — يُعرض كما هو.
  final String message;

  bool get isSession => kind == DriverErrorKind.session;
  bool get isPermanent => kind == DriverErrorKind.permanent;
  bool get isTransient => kind == DriverErrorKind.transient;

  @override
  String toString() => message;
}

/// عقدُ الوصول لبيانات المندوب (نموذجُ رمز الجلسة). تنفيذان: Supabase الحقيقيّ،
/// وخادمٌ وهميٌّ في الذاكرة يطبّق القواعدَ نفسَها (للعرض والاختبار).
///
/// كلُّ ما بعد الدخول يرمي [DriverActionError] فقط — فالحالةُ تقرّر بالنوع.
abstract class DriverRepository {
  /// خادمٌ وهميّ؟ (شارةُ «تجريبي» ولا بثَّ موقعٍ حقيقيّ.)
  bool get isDemo;
  bool get isAuthed;
  String? get sessionToken;
  DriverIdentity? get identity;

  /// يستعيد الجلسةَ المحفوظة عند بدء التطبيق.
  Future<bool> restoreSession();

  /// يتحقّق من رمز المطعم ويرسل OTP. يُعيد اسمَ المطعم. يرمي `Exception(رسالة)`.
  Future<String> sendOtp(String orgCode, String phone);

  /// يُصدر الجلسة. يرمي `Exception(رسالة)`.
  Future<DriverIdentity> verifyOtp(String orgCode, String phone, String otp, {String? name});

  Future<void> setName(String name);
  Future<void> signOut();

  Future<DriverProfile> profile();
  Future<List<Stop>> route();
  Future<List<HistoryEntry>> history();

  /// `driver_set_status` — picked · enroute · defer · delivered · delivered_door · failed.
  Future<void> setStatus(String deliveryId, String action, {String? reason});

  /// يرفع صورةَ التسليم ويعلّم التسليمَ معًا (دالّةُ الحافة تنادي `driver_set_status`
  /// بنفسها — فلا يُنادى الاثنان للتوصيلة نفسها).
  Future<void> uploadProof(String deliveryId, List<int> jpeg, {bool door = false});

  Future<List<ChatMessage>> messages(String deliveryId);
  Future<void> sendMessage(String deliveryId, String body);
  Future<void> pingLocation(double lat, double lng);

  /// يزامن قنواتِ المحادثة اللحظيّة (`delivery-chat:<id>`) مع التوصيلات المفتوحة.
  void syncMessageChannels(Set<String> deliveryIds);
  Stream<IncomingMessage> get incomingMessages;

  void dispose();
}
