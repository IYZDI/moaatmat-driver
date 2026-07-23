import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n.dart';
import 'models.dart';
import 'data/repository.dart';
import 'data/driver_repository.dart';
import 'data/notifications_service.dart';

/// معلومات المندوب (ثابتة في الوضع التجريبي — تُجلب لاحقاً من الحساب الحقيقي).
class Driver {
  final String name;
  final String initial;
  final String place;
  final String phone;
  const Driver({required this.name, required this.initial, required this.place, required this.phone});
}

const kDriver = Driver(
  name: 'أحمد المصري',
  initial: 'أ',
  place: 'مطعم مؤتمات · مناوبة المساء',
  phone: '0555 123 456',
);

const kMockTotal = 12;

/// الحرف الأول لاسم المندوب (للأفاتار). يعيد '؟' إن كان الاسم فارغًا.
String driverInitial(String name) {
  final t = name.trim();
  return t.isEmpty ? '؟' : t[0];
}

/// وقت الآن بصيغة عربية بسيطة (٨:١٤ م).
String nowTime() {
  final d = DateTime.now();
  var h = d.hour;
  final m = d.minute.toString().padLeft(2, '0');
  final mer = h >= 12 ? 'م' : 'ص';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m $mer';
}

class DriverData {
  final bool authed;
  final String name;
  final String phone;
  final String orgName;
  final List<Order> orders;
  final List<HistoryItem> history;
  final Map<String, List<ChatMessage>> messages;
  final int total;
  final int delivered;
  final int remaining;

  const DriverData({
    required this.authed,
    required this.name,
    required this.phone,
    this.orgName = '',
    required this.orders,
    required this.history,
    required this.messages,
    required this.total,
    required this.delivered,
    required this.remaining,
  });

  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  DriverData copyWith({
    bool? authed,
    String? name,
    String? phone,
    String? orgName,
    List<Order>? orders,
    List<HistoryItem>? history,
    Map<String, List<ChatMessage>>? messages,
    int? total,
    int? delivered,
    int? remaining,
  }) =>
      DriverData(
        authed: authed ?? this.authed,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        orgName: orgName ?? this.orgName,
        orders: orders ?? this.orders,
        history: history ?? this.history,
        messages: messages ?? this.messages,
        total: total ?? this.total,
        delivered: delivered ?? this.delivered,
        remaining: remaining ?? this.remaining,
      );
}

// ---------- بذور الوضع التجريبي ----------
final _seedOrders = <Order>[
  Order(id: '1042', name: 'سارة عبدالله', initial: 'س', items: 'برجر مشوي × 2 · بطاطس · مشروب', address: 'حي الياسمين، شارع الأمير سلطان، مبنى 24', prefTime: '8:30 م', status: OrderStatus.ready, distance: '1.4 كم', eta: 'وصول تقريبي 8:26 م · 6 دقائق'),
  Order(id: '1043', name: 'خالد الفهد', initial: 'خ', items: 'دجاج بروستد × 1 · سلطة · صوص', address: 'حي النرجس، طريق الملك عبدالعزيز، فيلا 8', prefTime: '8:50 م', status: OrderStatus.preparing, distance: '2.1 كم', eta: 'وصول تقريبي 8:44 م · 9 دقائق'),
  Order(id: '1041', name: 'منى الحربي', initial: 'م', items: 'شاورما × 3', address: 'حي الملقا، شارع أنس بن مالك، مبنى 12', prefTime: '9:05 م', status: OrderStatus.enroute, distance: '3.0 كم', eta: 'وصول تقريبي 9:01 م · 12 دقيقة'),
];

final _seedHistory = <HistoryItem>[
  HistoryItem(id: '1041', name: 'منى الحربي', sub: 'سُلّم 8:12 م', ok: true),
  HistoryItem(id: '1039', name: 'عبدالرحمن ناصر', sub: 'سُلّم 7:48 م', ok: true),
  HistoryItem(id: '1036', name: 'فهد العتيبي', sub: 'العميل غير متواجد', ok: false),
  HistoryItem(id: '1034', name: 'ريم السالم', sub: 'سُلّم 7:20 م', ok: true),
];

final _seedMessages = <String, List<ChatMessage>>{
  '1042': [
    ChatMessage(outgoing: true, text: 'السلام عليكم، أنا مندوب التوصيل من مطعم مؤتمات 👋', time: '8:14 م'),
    ChatMessage(outgoing: false, text: 'أهلاً، الطلب في الطريق أليس كذلك؟', time: '8:15 م'),
    ChatMessage(outgoing: true, text: 'نعم، سأصل خلال 6 دقائق تقريباً. هل الموقع على شارع الأمير سلطان صحيح؟', time: '8:15 م'),
    ChatMessage(outgoing: false, text: 'صحيح، مبنى 24 الدور الثالث. سأنتظرك عند المدخل 🙏', time: '8:16 م'),
  ],
};

DriverData _mockInitial() => DriverData(
      authed: false,
      name: 'مندوب مؤتمات',
      phone: '+966 55 123 4567',
      orders: List.of(_seedOrders),
      history: List.of(_seedHistory),
      messages: {for (final e in _seedMessages.entries) e.key: List.of(e.value)},
      total: kMockTotal,
      delivered: 7,
      remaining: 5,
    );

DriverData _connectedInitial() => const DriverData(
      authed: false, name: '', phone: '', orders: [], history: [], messages: {}, total: 0, delivered: 0, remaining: 0,
    );

class DriverNotifier extends Notifier<DriverData> {
  DriverRepository? get _repo => ref.read(driverRepositoryProvider);
  bool get connected => _repo != null;

  StreamSubscription<void>? _ordersSub;
  StreamSubscription<IncomingMessage>? _msgSub;

  /// معرّف التوصيلة التي محادثتها مفتوحة الآن (لا نُشعر المندوب وهو داخلها).
  String? _openChatId;
  void setOpenChat(String? deliveryId) => _openChatId = deliveryId;

  @override
  DriverData build() {
    ref.onDispose(() {
      _ordersSub?.cancel();
      _msgSub?.cancel();
    });
    if (connected) {
      _restore(); // استعادة الجلسة المحفوظة (غير متزامنة)
      return _connectedInitial();
    }
    return _mockInitial();
  }

  Future<void> _restore() async {
    if (await _repo!.restoreSession()) {
      state = _applyIdentity(state.copyWith(authed: true));
      await refresh();
      await _subscribeOrders();
    }
  }

  /// يُدخل اسم المندوب وجواله واسم مطعمه الحقيقيّة (من الداشبورد) في الحالة.
  DriverData _applyIdentity(DriverData d) {
    final id = _repo?.identity;
    if (id == null) return d;
    return d.copyWith(name: id.name, phone: id.phone, orgName: id.orgName);
  }

  /// اسم المطعم ورقم دعمه (لزرّ «المساعدة والدعم»).
  Future<OrgInfo?> orgInfo() async {
    if (!connected) return const OrgInfo(name: 'مطعم مؤتمات (تجريبي)', supportPhone: '0500000000');
    try {
      return await _repo!.orgInfo();
    } catch (_) {
      return null;
    }
  }

  // ---------- المصادقة (OTP: رمز مؤسسة + جوال) ----------
  /// يرسل رمز التحقّق؛ يعيد اسم المؤسسة. يرمي عند الفشل.
  Future<String> sendOtp(String orgCode, String phone) async {
    if (!connected) return '';
    return _repo!.sendOtp(orgCode, phone);
  }

  Future<void> verifyOtp(String orgCode, String phone, String otp, String name) async {
    if (connected) {
      await _repo!.verifyOtp(orgCode, phone, otp, name.trim().isEmpty ? null : name.trim());
      state = _applyIdentity(state.copyWith(authed: true));
      await refresh();
      await _subscribeOrders();
    } else {
      state = state.copyWith(authed: true);
    }
  }

  /// يحفظ اسم المندوب عند أول دخول (لمن لا اسم له). يعيد true عند نجاح الحفظ
  /// في الخادم. عند تعذّر الحفظ نعكس الاسم محليًّا حتى لا يضيع.
  Future<bool> setDriverName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return false;
    if (connected) {
      try {
        await _repo!.updateName(n);
        state = _applyIdentity(state);
        return true;
      } catch (_) {
        state = state.copyWith(name: n);
        return false;
      }
    }
    state = state.copyWith(name: n);
    return true;
  }

  Future<void> logout() async {
    await _ordersSub?.cancel();
    _ordersSub = null;
    if (connected) {
      await _repo!.signOut();
      state = _connectedInitial();
    } else {
      state = state.copyWith(authed: false);
    }
  }

  /// اشتراك لحظي: عند تغيّر أي من طلبات المندوب نُعيد التحميل (Realtime).
  Future<void> _subscribeOrders() async {
    if (!connected) return;
    final id = _repo!.driverId;
    if (id == null || id.isEmpty) return;
    await _ordersSub?.cancel();
    _ordersSub = _repo!.myOrdersChanges(id).listen((_) => refresh());

    // رسائل المحادثة الواردة لحظيًّا → إشعار نظام + تحديث المحادثة المفتوحة.
    await _msgSub?.cancel();
    _msgSub = _repo!.incomingMessages.listen(_onIncomingMessage);
    await NotificationsService.instance.init();
  }

  void _onIncomingMessage(IncomingMessage msg) {
    if (msg.sender != 'customer') return; // رسائل المندوب نفسه لا تُشعِر
    // نجد التوصيلة صاحبة هذا الطلب
    Order? order;
    for (final o in state.orders) {
      if (o.orderId == msg.orderId) {
        order = o;
        break;
      }
    }
    if (order == null) return;
    // حدّث رسائل المحادثة (سواء كانت مفتوحة أو لا — لتكون جاهزة عند الفتح)
    loadMessages(order.id);
    // أشعر المندوب فقط إن لم تكن محادثة هذا الطلب مفتوحة أمامه الآن
    if (_openChatId != order.id) {
      final t = ref.read(stringsProvider);
      NotificationsService.instance.showMessage(title: t.messageFrom(order.name), body: msg.body);
    }
  }

  /// إعادة تحميل الطلبات والإحصاءات والسجل (الوضع المتّصل فقط).
  ///
  /// الجلسة تبقى حتى يسجّل المندوب خروجه بنفسه أو يُعطَّل حسابه من صفحة
  /// المناديب: خطأ «جلسة غير صالحة» (حساب معطَّل/رمز مُبطَل) → خروج تلقائي؛
  /// أمّا أخطاء الشبكة العابرة فتُتجاهل وتبقى الجلسة والبيانات كما هي.
  Future<void> refresh() async {
    if (!connected) return;
    try {
      final orders = await _repo!.myOrders();
      final stats = await _repo!.todayStats();
      final history = await _repo!.history();
      state = state.copyWith(
        orders: orders,
        history: history,
        total: stats.total,
        delivered: stats.delivered,
        remaining: stats.remaining,
      );
      // زامن قنوات المحادثة اللحظية مع الطلبات النشطة (التي لها order_id)
      _repo!.syncMessageChannels({
        for (final o in orders)
          if (o.active && o.orderId != null) o.orderId!,
      });
    } catch (e) {
      if (e.toString().contains('جلسة غير صالحة')) {
        await logout();
      }
      // غير ذلك: خطأ شبكة عابر — المحاولة التالية (الاستطلاع الدوري) تعيد التحميل.
    }
  }

  // ---------- الخطوات ----------
  void _setStatusMock(String id, OrderStatus status) {
    state = state.copyWith(orders: [
      for (final o in state.orders) o.id == id ? o.copyWith(status: status) : o,
    ]);
  }

  Future<void> confirmPickup(String id) async {
    if (connected) {
      await _repo!.confirmPickup(id);
      await refresh();
    } else {
      _setStatusMock(id, OrderStatus.picked);
    }
  }

  Future<void> confirmEnroute(String id) async {
    if (connected) {
      await _repo!.confirmEnroute(id);
      await refresh();
    } else {
      _setStatusMock(id, OrderStatus.enroute);
    }
  }

  /// تأكيد التسليم مع صورة الإثبات (تُرفع عبر دالة الحافة في الوضع المتّصل).
  Future<void> confirmDelivered(String id, List<int> photoBytes) async {
    if (connected) {
      await _repo!.confirmDelivered(id, photoBytes);
      await refresh();
    } else {
      _completeMock(id, ok: true, sub: 'سُلّم ${nowTime()}');
    }
  }

  Future<void> markFailed(String id, String reason) async {
    if (connected) {
      await _repo!.markFailed(id, reason);
      await refresh();
    } else {
      _completeMock(id, ok: false, sub: reason);
    }
  }

  void _completeMock(String id, {required bool ok, required String sub}) {
    final done = state.orderById(id);
    if (done == null) return;
    final newDelivered = ok ? (state.delivered + 1).clamp(0, state.total) : state.delivered;
    state = state.copyWith(
      orders: [for (final o in state.orders) if (o.id != id) o],
      history: [HistoryItem(id: done.id, name: done.name, sub: sub, ok: ok), ...state.history],
      delivered: newDelivered,
      remaining: state.total - newDelivered,
    );
  }

  // ---------- المحادثة ----------
  // id = معرّف التوصيلة (delivery_id)؛ المحادثة مرتبطة بـ order_id للطلب.
  Future<void> loadMessages(String id) async {
    if (!connected) return;
    final orderId = state.orderById(id)?.orderId;
    if (orderId == null) return; // توصيلة اشتراك بلا طلب → لا محادثة
    final msgs = await _repo!.messages(orderId);
    state = state.copyWith(messages: {...state.messages, id: msgs});
  }

  Future<void> sendMessage(String id, String text) async {
    if (connected) {
      final orderId = state.orderById(id)?.orderId;
      if (orderId == null) return;
      await _repo!.sendMessage(orderId, text);
      await loadMessages(id);
    } else {
      final list = List<ChatMessage>.of(state.messages[id] ?? const []);
      list.add(ChatMessage(outgoing: true, text: text, time: nowTime()));
      state = state.copyWith(messages: {...state.messages, id: list});
    }
  }
}

final driverProvider = NotifierProvider<DriverNotifier, DriverData>(DriverNotifier.new);
