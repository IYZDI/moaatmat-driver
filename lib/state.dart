import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'data/repository.dart';
import 'data/driver_repository.dart';

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
  final String phone;
  final List<Order> orders;
  final List<HistoryItem> history;
  final Map<String, List<ChatMessage>> messages;
  final int total;
  final int delivered;
  final int remaining;

  const DriverData({
    required this.authed,
    required this.phone,
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
    String? phone,
    List<Order>? orders,
    List<HistoryItem>? history,
    Map<String, List<ChatMessage>>? messages,
    int? total,
    int? delivered,
    int? remaining,
  }) =>
      DriverData(
        authed: authed ?? this.authed,
        phone: phone ?? this.phone,
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
      phone: '+966 55 123 4567',
      orders: List.of(_seedOrders),
      history: List.of(_seedHistory),
      messages: {for (final e in _seedMessages.entries) e.key: List.of(e.value)},
      total: kMockTotal,
      delivered: 7,
      remaining: 5,
    );

DriverData _connectedInitial() => const DriverData(
      authed: false, phone: '', orders: [], history: [], messages: {}, total: 0, delivered: 0, remaining: 0,
    );

class DriverNotifier extends Notifier<DriverData> {
  DriverRepository? get _repo => ref.read(driverRepositoryProvider);
  bool get connected => _repo != null;

  @override
  DriverData build() => connected ? _connectedInitial() : _mockInitial();

  // ---------- المصادقة ----------
  Future<void> signIn(String email, String password) async {
    if (connected) {
      await _repo!.signIn(email, password);
      state = state.copyWith(authed: true);
      await refresh();
    } else {
      state = state.copyWith(authed: true);
    }
  }

  Future<void> logout() async {
    if (connected) {
      await _repo!.signOut();
      state = _connectedInitial();
    } else {
      state = state.copyWith(authed: false);
    }
  }

  /// إعادة تحميل الطلبات والإحصاءات والسجل (الوضع المتّصل فقط).
  Future<void> refresh() async {
    if (!connected) return;
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

  /// يرفع صورة التسليم ويعيد رابطها (تجريبيًّا رابط وهمي).
  Future<String> uploadProof(String orderId, List<int> bytes) async {
    if (connected) return _repo!.uploadProof(orderId, bytes);
    return 'mock://delivery-proof/$orderId';
  }

  Future<void> confirmDelivered(String id, String photoUrl) async {
    if (connected) {
      await _repo!.confirmDelivered(id, photoUrl);
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
  Future<void> loadMessages(String id) async {
    if (!connected) return;
    final msgs = await _repo!.messages(id);
    state = state.copyWith(messages: {...state.messages, id: msgs});
  }

  Future<void> sendMessage(String id, String text) async {
    if (connected) {
      await _repo!.sendMessage(id, text);
      await loadMessages(id);
    } else {
      final list = List<ChatMessage>.of(state.messages[id] ?? const []);
      list.add(ChatMessage(outgoing: true, text: text, time: nowTime()));
      state = state.copyWith(messages: {...state.messages, id: list});
    }
  }
}

final driverProvider = NotifierProvider<DriverNotifier, DriverData>(DriverNotifier.new);
