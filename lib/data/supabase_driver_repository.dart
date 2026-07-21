import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'driver_repository.dart';

/// تنفيذ Supabase بنموذج الرمز (ترحيلات 0125–0134). الدخول عبر OTP (Authentica)
/// ثم رمز جلسة (session_token) يُمرَّر لكل دالة RPC. لا مصادقة Supabase للمندوب.
class SupabaseDriverRepository implements DriverRepository {
  SupabaseClient get _db => Supabase.instance.client;

  static const _kToken = 'drv_token';
  static const _kId = 'drv_id';
  static const _kName = 'drv_name';
  static const _kPhone = 'drv_phone';
  static const _kOrg = 'drv_org';

  String? _token;
  DriverIdentity? _identity;

  @override
  bool get isAuthed => _token != null;
  @override
  String? get driverId => _identity?.driverId;
  @override
  DriverIdentity? get identity => _identity;

  String _initial(String name) => name.trim().isEmpty ? '؟' : name.trim()[0];

  /// يحوّل الجوال إلى E.164 السعودية (+9665XXXXXXXX).
  String _e164(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('966')) return '+$d';
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 9 && d.startsWith('5')) return '+966$d';
    return '+$d';
  }

  String _fnError(Object e, String fallback) {
    if (e is FunctionException) {
      final d = e.details;
      if (d is Map) {
        if (d['reason'] == 'invalid_otp') return 'رمز التحقّق غير صحيح';
        return (d['message'] ?? d['error'] ?? fallback).toString();
      }
    }
    return fallback;
  }

  @override
  Future<String> sendOtp(String orgCode, String phone) async {
    try {
      final res = await _db.functions.invoke('driver-otp-send',
          body: {'org_code': orgCode.trim(), 'phone': _e164(phone)});
      final data = (res.data as Map?) ?? const {};
      return (data['org_name'] ?? '') as String? ?? '';
    } catch (e) {
      throw Exception(_fnError(e, 'تعذّر إرسال الرمز — تحقّق من البيانات'));
    }
  }

  @override
  Future<DriverIdentity> verifyOtp(String orgCode, String phone, String otp, String? name) async {
    try {
      final res = await _db.functions.invoke('driver-otp-verify', body: {
        'org_code': orgCode.trim(),
        'phone': _e164(phone),
        'otp': otp.trim(),
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      });
      final data = (res.data as Map?) ?? const {};
      if (data['verified'] != true || data['token'] == null) {
        throw Exception(data['reason'] == 'invalid_otp' ? 'رمز التحقّق غير صحيح' : (data['error'] ?? 'تعذّر الدخول'));
      }
      _token = data['token'] as String;
      // الجوال الحقيقي: نفضّل ما يعيده الخادم (driver_phone)، وإلا الجوال المُدخَل
      // مُطبَّعًا إلى صيغة E.164.
      final serverPhone = (data['driver_phone'] ?? '') as String? ?? '';
      final phoneVal = serverPhone.trim().isNotEmpty ? serverPhone.trim() : _e164(phone);
      _identity = DriverIdentity(
        driverId: (data['driver_id'] ?? '').toString(),
        name: (data['driver_name'] ?? '') as String? ?? '',
        phone: phoneVal,
        orgName: (data['org_name'] ?? '') as String? ?? '',
      );
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kToken, _token!);
      await sp.setString(_kId, _identity!.driverId);
      await sp.setString(_kName, _identity!.name);
      await sp.setString(_kPhone, _identity!.phone);
      await sp.setString(_kOrg, _identity!.orgName);
      return _identity!;
    } catch (e) {
      if (e is Exception && e is! FunctionException) rethrow;
      throw Exception(_fnError(e, 'تعذّر الدخول'));
    }
  }

  @override
  Future<bool> restoreSession() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kToken);
    if (t == null) return false;
    _token = t;
    _identity = DriverIdentity(
      driverId: sp.getString(_kId) ?? '',
      name: sp.getString(_kName) ?? '',
      phone: sp.getString(_kPhone) ?? '',
      orgName: sp.getString(_kOrg) ?? '',
    );
    return true;
  }

  @override
  Future<void> updateName(String name) async {
    final n = name.trim();
    if (n.isEmpty || _identity == null) return;
    // يتبع اصطلاح دوال RPC للمندوب (مثل driver_set_status).
    await _db.rpc('driver_set_name', params: {'p_token': _token, 'p_name': n});
    _identity = DriverIdentity(
      driverId: _identity!.driverId,
      name: n,
      phone: _identity!.phone,
      orgName: _identity!.orgName,
    );
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, n);
  }

  @override
  Future<void> signOut() async {
    _token = null;
    _identity = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kId);
    await sp.remove(_kName);
    await sp.remove(_kPhone);
    await sp.remove(_kOrg);
  }

  @override
  Future<List<Order>> myOrders() async {
    final rows = await _db.rpc('driver_orders', params: {'p_token': _token}) as List<dynamic>;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final name = (m['customer_name'] ?? '') as String? ?? '';
      final eta = (m['eta'] ?? '') as String? ?? '';
      return Order(
        id: (m['delivery_id'] ?? '').toString(),
        orderId: m['order_id']?.toString(),
        name: name,
        initial: _initial(name),
        items: (m['items'] ?? '') as String? ?? '',
        address: (m['address'] ?? '') as String? ?? '',
        prefTime: eta,
        eta: eta,
        status: orderStatusFromDb((m['status'] ?? 'preparing') as String),
      );
    }).toList();
  }

  @override
  Future<DriverStats> todayStats() async {
    final rows = await _db.rpc('driver_stats', params: {'p_token': _token}) as List<dynamic>;
    if (rows.isEmpty) return const DriverStats(total: 0, delivered: 0, remaining: 0);
    final m = rows.first as Map<String, dynamic>;
    return DriverStats(
      total: (m['total'] ?? 0) as int,
      delivered: (m['delivered'] ?? 0) as int,
      remaining: (m['remaining'] ?? 0) as int,
    );
  }

  @override
  Future<List<HistoryItem>> history() async {
    final rows = await _db.rpc('driver_history', params: {'p_token': _token}) as List<dynamic>;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final ok = (m['status'] ?? '') == 'delivered';
      final at = DateTime.tryParse((m['delivered_at'] ?? '') as String? ?? '')?.toLocal();
      final sub = ok
          ? 'سُلّم ${at != null ? _fmt(at) : ''}'
          : ((m['failure_reason'] ?? 'تعذّر التسليم') as String? ?? 'تعذّر التسليم');
      return HistoryItem(
        id: (m['order_id'] ?? m['delivery_id'] ?? '').toString(),
        name: (m['customer_name'] ?? '') as String? ?? '',
        sub: sub,
        ok: ok,
      );
    }).toList();
  }

  Future<void> _setStatus(String deliveryId, String action, {String? photo, String? reason}) =>
      _db.rpc('driver_set_status', params: {
        'p_token': _token,
        'p_delivery_id': deliveryId,
        'p_action': action,
        'p_photo_url': photo,
        'p_reason': reason,
      });

  @override
  Future<void> confirmPickup(String deliveryId) => _setStatus(deliveryId, 'picked');
  @override
  Future<void> confirmEnroute(String deliveryId) => _setStatus(deliveryId, 'enroute');
  @override
  Future<void> markFailed(String deliveryId, String reason) => _setStatus(deliveryId, 'failed', reason: reason);

  @override
  Future<void> confirmDelivered(String deliveryId, List<int> photoBytes) async {
    // المندوب مجهول ولا يكتب في السلّة الخاصّة — نرفع عبر دالة الحافة الآمنة.
    try {
      final res = await _db.functions.invoke('driver-upload-proof', body: {
        'token': _token,
        'delivery_id': deliveryId,
        'content_type': 'image/jpeg',
        'data_base64': base64Encode(photoBytes),
      });
      final data = (res.data as Map?) ?? const {};
      if (data['ok'] != true) throw Exception('تعذّر رفع صورة التسليم');
    } catch (e) {
      throw Exception(_fnError(e, 'تعذّر تأكيد التسليم'));
    }
  }

  @override
  Future<List<ChatMessage>> messages(String orderId) async {
    final rows = await _db.rpc('driver_messages', params: {'p_token': _token, 'p_order_id': orderId}) as List<dynamic>;
    return rows.map((r) {
      final m = r as Map<String, dynamic>;
      final c = DateTime.tryParse((m['created_at'] ?? '') as String? ?? '')?.toLocal();
      return ChatMessage(
        outgoing: (m['sender'] ?? 'driver') == 'driver',
        text: (m['body'] ?? '') as String? ?? '',
        time: c != null ? _fmt(c) : '',
      );
    }).toList();
  }

  @override
  Future<void> sendMessage(String orderId, String body) =>
      _db.rpc('driver_send_message', params: {'p_token': _token, 'p_order_id': orderId, 'p_body': body});

  @override
  Future<void> broadcastLocation(double lat, double lng) async {
    await _db.rpc('driver_ping_location', params: {'p_token': _token, 'p_lat': lat, 'p_lng': lng});
  }

  @override
  Stream<void> myOrdersChanges(String driverId) {
    // المندوب مجهول (بلا صلاحية RLS للاستماع اللحظي) → استطلاع دوري كل 20 ثانية.
    late final StreamController<void> ctrl;
    Timer? timer;
    ctrl = StreamController<void>(
      onListen: () { timer = Timer.periodic(const Duration(seconds: 20), (_) => ctrl.add(null)); },
      onCancel: () { timer?.cancel(); },
    );
    return ctrl.stream;
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
