import 'dart:async';

import '../models.dart';
import 'driver_repository.dart';

/// خادمٌ وهميٌّ في الذاكرة — للعرض بلا خادم وللاختبار.
///
/// ⚠ **يطبّق قواعدَ `driver_set_status` نفسَها** (0600): صورةٌ إلزاميّة، والبابُ
///   بإذن المطعم وبصورة، ولا تعذّرَ فوق مسلَّمة، و«في الطريق» لا تُحيي مغلَقًا.
///   خادمٌ وهميٌّ متساهل يُري واجهةً تنجح حيث يرفض الحقيقيّ — فيكذب العرضُ.
class MockDriverRepository implements DriverRepository {
  MockDriverRepository({
    this.latency = const Duration(milliseconds: 250),
    this.photoRequired = true,
    this.doorAllowed = true,
    DateTime? today,
  }) : _today = today ?? DateTime.now() {
    _seed();
  }

  /// تأخيرُ كلّ نداء — شبكةٌ حقيقيّةٌ لا تُجيب فورًا، والواجهةُ يجب أن تحتمل ذلك.
  final Duration latency;
  bool photoRequired;
  bool doorAllowed;
  final DateTime _today;

  /// لمحاكاة الانقطاع في الاختبار: كلُّ نداءٍ يفشل فشلًا عابرًا.
  bool offline = false;

  String? _token;
  DriverIdentity? _identity;
  String _name = '';
  final List<_Row> _rows = [];
  final List<HistoryEntry> _past = [];
  final Map<String, List<ChatMessage>> _chat = {};
  final _incoming = StreamController<IncomingMessage>.broadcast();

  /// آخرُ صورةٍ وصلت لكلّ توصيلة — ليتحقّق الاختبارُ من وصولها.
  final Map<String, int> photoBytes = {};

  @override
  bool get isDemo => true;
  @override
  bool get isAuthed => _token != null;
  @override
  String? get sessionToken => _token;
  @override
  DriverIdentity? get identity => _identity;

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (offline) throw const DriverActionError.transient();
  }

  void _authed() {
    if (_token == null) throw const DriverActionError.session();
  }

  // ---------- الدخول ----------

  @override
  Future<bool> restoreSession() async => _token != null;

  @override
  Future<String> sendOtp(String orgCode, String phone) async {
    await Future<void>.delayed(latency);
    if (orgCode.trim().isEmpty) throw Exception('أدخل رمز المطعم');
    if (phone.replaceAll(RegExp(r'\D'), '').length < 9) throw Exception('رقم الجوال غير صحيح');
    return 'مطبخ العافية (تجريبي)';
  }

  @override
  Future<DriverIdentity> verifyOtp(String orgCode, String phone, String otp, {String? name}) async {
    await Future<void>.delayed(latency);
    if (otp.trim().length < 4) throw Exception('رمز التحقّق غير صحيح');
    if (name != null && name.trim().isNotEmpty) _name = name.trim();
    _token = '00000000-0000-4000-8000-00000000d0d0';
    _identity = DriverIdentity(driverId: 'demo-driver', name: _name, phone: '+966500000099', orgName: 'مطبخ العافية (تجريبي)');
    return _identity!;
  }

  @override
  Future<void> setName(String name) async {
    await _wait();
    _authed();
    _name = name.trim();
    final id = _identity!;
    _identity = DriverIdentity(driverId: id.driverId, name: _name, phone: id.phone, orgName: id.orgName);
  }

  @override
  Future<void> signOut() async {
    _token = null;
    _identity = null;
  }

  // ---------- القراءة ----------

  @override
  Future<DriverProfile> profile() async {
    await _wait();
    _authed();
    return DriverProfile(
      name: _name,
      phone: '+966500000099',
      orgName: 'مطبخ العافية (تجريبي)',
      color: '#4F46E5',
      supportPhone: '+966500000001',
      photoRequired: photoRequired,
      doorAllowed: doorAllowed,
      orgToday: DateTime(_today.year, _today.month, _today.day),
    );
  }

  @override
  Future<List<Stop>> route() async {
    await _wait();
    _authed();
    return [for (final r in _rows) r.toStop()];
  }

  @override
  Future<List<HistoryEntry>> history() async {
    await _wait();
    _authed();
    final today = [
      for (final r in _rows.reversed)
        if (r.status == 'delivered' || r.status == 'failed')
          HistoryEntry(
            id: r.id,
            customerName: r.name,
            bagNo: r.bag,
            delivered: r.status == 'delivered',
            atDoor: r.handoff == 'door',
            deliveredAt: r.deliveredAt,
            failureReason: r.failure,
            routeDate: DateTime(_today.year, _today.month, _today.day),
            slotLabel: r.slot,
          ),
    ];
    return [...today, ..._past];
  }

  // ---------- القواعد (نسخةُ driver_set_status) ----------

  _Row _row(String id) {
    for (final r in _rows) {
      if (r.id == id) return r;
    }
    throw const DriverActionError.permanent('هذه التوصيلةُ ليست لك');
  }

  void _apply(String id, String action, {String? reason, String? photo}) {
    final d = _row(id);
    final now = DateTime.now();
    switch (action) {
      case 'picked':
        d.pickedAt ??= now;
      case 'enroute':
        if (d.status == 'delivered' || d.status == 'failed') return;
        d.status = 'out_for_delivery';
        d.enrouteAt ??= now;
        d.pickedAt ??= now;
      case 'defer':
        if (d.status == 'out_for_delivery') d.status = 'ready';
      case 'delivered':
      case 'delivered_door':
        final p = photo ?? d.photo;
        if (action == 'delivered_door') {
          if (!doorAllowed) throw const DriverActionError.permanent('الترك عند الباب غير مسموح في هذا المطعم');
          if (p == null) throw const DriverActionError.permanent('الترك عند الباب يحتاج صورة');
        } else if (photoRequired && p == null) {
          throw const DriverActionError.permanent('صورة التسليم إلزاميّة في هذا المطعم');
        }
        d.status = 'delivered';
        d.deliveredAt ??= now;
        d.photo = p;
        d.handoff = action == 'delivered_door' ? 'door' : 'hand';
        d.failure = null;
      case 'failed':
        final r = (reason ?? '').trim();
        if (r.isEmpty) throw const DriverActionError.permanent('اختر سبب التعذّر');
        if (d.status == 'delivered') {
          throw const DriverActionError.permanent('سُلّمت هذه التوصيلة — لا يُسجَّل لها تعذّر');
        }
        d.status = 'failed';
        d.failure = r.length > 300 ? r.substring(0, 300) : r;
        d.handoff = null;
      default:
        throw DriverActionError.permanent('إجراء غير معروف: $action');
    }
  }

  @override
  Future<void> setStatus(String deliveryId, String action, {String? reason}) async {
    await _wait();
    _authed();
    _apply(deliveryId, action, reason: reason);
  }

  @override
  Future<void> uploadProof(String deliveryId, List<int> jpeg, {bool door = false}) async {
    await _wait();
    _authed();
    if (jpeg.isEmpty) throw const DriverActionError.permanent('تعذّرت قراءة الصورة — التقطها من جديد');
    _row(deliveryId);
    if (door && !doorAllowed) {
      throw const DriverActionError.permanent('الترك عند الباب غير مسموح في هذا المطعم');
    }
    photoBytes[deliveryId] = jpeg.length;
    _apply(deliveryId, door ? 'delivered_door' : 'delivered', photo: 'demo://proof/$deliveryId.jpg');
  }

  // ---------- المحادثة ----------

  @override
  Future<List<ChatMessage>> messages(String deliveryId) async {
    await _wait();
    _authed();
    return List.of(_chat[deliveryId] ?? const []);
  }

  @override
  Future<void> sendMessage(String deliveryId, String body) async {
    await _wait();
    _authed();
    _row(deliveryId);
    (_chat[deliveryId] ??= []).add(ChatMessage(outgoing: true, text: body, at: DateTime.now()));
  }

  /// يحاكي رسالةً من العميل (للاختبار) — لا يُنادى في العرض: «حضورٌ» وهميّ كذبٌ.
  void simulateCustomerMessage(String deliveryId, String body) {
    (_chat[deliveryId] ??= []).add(ChatMessage(outgoing: false, text: body, at: DateTime.now()));
    _incoming.add(IncomingMessage(deliveryId: deliveryId, sender: 'customer', body: ''));
  }

  @override
  Future<void> pingLocation(double lat, double lng) async {}

  @override
  void syncMessageChannels(Set<String> deliveryIds) {}

  @override
  Stream<IncomingMessage> get incomingMessages => _incoming.stream;

  @override
  void dispose() {}

  /// صفُّ الخادم كما يُرى من الاختبار (حالةٌ خام).
  String statusOf(String id) => _row(id).status;
  bool pickedOf(String id) => _row(id).pickedAt != null;
  String? handoffOf(String id) => _row(id).handoff;

  // ---------- البذور: الرياض، فرعٌ واحد، فترتان + طلبُ نقطة بيع ----------

  static String uuid(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

  static const branchId = '00000000-0000-4000-8000-0000000000b1';
  static const branchPos = LatLon(24.8121, 46.6402);
  static const morning = 'صباحًا (6 - 9 ص)';
  static const evening = 'مساءً (5 - 8 م)';

  void _seed() {
    var n = 0;
    void add(String slot, int sort, String from, String to, int bag, String name, String? phone, String address,
        double? lat, double? lng,
        {String? notes, String status = 'ready', int meals = 3, String? items}) {
      n++;
      _rows.add(_Row(
        id: uuid(100 + n),
        dayId: uuid(500 + n),
        orderId: null,
        slot: slot,
        sort: sort,
        from: from,
        to: to,
        bag: bag,
        name: name,
        phone: phone,
        address: address,
        notes: notes,
        lat: lat,
        lng: lng,
        status: status,
        meals: meals,
        items: items ?? 'دجاج مشوي بالأرز · سلطة كينوا · زبادي بالتوت',
      ));
    }

    // الصباح: ثمانية أكياس — واحدٌ ما زال في المطبخ، وواحدٌ بلا إحداثيّات.
    add(morning, 1, '06:00', '09:00', 3, 'سارة العتيبي', '+966500000011', 'الياسمين، شارع الملقا، مبنى 14، شقة 3',
        24.8185, 46.6391, notes: 'البوابة الثانية — لا تطرق الجرس، الطفل نائم');
    add(morning, 1, '06:00', '09:00', 5, 'خالد الدوسري', '+966500000012', 'النرجس، شارع أبي بكر الصديق، فيلا 8',
        24.8402, 46.6550);
    add(morning, 1, '06:00', '09:00', 7, 'نورة القحطاني', '+966500000013', 'الياسمين، شارع الأمير سلطان، مبنى 24',
        24.8231, 46.6468, meals: 2);
    add(morning, 1, '06:00', '09:00', 12, 'فهد الشمري', '+966500000014', 'الملقا، طريق أنس بن مالك، مبنى 9، شقة 12',
        24.8015, 46.6273, notes: 'اتصل قبل الوصول بخمس دقائق');
    add(morning, 1, '06:00', '09:00', 15, 'ريم الزهراني', null, 'الصحافة، شارع العليا، برج 3، مكتب 41',
        24.7952, 46.6464);
    add(morning, 1, '06:00', '09:00', 17, 'عبدالله الحربي', '+966500000016', 'النخيل، شارع التخصصي، فيلا 22',
        24.7408, 46.6489, status: 'preparing', meals: 4);
    add(morning, 1, '06:00', '09:00', 21, 'منى السبيعي', '+966500000017', 'العقيق، شارع الإمام سعود، مبنى 5',
        24.7790, 46.6301);
    add(morning, 1, '06:00', '09:00', 24, 'تركي المطيري', '+966500000018', 'حطين، شارع الأمير محمد بن سعد، مبنى 31',
        null, null, notes: 'المدخل الخلفي بجانب المسجد');
    // المساء: أربعة، ما زالت تُطهى.
    add(evening, 2, '17:00', '20:00', 30, 'ليان الغامدي', '+966500000021', 'الربيع، شارع عثمان بن عفان، مبنى 2',
        24.7988, 46.6697, status: 'preparing');
    add(evening, 2, '17:00', '20:00', 31, 'ماجد العنزي', '+966500000022', 'الندى، شارع الثمامة، فيلا 17',
        24.8063, 46.6812, status: 'preparing');
    add(evening, 2, '17:00', '20:00', 33, 'هند الشهري', '+966500000023', 'الياسمين، شارع الملك عبدالعزيز، مبنى 40',
        24.8264, 46.6589, status: 'preparing', notes: 'اتركه عند حارس العمارة إن لم أرد');
    add(evening, 2, '17:00', '20:00', 36, 'العنود الرشيد', '+966500000024', 'النفل، شارع المحمدية، فيلا 6',
        24.7849, 46.6866, status: 'preparing', meals: 2);
    // طلبُ نقطة بيعٍ بلا فترةٍ ولا رقمِ كيس.
    _rows.add(_Row(
      id: uuid(199),
      dayId: null,
      orderId: uuid(299),
      slot: null,
      sort: null,
      from: null,
      to: null,
      bag: null,
      orderNo: 1042,
      name: 'بندر الشهراني',
      phone: '+966500000031',
      address: 'الغدير، شارع الأمير تركي، مبنى 11',
      notes: null,
      lat: 24.7731,
      lng: 46.6582,
      status: 'ready',
      meals: 3,
      items: 'برجر دجاج مشوي × 2 · بطاطس بالفرن × 1',
      kind: 'order',
    ));

    // محادثةٌ مبذورة على كيس #12.
    final d12 = _rows.firstWhere((r) => r.bag == 12).id;
    final t = DateTime.now();
    _chat[d12] = [
      ChatMessage(outgoing: false, text: 'صباح الخير، أنا في الدوام — اتركه عند حارس المبنى لو سمحت', at: t.subtract(const Duration(minutes: 30))),
      ChatMessage(outgoing: true, text: 'تمام، أبشر', at: t.subtract(const Duration(minutes: 29))),
    ];

    // سجلُّ الأيّام الخمسة الماضية.
    const names = ['سارة العتيبي', 'خالد الدوسري', 'نورة القحطاني', 'فهد الشمري', 'منى السبيعي', 'ليان الغامدي',
      'ماجد العنزي', 'هند الشهري'];
    const reasons = ['لا يردّ على الاتصال', 'العميل غير متواجد', 'العنوان غير صحيح'];
    var h = 0;
    for (var day = 1; day <= 5; day++) {
      final date = DateTime(_today.year, _today.month, _today.day - day);
      final count = 6 + (day % 3);
      for (var i = 0; i < count; i++) {
        h++;
        final evening0 = i >= count - 3;
        final at = DateTime(date.year, date.month, date.day, evening0 ? 17 + i % 3 : 6 + i % 3, (i * 13) % 60);
        final failed = (h % 9) == 0;
        final door = !failed && (h % 5) == 0;
        _past.add(HistoryEntry(
          id: uuid(1000 + h),
          customerName: names[h % names.length],
          bagNo: 3 + (h * 7) % 34,
          delivered: !failed,
          atDoor: door,
          deliveredAt: failed ? null : at,
          failureReason: failed ? reasons[h % reasons.length] : null,
          routeDate: date,
          slotLabel: evening0 ? evening : morning,
        ));
      }
    }
  }
}

class _Row {
  _Row({
    required this.id,
    required this.dayId,
    required this.orderId,
    required this.slot,
    required this.sort,
    required this.from,
    required this.to,
    required this.bag,
    this.orderNo,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    required this.lat,
    required this.lng,
    required this.status,
    required this.meals,
    required this.items,
    this.kind = 'subscription',
  });

  final String id;
  final String? dayId;
  final String? orderId;
  final String? slot;
  final int? sort;
  final String? from;
  final String? to;
  final int? bag;
  final int? orderNo;
  final String name;
  final String? phone;
  final String address;
  final String? notes;
  final double? lat;
  final double? lng;
  String status; // preparing | ready | out_for_delivery | delivered | failed
  final int meals;
  final String items;
  final String kind;
  DateTime? pickedAt;
  DateTime? enrouteAt;
  DateTime? deliveredAt;
  String? handoff;
  String? failure;
  String? photo;

  /// كما يشتقّ `driver_route` الحالة: «picked» من `picked_at` (0144).
  Stop toStop() {
    final derived = (status == 'preparing' || status == 'ready') && pickedAt != null ? 'picked' : status;
    return Stop(
      id: id,
      orderId: orderId,
      subscriptionDayId: dayId,
      isSubscription: kind == 'subscription',
      status: stopStatusFromDb(derived),
      pickedAt: pickedAt,
      enrouteAt: enrouteAt,
      deliveredAt: deliveredAt,
      handoff: handoff,
      failureReason: failure,
      customerName: name,
      phone: phone,
      address: address,
      notes: notes,
      pos: lat != null && lng != null ? LatLon(lat!, lng!) : null,
      bagNo: bag,
      orderNo: orderNo,
      slotLabel: slot,
      slotSort: sort,
      slotStart: from,
      slotEnd: to,
      mealsCount: meals,
      items: items,
      branchId: MockDriverRepository.branchId,
      branchName: 'فرع الياسمين',
      branchPos: MockDriverRepository.branchPos,
      routeDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );
  }
}
