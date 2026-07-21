import '../models.dart';

/// هوية المندوب بعد الدخول.
class DriverIdentity {
  final String driverId;
  final String name;
  final String phone;
  final String orgName;
  const DriverIdentity({required this.driverId, required this.name, required this.phone, required this.orgName});
}

/// عقد الوصول لبيانات المندوب — نموذج الرمز (session_token). تنفيذان: تجريبي
/// (وهمي) وSupabase حقيقي. الشاشات تتعامل مع هذا العقد فقط.
abstract class DriverRepository {
  bool get isAuthed;
  String? get driverId;
  DriverIdentity? get identity;

  /// يتحقّق من رمز المؤسسة ويرسل OTP للجوال. يعيد اسم المؤسسة. يرمي عند الفشل.
  Future<String> sendOtp(String orgCode, String phone);

  /// يتحقّق من الرمز ويُصدر جلسة المندوب (يخزّن session_token). يعيد الهوية.
  Future<DriverIdentity> verifyOtp(String orgCode, String phone, String otp, String? name);

  /// يستعيد الجلسة المحفوظة إن وُجدت (عند بدء التطبيق).
  Future<bool> restoreSession();
  Future<void> signOut();

  /// يحدّث اسم المندوب في الداشبورد (يُستخدم عند أول دخول إن لم يكن له اسم).
  Future<void> updateName(String name);

  Future<List<Order>> myOrders();
  Future<DriverStats> todayStats();
  Future<List<HistoryItem>> history();

  Future<void> confirmPickup(String deliveryId);
  Future<void> confirmEnroute(String deliveryId);

  /// يرفع صورة التسليم عبر دالة الحافة الآمنة ويعلّم التوصيلة مُسلّمة.
  Future<void> confirmDelivered(String deliveryId, List<int> photoBytes);
  Future<void> markFailed(String deliveryId, String reason);

  Future<List<ChatMessage>> messages(String orderId);
  Future<void> sendMessage(String orderId, String body);

  /// يبثّ موقع المندوب الحيّ.
  Future<void> broadcastLocation(double lat, double lng);

  /// بثّ لحظي عند تغيّر أي من توصيلات هذا المندوب (Realtime).
  Stream<void> myOrdersChanges(String driverId);
}
