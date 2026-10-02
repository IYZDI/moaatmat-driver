import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../route_logic.dart' show hasXY;
import 'crash_reporter.dart';
import 'driver_repository.dart';

/// تنفيذُ Supabase بنموذج الرمز: الدخولُ عبر OTP (Authentica) ثمّ رمزُ جلسةٍ
/// يُمرَّر لكلّ دالّة RPC — لا مصادقةَ Supabase للمندوب.
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
  bool get isDemo => false;
  @override
  bool get isAuthed => _token != null;
  @override
  String? get sessionToken => _token;
  @override
  DriverIdentity? get identity => _identity;

  // ---------- تصنيف الأخطاء ----------

  /// أصنافُ SQLSTATE التي لا تُصلحها الإعادة: 42 (صياغة/صلاحيّة/غيرُ موجود)
  /// و22 (بياناتٌ مرفوضة).
  static final _permanentSqlState = RegExp(r'^(42|22)[0-9A-Z]{3}$');

  /// كلُّ خطأٍ ⇒ نوعٌ ورسالة. ‎P0001‎ رسالةٌ كتبها الخادمُ للمندوب فتُعرض حرفيًّا،
  /// و«جلسة غير صالحة» (0472 وحّدت نصَّها في كلّ الدوال) ⇒ خروج.
  static DriverActionError classify(Object e) {
    if (e is DriverActionError) return e;
    final text = e.toString();
    if (text.contains('جلسة غير صالحة')) return const DriverActionError.session();
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code == 'P0001') return DriverActionError.permanent(e.message);
      // دالّةٌ غيرُ موجودة (هجرةٌ لم تُطبَّق) أو معاملٌ خاطئ: الإعادةُ لا تُصلحها.
      // ⚠ SQLSTATE من خمسة محارف فقط: postgrest يضع رمزَ HTTP في `code` حين لا
      //   يفهم جسمَ الردّ (صفحةُ HTML من البوّابة)، و«429» يبدأ بـ«42» — فكان
      //   تقييدُ المعدّل يُسقط تسليمًا محفوظًا نهائيًّا بدل إعادته بعد ثوانٍ.
      if (code.startsWith('PGRST2') || _permanentSqlState.hasMatch(code)) {
        return DriverActionError.permanent('الخادم لم يقبل الطلب (${e.code}) — حدّث التطبيق أو تواصل مع المطعم');
      }
      return const DriverActionError.transient();
    }
    if (e is FunctionException) {
      final d = e.details;
      final err = d is Map ? (d['error'] ?? '').toString() : '';
      final msg = d is Map ? (d['message'] ?? '').toString().trim() : '';
      if (e.status == 401 || err == 'invalid_session') return const DriverActionError.session();
      switch (err) {
        case 'not_assigned':
          return DriverActionError.permanent(msg.isNotEmpty ? msg : 'هذه التوصيلةُ ليست لك');
        case 'door_not_allowed':
          return DriverActionError.permanent(msg.isNotEmpty ? msg : 'الترك عند الباب غير مسموح في هذا المطعم');
        case 'cancelled':
          return DriverActionError.permanent(msg.isNotEmpty ? msg : 'أُلغيت هذه التوصيلة');
        case 'image_too_large':
          return const DriverActionError.permanent('الصورة كبيرة جدًّا — التقطها من جديد');
        case 'bad_image':
        case 'bad_input':
          return const DriverActionError.permanent('تعذّرت قراءة الصورة — التقطها من جديد');
      }
      // 409/403/400 بلا رمزٍ نعرفه: رفضٌ لا تُصلحه الإعادة.
      if (e.status == 400 || e.status == 403 || e.status == 409 || e.status == 413) {
        return DriverActionError.permanent(msg.isNotEmpty ? msg : 'تعذّر تأكيد التسليم');
      }
      return const DriverActionError.transient();
    }
    // انقطاعُ شبكة (SocketException · ClientException · TimeoutException …).
    return const DriverActionError.transient();
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw classify(e);
    }
  }

  // ---------- الدخول ----------

  /// يحوّل الجوال إلى E.164 السعودية (+9665XXXXXXXX).
  static String e164(String raw) {
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
      final res = await _db.functions
          .invoke('driver-otp-send', body: {'org_code': orgCode.trim(), 'phone': e164(phone)});
      final data = (res.data as Map?) ?? const {};
      return (data['org_name'] ?? '').toString();
    } catch (e) {
      throw Exception(_fnError(e, 'تعذّر إرسال الرمز — تحقّق من البيانات'));
    }
  }

  @override
  Future<DriverIdentity> verifyOtp(String orgCode, String phone, String otp, {String? name}) async {
    Map data;
    try {
      final res = await _db.functions.invoke('driver-otp-verify', body: {
        'org_code': orgCode.trim(),
        'phone': e164(phone),
        'otp': otp.trim(),
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : null,
      });
      data = (res.data as Map?) ?? const {};
    } catch (e) {
      throw Exception(_fnError(e, 'تعذّر الدخول'));
    }
    if (data['verified'] != true || data['token'] == null) {
      throw Exception(data['reason'] == 'invalid_otp' ? 'رمز التحقّق غير صحيح' : (data['error'] ?? 'تعذّر الدخول'));
    }
    _token = data['token'].toString();
    CrashReporter.driverToken = _token; // ليُعرف صاحبُ التقرير (0296)
    // الجوالُ كما يعرفه الخادم أولى من المُدخَل.
    final serverPhone = (data['driver_phone'] ?? '').toString().trim();
    _identity = DriverIdentity(
      driverId: (data['driver_id'] ?? '').toString(),
      name: (data['driver_name'] ?? '').toString(),
      phone: serverPhone.isNotEmpty ? serverPhone : e164(phone),
      orgName: (data['org_name'] ?? '').toString(),
    );
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, _token!);
    await sp.setString(_kId, _identity!.driverId);
    await sp.setString(_kName, _identity!.name);
    await sp.setString(_kPhone, _identity!.phone);
    await sp.setString(_kOrg, _identity!.orgName);
    return _identity!;
  }

  @override
  Future<bool> restoreSession() async {
    final sp = await SharedPreferences.getInstance();
    final t = sp.getString(_kToken);
    if (t == null) return false;
    _token = t;
    CrashReporter.driverToken = _token;
    _identity = DriverIdentity(
      driverId: sp.getString(_kId) ?? '',
      name: sp.getString(_kName) ?? '',
      phone: sp.getString(_kPhone) ?? '',
      orgName: sp.getString(_kOrg) ?? '',
    );
    return true;
  }

  @override
  Future<void> setName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await _guard(() => _db.rpc('driver_set_name', params: {'p_token': _token, 'p_name': n}));
    final id = _identity;
    if (id != null) {
      _identity = DriverIdentity(driverId: id.driverId, name: n, phone: id.phone, orgName: id.orgName);
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kName, n);
  }

  @override
  Future<void> signOut() async {
    // يُبطَل الرمزُ على الخادم أوّلًا: مسحُ التخزين وحده يترك الرمزَ صالحًا لمن
    // التقطه. وفشلُ النداء لا يمنع الخروجَ المحلّيّ.
    final t = _token;
    if (t != null) {
      try {
        await _db.rpc('driver_logout', params: {'p_token': t});
      } catch (_) {/* الخروجُ المحلّيّ يمضي */}
    }
    _token = null;
    _identity = null;
    CrashReporter.driverToken = null;
    syncMessageChannels(const {});
    final sp = await SharedPreferences.getInstance();
    for (final k in [_kToken, _kId, _kName, _kPhone, _kOrg]) {
      await sp.remove(k);
    }
  }

  // ---------- القراءة ----------

  static String? _s(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  static DateTime? _ts(dynamic v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  /// تاريخٌ بلا وقت (`date` في Postgres) — يُقرأ يومًا محلّيًّا لا لحظةً بتوقيت UTC.
  static DateTime? _date(dynamic v) {
    final t = _s(v);
    if (t == null) return null;
    final p = t.split('-');
    if (p.length < 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2].substring(0, 2));
    return (y == null || m == null || d == null) ? null : DateTime(y, m, d);
  }

  static LatLon? _pos(dynamic lat, dynamic lng) {
    final a = (lat as num?)?.toDouble(), b = (lng as num?)?.toDouble();
    if (a == null || b == null) return null;
    final p = LatLon(a, b);
    return hasXY(p) ? p : null;
  }

  static Stop stopFromRow(Map<String, dynamic> m) => Stop(
        id: m['delivery_id'].toString(),
        orderId: _s(m['order_id']),
        subscriptionDayId: _s(m['subscription_day_id'])?.toLowerCase(),
        isSubscription: (m['kind'] ?? 'subscription') == 'subscription',
        status: stopStatusFromDb(m['status'] as String?),
        pickedAt: _ts(m['picked_at']),
        enrouteAt: _ts(m['enroute_at']),
        deliveredAt: _ts(m['delivered_at']),
        handoff: _s(m['handoff']),
        failureReason: _s(m['failure_reason']),
        customerName: _s(m['customer_name']) ?? '',
        phone: _s(m['customer_phone']),
        address: _s(m['address']),
        notes: _s(m['address_notes']),
        pos: _pos(m['lat'], m['lng']),
        bagNo: (m['bag_no'] as num?)?.toInt(),
        orderNo: (m['order_no'] as num?)?.toInt(),
        slotLabel: _s(m['slot_label']),
        slotSort: (m['slot_sort'] as num?)?.toInt(),
        slotStart: _s(m['slot_start']),
        slotEnd: _s(m['slot_end']),
        mealsCount: (m['meals_count'] as num?)?.toInt() ?? 0,
        items: _s(m['items']),
        branchId: _s(m['branch_id']),
        branchName: _s(m['branch_name']),
        branchPos: _pos(m['branch_lat'], m['branch_lng']),
        routeDate: _date(m['route_date']),
      );

  @override
  Future<List<Stop>> route() => _guard(() async {
        final rows = await _db.rpc('driver_route', params: {'p_token': _token}) as List<dynamic>;
        return [for (final r in rows) stopFromRow(Map<String, dynamic>.from(r as Map))];
      });

  @override
  Future<DriverProfile> profile() => _guard(() async {
        final rows = await _db.rpc('driver_profile', params: {'p_token': _token}) as List<dynamic>;
        if (rows.isEmpty) throw const DriverActionError.session();
        final m = Map<String, dynamic>.from(rows.first as Map);
        return DriverProfile(
          name: _s(m['driver_name']) ?? '',
          phone: _s(m['driver_phone']) ?? (_identity?.phone ?? ''),
          orgName: _s(m['org_name']) ?? (_identity?.orgName ?? ''),
          logoUrl: _s(m['org_logo_url']),
          color: _s(m['org_color']),
          supportPhone: _s(m['support_phone']),
          photoRequired: m['photo_required'] != false,
          doorAllowed: m['door_allowed'] != false,
          orgToday: _date(m['org_today']),
        );
      });

  @override
  Future<List<HistoryEntry>> history() => _guard(() async {
        final rows = await _db.rpc('driver_history_v2', params: {'p_token': _token}) as List<dynamic>;
        return [
          for (final r in rows)
            () {
              final m = Map<String, dynamic>.from(r as Map);
              return HistoryEntry(
                id: m['delivery_id'].toString(),
                customerName: _s(m['customer_name']) ?? '',
                bagNo: (m['bag_no'] as num?)?.toInt(),
                delivered: m['status'] == 'delivered',
                atDoor: m['handoff'] == 'door',
                deliveredAt: _ts(m['delivered_at']),
                failureReason: _s(m['failure_reason']),
                routeDate: _date(m['route_date']),
                slotLabel: _s(m['slot_label']),
              );
            }(),
        ];
      });

  // ---------- الأفعال ----------

  @override
  Future<void> setStatus(String deliveryId, String action, {String? reason}) =>
      _guard(() => _db.rpc('driver_set_status', params: {
            'p_token': _token,
            'p_delivery_id': deliveryId,
            'p_action': action,
            'p_photo_url': null,
            'p_reason': reason,
          }));

  @override
  Future<void> uploadProof(String deliveryId, List<int> jpeg, {bool door = false}) => _guard(() async {
        // المندوبُ مجهولٌ لا يكتب في السلّة الخاصّة — دالّةُ الحافة ترفع ثمّ تنادي
        // `driver_set_status` بالحارس نفسه (صورةٌ إلزاميّة؟ الباب مسموح؟).
        final res = await _db.functions.invoke('driver-upload-proof', body: {
          'token': _token,
          'delivery_id': deliveryId,
          'content_type': 'image/jpeg',
          'data_base64': base64Encode(jpeg),
          'handoff': door ? 'door' : 'hand',
        });
        final data = (res.data as Map?) ?? const {};
        if (data['ok'] != true) throw const DriverActionError.transient('تعذّر رفع صورة التسليم — سيُعاد');
      });

  @override
  Future<List<ChatMessage>> messages(String deliveryId) => _guard(() async {
        // 0291 — المحادثةُ بالتوصيلة لا بالطلب، فلتوصيلة الاشتراك محادثةٌ أيضًا.
        final rows = await _db.rpc('driver_delivery_messages',
            params: {'p_token': _token, 'p_delivery_id': deliveryId}) as List<dynamic>;
        return [
          for (final r in rows)
            ChatMessage(
              outgoing: ((r as Map)['sender'] ?? 'driver') == 'driver',
              text: (r['body'] ?? '').toString(),
              at: _ts(r['created_at']),
            ),
        ];
      });

  @override
  Future<void> sendMessage(String deliveryId, String body) => _guard(() => _db.rpc(
      'driver_send_delivery_message',
      params: {'p_token': _token, 'p_delivery_id': deliveryId, 'p_body': body}));

  @override
  Future<void> pingLocation(double lat, double lng) =>
      _guard(() => _db.rpc('driver_ping_location', params: {'p_token': _token, 'p_lat': lat, 'p_lng': lng}));

  // ---------- المحادثة اللحظيّة (0434: `delivery-chat:<delivery_id>`) ----------

  final _msgCtrl = StreamController<IncomingMessage>.broadcast();
  final Map<String, RealtimeChannel> _msgChannels = {};

  @override
  Stream<IncomingMessage> get incomingMessages => _msgCtrl.stream;

  @override
  void syncMessageChannels(Set<String> deliveryIds) {
    for (final id in _msgChannels.keys.toList()) {
      if (!deliveryIds.contains(id)) _db.removeChannel(_msgChannels.remove(id)!);
    }
    for (final id in deliveryIds) {
      if (_msgChannels.containsKey(id)) continue;
      // ⚠ الحمولةُ جرسٌ بلا نصّ (0457): القناةُ عامّةٌ لحامل المفتاح العلنيّ،
      //   فالنصُّ يُقرأ من `driver_delivery_messages` المحروسة برمز المندوب.
      final ch = _db.channel('delivery-chat:$id');
      ch.onBroadcast(
        event: 'new-message',
        callback: (payload) => _msgCtrl.add(IncomingMessage(
          deliveryId: (payload['delivery_id'] ?? id).toString(),
          sender: (payload['sender'] ?? '').toString(),
          body: (payload['body'] ?? '').toString(),
        )),
      ).subscribe();
      _msgChannels[id] = ch;
    }
  }

  @override
  void dispose() {
    syncMessageChannels(const {});
  }
}
