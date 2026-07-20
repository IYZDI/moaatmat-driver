import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'driver_repository.dart';

/// تنفيذ Supabase — ينادي دوال RPC المعرّفة في هجرة 0124_driver_app.sql.
/// كل الدوال محميّة على الخادم (SECURITY DEFINER) ومحصورة على طلبات هذا المندوب.
class SupabaseDriverRepository implements DriverRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String _initial(String name) => name.trim().isEmpty ? '؟' : name.trim()[0];

  @override
  Future<void> signIn(String email, String password) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<List<HistoryItem>> history() async {
    final rows = await _db.rpc('driver_history') as List<dynamic>;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final ok = (m['status'] ?? '') == 'delivered';
      final at = DateTime.tryParse((m['delivered_at'] ?? '') as String? ?? '')?.toLocal();
      final sub = ok
          ? 'سُلّم ${at != null ? _fmt(at) : ''}'
          : ((m['failure_reason'] ?? 'تعذّر التسليم') as String);
      return HistoryItem(
        id: m['order_id'].toString(),
        name: (m['name'] ?? '') as String,
        sub: sub,
        ok: ok,
      );
    }).toList();
  }

  @override
  Future<List<Order>> myOrders() async {
    final rows = await _db.rpc('driver_my_orders') as List<dynamic>;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final name = (m['customer_name'] ?? '') as String;
      return Order(
        id: m['order_id'].toString(),
        name: name,
        initial: _initial(name),
        items: (m['items'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        prefTime: (m['pref_eta'] ?? '') as String,
        status: orderStatusFromDb((m['status'] ?? 'preparing') as String),
        eta: (m['pref_eta'] ?? '') as String,
      );
    }).toList();
  }

  @override
  Future<DriverStats> todayStats() async {
    final rows = await _db.rpc('driver_today_stats') as List<dynamic>;
    if (rows.isEmpty) return const DriverStats(total: 0, delivered: 0, remaining: 0);
    final m = rows.first as Map<String, dynamic>;
    return DriverStats(
      total: (m['total'] ?? 0) as int,
      delivered: (m['delivered'] ?? 0) as int,
      remaining: (m['remaining'] ?? 0) as int,
    );
  }

  @override
  Future<void> confirmPickup(String orderId) =>
      _db.rpc('driver_confirm_pickup', params: {'p_order_id': orderId});

  @override
  Future<void> confirmEnroute(String orderId) =>
      _db.rpc('driver_confirm_enroute', params: {'p_order_id': orderId});

  @override
  Future<void> confirmDelivered(String orderId, String photoUrl) =>
      _db.rpc('driver_confirm_delivered', params: {'p_order_id': orderId, 'p_photo_url': photoUrl});

  @override
  Future<void> markFailed(String orderId, String reason) =>
      _db.rpc('driver_mark_failed', params: {'p_order_id': orderId, 'p_reason': reason});

  @override
  Future<List<ChatMessage>> messages(String orderId) async {
    final rows = await _db.rpc('driver_order_messages', params: {'p_order_id': orderId}) as List<dynamic>;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final created = DateTime.tryParse((m['created_at'] ?? '') as String)?.toLocal();
      return ChatMessage(
        outgoing: (m['sender'] ?? 'driver') == 'driver',
        text: (m['body'] ?? '') as String,
        time: created != null ? _fmt(created) : '',
      );
    }).toList();
  }

  @override
  Future<void> sendMessage(String orderId, String body) =>
      _db.rpc('driver_send_message', params: {'p_order_id': orderId, 'p_body': body});

  @override
  Future<String> uploadProof(String orderId, List<int> bytes) async {
    // organization_id يُستنتج من المستخدم الحالي في الخادم؛ هنا نستخدم auth uid
    // كمجلد مؤقت لو لم تتوفّر المؤسسة (سياسة التخزين تتحقّق من العضوية).
    final uid = _db.auth.currentUser?.id ?? 'unknown';
    final path = '$uid/$orderId.jpg';
    await _db.storage.from('delivery-proofs').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    return _db.storage.from('delivery-proofs').getPublicUrl(path);
  }

  static String _fmt(DateTime d) {
    var h = d.hour;
    final min = d.minute.toString().padLeft(2, '0');
    final mer = h >= 12 ? 'م' : 'ص';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$min $mer';
  }
}
