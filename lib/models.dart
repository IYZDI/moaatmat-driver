/// نماذجُ تطبيق المندوب — محطّاتُ المسار كما تُعيدها `driver_route` (0600).
library;

/// حالةُ المحطة لدى المندوب.
///   preparing/ready — في المطبخ · picked — حمّله · enroute — في طريقه إليها الآن
///   delivered/failed — أُغلقت.
enum StopStatus { preparing, ready, picked, enroute, delivered, failed }

StopStatus stopStatusFromDb(String? s) {
  switch (s) {
    case 'preparing':
    case 'scheduled':
      return StopStatus.preparing;
    case 'ready':
      return StopStatus.ready;
    case 'picked':
      return StopStatus.picked;
    case 'out_for_delivery':
      return StopStatus.enroute;
    case 'delivered':
      return StopStatus.delivered;
    case 'failed':
    case 'cancelled':
      return StopStatus.failed;
    default:
      return StopStatus.preparing;
  }
}

/// نقطةٌ على الخريطة.
class LatLon {
  final double lat;
  final double lng;
  const LatLon(this.lat, this.lng);

  @override
  bool operator ==(Object other) => other is LatLon && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => '$lat,$lng';
}

/// يختصر معرّفًا طويلًا لعرضه حين لا رقمَ كيسٍ له (طلبُ نقطة البيع): أربعةُ
/// محارف كبيرة يقرؤها إنسانٌ بصوته — كما في نسخة الويب.
String shortCode(String id) {
  final s = id.replaceAll('-', '');
  return s.isEmpty ? '—' : s.substring(0, s.length < 4 ? s.length : 4).toUpperCase();
}

/// محطّةٌ في مسار اليوم — توصيلةٌ واحدة.
class Stop {
  const Stop({
    required this.id,
    this.orderId,
    this.subscriptionDayId,
    this.isSubscription = true,
    required this.status,
    this.pickedAt,
    this.enrouteAt,
    this.deliveredAt,
    this.handoff,
    this.failureReason,
    required this.customerName,
    this.phone,
    this.address,
    this.notes,
    this.pos,
    this.bagNo,
    this.orderNo,
    this.slotLabel,
    this.slotSort,
    this.slotStart,
    this.slotEnd,
    this.mealsCount = 0,
    this.items,
    this.branchId,
    this.branchName,
    this.branchPos,
    this.routeDate,
    this.pending,
  });

  final String id; // معرّفُ التوصيلة
  final String? orderId;
  final String? subscriptionDayId; // ما يحمله باركودُ الملصق
  final bool isSubscription;
  final StopStatus status;
  final DateTime? pickedAt;
  final DateTime? enrouteAt;
  final DateTime? deliveredAt;
  final String? handoff; // hand | door
  final String? failureReason;
  final String customerName;
  final String? phone;
  final String? address;
  final String? notes; // «ملاحظات للسائق» من تطبيق العميل
  final LatLon? pos;
  final int? bagNo; // رقمُ «طلب اليوم» المطبوع على الملصق
  final int? orderNo;
  final String? slotLabel;
  final int? slotSort;
  final String? slotStart;
  final String? slotEnd;
  final int mealsCount;
  final String? items;
  final String? branchId;
  final String? branchName;
  final LatLon? branchPos;
  final DateTime? routeDate;

  /// فعلٌ سُجّل على الهاتف ولم يصل الخادمَ بعد (picked · delivered · …) —
  /// الواجهةُ تعرض أثرَه فورًا وتقول إنّه «يُرسَل».
  final String? pending;

  bool get isClosed => status == StopStatus.delivered || status == StopStatus.failed;
  bool get isOpen => !isClosed;

  /// الكيسُ في سيّارة المندوب؟
  bool get isLoaded =>
      pickedAt != null ||
      status == StopStatus.picked ||
      status == StopStatus.enroute ||
      isClosed;

  /// ما زال في المطبخ لم يجهز؟
  bool get inKitchen => status == StopStatus.preparing && pickedAt == null;

  /// الرقمُ كما على الملصق: «#12» — وطلبُ نقطة البيع بلا رقمٍ يأخذ رمزًا قصيرًا.
  String get bagLabel => bagNo != null ? '#$bagNo' : '#${shortCode(id)}';

  String get slotKey => slotLabel ?? '';

  bool get atDoor => handoff == 'door';

  Stop copyWith({
    StopStatus? status,
    DateTime? pickedAt,
    String? handoff,
    String? failureReason,
    String? pending,
    bool clearPending = false,
  }) =>
      Stop(
        id: id,
        orderId: orderId,
        subscriptionDayId: subscriptionDayId,
        isSubscription: isSubscription,
        status: status ?? this.status,
        pickedAt: pickedAt ?? this.pickedAt,
        enrouteAt: enrouteAt,
        deliveredAt: deliveredAt,
        handoff: handoff ?? this.handoff,
        failureReason: failureReason ?? this.failureReason,
        customerName: customerName,
        phone: phone,
        address: address,
        notes: notes,
        pos: pos,
        bagNo: bagNo,
        orderNo: orderNo,
        slotLabel: slotLabel,
        slotSort: slotSort,
        slotStart: slotStart,
        slotEnd: slotEnd,
        mealsCount: mealsCount,
        items: items,
        branchId: branchId,
        branchName: branchName,
        branchPos: branchPos,
        routeDate: routeDate,
        pending: clearPending ? null : (pending ?? this.pending),
      );
}

/// المندوبُ ومطعمُه — من `driver_profile` (0600).
class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.phone,
    required this.orgName,
    this.logoUrl,
    this.color,
    this.supportPhone,
    this.photoRequired = true,
    this.doorAllowed = true,
    this.orgToday,
  });

  final String name;
  final String phone;
  final String orgName;
  final String? logoUrl;
  final String? color;
  final String? supportPhone;

  /// قرارُ المطعم: صورةُ التسليم إلزاميّة؟ (يحرسه الخادم كذلك.)
  final bool photoRequired;

  /// قرارُ المطعم: «تركته عند الباب» مقبول؟
  final bool doorAllowed;
  final DateTime? orgToday;

  DriverProfile copyWith({String? name}) => DriverProfile(
        name: name ?? this.name,
        phone: phone,
        orgName: orgName,
        logoUrl: logoUrl,
        color: color,
        supportPhone: supportPhone,
        photoRequired: photoRequired,
        doorAllowed: doorAllowed,
        orgToday: orgToday,
      );
}

/// سطرٌ في «سجلّي» — من `driver_history_v2` (بالتاريخ ورقم الكيس).
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.customerName,
    this.bagNo,
    required this.delivered,
    this.atDoor = false,
    this.deliveredAt,
    this.failureReason,
    this.routeDate,
    this.slotLabel,
  });

  final String id;
  final String customerName;
  final int? bagNo;
  final bool delivered;
  final bool atDoor;
  final DateTime? deliveredAt;
  final String? failureReason;
  final DateTime? routeDate;
  final String? slotLabel;

  String get bagLabel => bagNo != null ? '#$bagNo' : '#${shortCode(id)}';
}

/// رسالةُ محادثةٍ مع العميل.
class ChatMessage {
  final bool outgoing; // من المندوب
  final String text;
  final DateTime? at;
  const ChatMessage({required this.outgoing, required this.text, this.at});
}

/// رسالةٌ واردةٌ لحظيًّا (بثّ `delivery-chat:<id>` — 0434).
class IncomingMessage {
  final String deliveryId;
  final String sender; // customer | driver
  final String body;
  const IncomingMessage({required this.deliveryId, required this.sender, required this.body});
}

/// هويّةُ المندوب بعد الدخول.
class DriverIdentity {
  final String driverId;
  final String name;
  final String phone;
  final String orgName;
  const DriverIdentity({required this.driverId, required this.name, required this.phone, required this.orgName});
}
