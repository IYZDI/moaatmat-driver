import '../models.dart';

/// عقد الوصول لبيانات المندوب — تنفيذان: تجريبي (وهمي) وSupabase حقيقي.
/// الشاشات تتعامل مع هذا العقد فقط، فيمكن التبديل بينهما دون تغيير الواجهة.
abstract class DriverRepository {
  /// تسجيل الدخول بإيميل/كلمة مرور (حساب الموظف في الداشبورد). يرمي عند الفشل.
  Future<void> signIn(String email, String password);
  Future<void> signOut();

  Future<List<Order>> myOrders();
  Future<DriverStats> todayStats();
  Future<List<HistoryItem>> history();
  Future<void> confirmPickup(String orderId);
  Future<void> confirmEnroute(String orderId);
  Future<void> confirmDelivered(String orderId, String photoUrl);
  Future<void> markFailed(String orderId, String reason);
  Future<List<ChatMessage>> messages(String orderId);
  Future<void> sendMessage(String orderId, String body);

  /// يرفع صورة التسليم ويعيد رابطها العلني/الموقّع. المسار: `orgId/orderId.jpg`
  Future<String> uploadProof(String orderId, List<int> bytes);
}
