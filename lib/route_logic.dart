/// منطقُ «مساري اليوم» — دوالُّ صافية بلا Flutter ولا شبكة، فتُقاس وحدَها.
///
/// ⚠ ترتيبُ المحطّات **يجب أن يساوي ورقةَ المسار المطبوعة** في لوحة المطعم
///   (`drv-dash/src/components/kitchen/deliveryRoute.js`): المطبخُ يعبّئ الأكياسَ
///   بترتيبها، فإن رتّب التطبيقُ بغيره صار الكيسُ التالي في قاع الصندوق.
library;

import 'dart:math' as math;

import 'models.dart';

// ═══════════════ ① الهندسة — نقلٌ حرفيٌّ من deliveryRoute.js ═══════════════

const double _rKm = 6371;
double _rad(double d) => d * math.pi / 180;

/// موقعٌ صالح؟ ‎0,0‎ (وسط المحيط) قيمةٌ افتراضيّةٌ لا موقع — كما في اللوحة.
bool hasXY(LatLon? p) =>
    p != null && p.lat.isFinite && p.lng.isFinite && !(p.lat == 0 && p.lng == 0);

/// مسافةٌ مباشرة بالكيلومتر (هافرساين) — لا طولُ الطريق.
double? distanceKm(LatLon? a, LatLon? b) {
  if (!hasXY(a) || !hasXY(b)) return null;
  final dLat = _rad(b!.lat - a!.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _rKm * math.asin(math.min(1, math.sqrt(h)));
}

/// أقربُ جارٍ انطلاقًا من [start] على أيّ نوع — [posOf] تُخرج موقعَه.
///
/// ⚠ المقارنةُ `<` صارمة كما في اللوحة: عند التساوي تبقى الأسبقُ في المدخل،
///   وإلّا اختلفت الورقتان في مسارٍ فيه بنايةٌ واحدةٌ لعميلين.
/// ⚠ وما لا موقعَ له لا يُخمَّن: يُلحق بالآخر بترتيب المدخل.
List<T> orderBy<T>(LatLon? start, List<T> items, LatLon? Function(T) posOf) {
  final located = [for (final s in items) if (hasXY(posOf(s))) s];
  final lost = [for (final s in items) if (!hasXY(posOf(s))) s];
  final out = <T>[];
  var cur = hasXY(start) ? start : null;
  final left = [...located];
  while (left.isNotEmpty) {
    var best = 0;
    if (cur != null) {
      var bestD = double.infinity;
      for (var i = 0; i < left.length; i++) {
        final d = distanceKm(cur, posOf(left[i]))!;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
    }
    final s = left.removeAt(best);
    out.add(s);
    cur = posOf(s);
  }
  return [...out, ...lost];
}

/// `orderStops(start, stops)` في اللوحة — على محطّات المسار.
List<Stop> orderStops(LatLon? start, List<Stop> stops) => orderBy(start, stops, (s) => s.pos);

/// أكثرُ قيمةٍ تكرارًا، والأسبقُ ظهورًا يفوز عند التعادل (كـ`mode` في اللوحة:
/// `Map` يحفظ ترتيب الإدراج و`>` صارمة).
T? modeOf<T>(Iterable<T?> list) {
  final m = <T, int>{};
  for (final v in list) {
    if (v != null) m[v] = (m[v] ?? 0) + 1;
  }
  T? best;
  var n = 0;
  m.forEach((v, c) {
    if (c > n) {
      best = v;
      n = c;
    }
  });
  return best;
}

/// رابطُ «الاتّجاهات» في خرائط جوجل: نقطةُ البدء ثمّ المحطّاتُ بترتيبها (حتّى عشر)
/// — كـ`mapsDirUrl` في اللوحة.
Uri? mapsDirUrl(LatLon? start, List<Stop> stops) {
  final pts = [for (final s in stops) if (hasXY(s.pos)) '${s.pos!.lat},${s.pos!.lng}'].take(10).toList();
  if (pts.isEmpty) return null;
  final q = <String, String>{'api': '1', 'destination': pts.last, 'travelmode': 'driving'};
  if (hasXY(start)) q['origin'] = '${start!.lat},${start.lng}';
  if (pts.length > 1) q['waypoints'] = pts.sublist(0, pts.length - 1).join('|');
  return Uri.https('www.google.com', '/maps/dir/', q);
}

/// الملاحةُ إلى محطّةٍ واحدة: إلى إحداثيّاتها، وإلّا بحثًا بعنوانها، وإلّا لا شيء
/// (فيُعطَّل الزرّ بسببٍ ظاهر بدل أن يفتح خريطةً فارغة).
Uri? navigationUri(Stop s) {
  if (hasXY(s.pos)) {
    return Uri.https('www.google.com', '/maps/dir/',
        {'api': '1', 'destination': '${s.pos!.lat},${s.pos!.lng}', 'travelmode': 'driving'});
  }
  final a = s.address?.trim() ?? '';
  if (a.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': a});
}

/// أرقامُ الجوّال الدوليّة بلا «+» — صيغةُ wa.me. والرقمُ المحلّيّ «05…» سعوديّ.
String? phoneDigits(String? phone) {
  var d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('00')) d = d.substring(2);
  if (d.startsWith('05') && d.length == 10) d = '966${d.substring(1)}';
  if (d.startsWith('5') && d.length == 9) d = '966$d';
  return d;
}

Uri? telUri(String? phone) {
  final p = (phone ?? '').replaceAll(RegExp(r'[^\d+]'), '');
  return p.isEmpty ? null : Uri(scheme: 'tel', path: p);
}

Uri? whatsappUri(String? phone) {
  final d = phoneDigits(phone);
  return d == null ? null : Uri.https('wa.me', '/$d');
}

// ═══════════════ ② المسح ═══════════════

final _uuidRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// ملصقُ الكيس `MQD:<subscription_day_id>` ⇒ المعرّف (بأحرفٍ صغيرة)، وإلّا null.
/// والمعرّفُ يُفحص شكلًا: رمزُ QR آخر في المطبخ لا يُقرأ ملصقًا.
String? parseBagQr(String raw) {
  final t = raw.trim();
  if (t.length < 4 || t.substring(0, 4).toUpperCase() != 'MQD:') return null;
  final id = t.substring(4).trim();
  return _uuidRe.hasMatch(id) ? id.toLowerCase() : null;
}

/// رمزُ المطعم من QR: رابطُ `https://<host>/driver?code=XXXX` أو الرمزُ عاريًا
/// (٤–١٢ حرفًا ورقمًا). يُعاد بأحرفٍ كبيرة كما يُكتب في الحقل.
String? parseOrgCodeQr(String raw) {
  final t = raw.trim();
  final code = RegExp(r'^[A-Za-z0-9]{4,12}$');
  final u = Uri.tryParse(t);
  if (u != null && (u.scheme == 'https' || u.scheme == 'http')) {
    final c = (u.queryParameters['code'] ?? '').trim();
    return code.hasMatch(c) ? c.toUpperCase() : null;
  }
  return code.hasMatch(t) ? t.toUpperCase() : null;
}

// ═══════════════ ③ أثرُ الأفعال المعلّقة ═══════════════

/// فعلٌ سُجّل على الهاتف ولم يُعرف أثرُه من الخادم بعد.
typedef StopAction = ({String deliveryId, String action, String? reason});

/// يطبّق الأفعالَ بترتيبها على محطّات الخادم — بالقواعد نفسها التي يطبّقها
/// `driver_set_status`، فما تراه اليدُ الآن هو ما سيكتبه الخادمُ بعد ثوانٍ.
List<Stop> applyActions(List<Stop> server, Iterable<StopAction> actions, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final byId = {for (final s in server) s.id: s};
  for (final a in actions) {
    final s = byId[a.deliveryId];
    if (s == null) continue;
    Stop? next;
    switch (a.action) {
      case 'picked':
        next = s.copyWith(
          pickedAt: s.pickedAt ?? at,
          status: (s.status == StopStatus.preparing || s.status == StopStatus.ready) ? StopStatus.picked : null,
        );
      case 'enroute':
        // لا يُحيي مغلَقًا — كالخادم.
        if (s.isOpen) next = s.copyWith(status: StopStatus.enroute, pickedAt: s.pickedAt ?? at);
      case 'defer':
        // يعود «جاهزًا» والكيسُ معه، فيُقرأ «محمّلًا» كما يشتقّه driver_route.
        if (s.status == StopStatus.enroute) next = s.copyWith(status: StopStatus.picked);
      case 'delivered':
      case 'delivered_door':
        next = s.copyWith(
          status: StopStatus.delivered,
          handoff: a.action == 'delivered_door' ? 'door' : 'hand',
          pickedAt: s.pickedAt ?? at,
        );
      case 'failed':
        if (s.status != StopStatus.delivered) {
          next = s.copyWith(status: StopStatus.failed, failureReason: a.reason);
        }
    }
    byId[s.id] = (next ?? s).copyWith(pending: a.action);
  }
  return [for (final s in server) byId[s.id]!];
}

// ═══════════════ ④ الفترات والمراحل ═══════════════

enum RoutePhase { loading, onRoute, done }

/// ما يقرّره المندوبُ على هاتفه ولا يعرفه الخادم: ترتيبٌ شخصيّ ومَن بدأ ومَن
/// اتّصل. يُحفظ لكلّ «يوم مطعم» ويُصفَّر حين يتغيّر اليوم.
class RouteLocal {
  const RouteLocal({
    this.day,
    this.deferred = const [],
    this.pinned,
    this.started = const {},
    this.acked = const {},
    this.calls = const {},
  });

  /// يومُ المطعم الذي تخصّه هذه القرارات (yyyy-MM-dd).
  final String? day;

  /// «أعود إليه آخر المسار» — بترتيب التأجيل، فآخرُ مؤجَّلٍ آخرُ المسار.
  final List<String> deferred;

  /// «اذهب إليها الآن» — تتقدّم الجميع.
  final String? pinned;

  /// فتراتٌ ضغط المندوبُ «ابدأ المسار» فيها (مفتاحُ الفترة).
  final Set<String> started;

  /// فتراتٌ أقرّ بانتهائها («وصلتُ المطبخ»).
  final Set<String> acked;

  /// كم مرّةً اتّصل بكلّ عميل — يعرضه «لا يردّ على الاتصال».
  final Map<String, int> calls;

  RouteLocal copyWith({
    String? day,
    List<String>? deferred,
    Object? pinned = _keep,
    Set<String>? started,
    Set<String>? acked,
    Map<String, int>? calls,
  }) =>
      RouteLocal(
        day: day ?? this.day,
        deferred: deferred ?? this.deferred,
        pinned: identical(pinned, _keep) ? this.pinned : pinned as String?,
        started: started ?? this.started,
        acked: acked ?? this.acked,
        calls: calls ?? this.calls,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'deferred': deferred,
        'pinned': pinned,
        'started': started.toList(),
        'acked': acked.toList(),
        'calls': calls,
      };

  factory RouteLocal.fromJson(Map<String, dynamic> j) => RouteLocal(
        day: j['day'] as String?,
        deferred: [for (final x in (j['deferred'] as List? ?? const [])) x.toString()],
        pinned: j['pinned'] as String?,
        started: {for (final x in (j['started'] as List? ?? const [])) x.toString()},
        acked: {for (final x in (j['acked'] as List? ?? const [])) x.toString()},
        calls: {
          for (final e in ((j['calls'] as Map?) ?? const {}).entries)
            e.key.toString(): (e.value as num?)?.toInt() ?? 0,
        },
      );
}

const Object _keep = Object();

/// مفتاحُ فترة «من يومٍ سابق»: محطّاتٌ بقيت «في الطريق» من مسارٍ مضى.
///
/// ⚠ لا تُخلط بفترة اليوم التي تحمل الاسمَ نفسَه: محطّةٌ عالقةٌ من الأمس كانت
///   تجعل «صباحًا» اليوم «على الطريق» فيتخطّى المندوبُ تحميلَ أكياسه، وتصير
///   عميلةُ الأمس محطّتَه الحاليّة. ولا يُرسَل لها «أجِّل»: الخادمُ يُعيدها
///   «جاهزة» فتختفي من مساره (لا يعرض الجاهزَ إلّا لليوم) والكيسُ في سيّارته.
const pastGroupKey = '\u0001past';

/// يومٌ (yyyy-MM-dd) ⇒ تاريخ، أو null.
DateTime? parseDayKey(String? s) {
  final p = (s ?? '').split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  return (y == null || m == null || d == null) ? null : DateTime(y, m, d);
}

/// محطّةٌ من مسار يومٍ قبل [today]؟ (بلا تاريخٍ أو بلا «اليوم» ⇒ لا.)
bool isPastStop(Stop s, DateTime? today) {
  final d = s.routeDate;
  if (d == null || today == null) return false;
  return DateTime(d.year, d.month, d.day).isBefore(DateTime(today.year, today.month, today.day));
}

/// الفترةُ التي تنتمي إليها المحطّة على الشاشة.
String groupKeyOf(Stop s, DateTime? today) => isPastStop(s, today) ? pastGroupKey : s.slotKey;

/// ترتيبُ المدخل قبل أقرب جار — **المفتاحُ نفسُه في اللوحة** (`buildRoutes`).
///
/// ⚠ أقربُ جارٍ يتبع ترتيبَ مدخله في ثلاث: التعادل، وذيلِ ما لا موقعَ له،
///   ونقطةِ البدء حين لا موقعَ للفرع. والطرفان كانا يقرآن صفوفَهما بترتيبين
///   مختلفين (اللوحةُ بوقتٍ يتساوى لكلّ اشتراكات اليوم) فاختلفت الورقتان.
///   معرّفُ التوصيلة مفتاحٌ يملكه الطرفان، و`compareTo` هنا = `<` في JS.
int compareRouteInput(Stop a, Stop b) => a.id.compareTo(b.id);

/// مجموعةُ فترةٍ بترتيب ورقة المسار — قبل تطبيق قرارات المندوب.
class StopGroup {
  const StopGroup({
    required this.key,
    required this.slotLabel,
    required this.slotSort,
    required this.slotStart,
    required this.slotEnd,
    required this.start,
    required this.all,
    this.past = false,
  });
  final String key;
  final String? slotLabel;
  final int? slotSort;
  final String? slotStart;
  final String? slotEnd;
  final LatLon? start;
  final List<Stop> all;

  /// محطّاتٌ عالقة من يومٍ سابق ([pastGroupKey]).
  final bool past;
}

/// المحطّاتُ ← فتراتٌ مرتّبة. كلُّ فترةٍ تبدأ من الفرع الغالب على محطّاتها،
/// ويُحسب الترتيبُ على **كلّ** محطّاتها (المفتوحة والمغلقة اليوم) — فلا يتبدّل
/// رقمُ «المحطة ٨» تحت يد المندوب كلّما أغلق واحدة.
/// و[today] يومُ المطعم: ما قبله يُعزل في فترة «من يومٍ سابق».
List<StopGroup> buildGroups(List<Stop> stops, {DateTime? today}) {
  final byKey = <String, List<Stop>>{};
  for (final s in [...stops]..sort(compareRouteInput)) {
    byKey.putIfAbsent(groupKeyOf(s, today), () => []).add(s);
  }
  final groups = <StopGroup>[];
  byKey.forEach((key, list) {
    final past = key == pastGroupKey;
    final branchId = modeOf(list.map((s) => s.branchId));
    LatLon? start;
    if (branchId != null) {
      for (final s in list) {
        if (s.branchId == branchId && hasXY(s.branchPos)) {
          start = s.branchPos;
          break;
        }
      }
    }
    int? sort;
    String? from;
    String? to;
    for (final s in list) {
      if (s.slotSort != null && (sort == null || s.slotSort! < sort)) sort = s.slotSort;
      from ??= s.slotStart;
      to ??= s.slotEnd;
    }
    groups.add(StopGroup(
      key: key,
      slotLabel: key.isEmpty || past ? null : key,
      slotSort: past ? null : sort,
      slotStart: past ? null : from,
      slotEnd: past ? null : to,
      start: start,
      all: orderStops(start, list),
      past: past,
    ));
  });
  groups.sort(compareGroups);
  return groups;
}

/// ترتيبُ الفترات: `slot_sort` تصاعديًّا (الفارغُ آخرًا) ثمّ الاسم، وما لا فترةَ
/// له في الآخر (طلباتُ نقطة البيع)، ثمّ العالقُ من يومٍ سابق: مسارُ اليوم هو ما
/// يفتح عليه التطبيق، والعالقُ ظاهرٌ في رقاقته لا يزاحمه.
int compareGroups(StopGroup a, StopGroup b) {
  if (a.past != b.past) return a.past ? 1 : -1;
  final an = a.key.isEmpty, bn = b.key.isEmpty;
  if (an != bn) return an ? 1 : -1;
  final sa = a.slotSort, sb = b.slotSort;
  if (sa != sb) {
    if (sa == null) return 1;
    if (sb == null) return -1;
    return sa.compareTo(sb);
  }
  return a.key.compareTo(b.key);
}

/// الترتيبُ الفعليّ للمفتوح: ورقةُ المسار، ثمّ المؤجَّلُ إلى الآخر بترتيب تأجيله،
/// ثمّ «اذهب إليها الآن» في الأوّل — ثمّ المحطّةُ الحاليّة أوّلًا: أوّلُ ما هو
/// «في الطريق» ولم يؤجَّل، وإلّا أوّلُ مفتوح.
///
/// ⚠ «في الطريق» يغلب الترتيب لأنّ العميلَ يرى تتبّعَها الآن: لو قدّم التطبيقُ
///   غيرَها لذهب المندوبُ إلى عميلٍ وخريطةُ عميلٍ آخر تقول «مندوبك قادم».
List<Stop> effectiveOpenOrder(List<Stop> sheet, RouteLocal local) {
  final open = [for (final s in sheet) if (s.isOpen) s];
  final deferredIds = local.deferred.toSet();
  final normal = [for (final s in open) if (!deferredIds.contains(s.id)) s];
  final tail = <Stop>[];
  for (final id in local.deferred) {
    for (final s in open) {
      if (s.id == id) tail.add(s);
    }
  }
  var list = [...normal, ...tail];
  final pin = local.pinned;
  if (pin != null) {
    final i = list.indexWhere((s) => s.id == pin);
    if (i > 0) list = [list[i], ...list.sublist(0, i), ...list.sublist(i + 1)];
  }
  final ci = list.indexWhere((s) => s.status == StopStatus.enroute && !deferredIds.contains(s.id));
  if (ci > 0) list = [list[ci], ...list.sublist(0, ci), ...list.sublist(ci + 1)];
  return list;
}

/// بدأ المندوبُ هذا المسار؟ ضغط «ابدأ المسار» على هذا الهاتف، أو أثرُه ظاهرٌ
/// عند الخادم: محطّةٌ «في الطريق»، أو محطّةٌ أغلقها بعد أن حمّل كيسَها.
///
/// ⚠ «ابدأ» محفوظٌ على الهاتف وحده ويُمحى بالخروج: بعد دخولٍ جديدٍ في منتصف
///   المسار كان أوّلُ تسليمٍ يعيده إلى «حمّل أكياسك» فلا يُوجَّه التالي، ولا
///   يظهر ملخّصُ النهاية. فما يقوله الخادمُ يكفي دليلًا.
/// ⚠ والمغلقُ بلا تحميلٍ لا يُعدّ: قد يُغلقه فريقُ المطعم قبل خروج المندوب.
bool groupStarted(String key, Iterable<Stop> all, RouteLocal local) =>
    local.started.contains(key) ||
    all.any((s) => s.status == StopStatus.enroute || (s.isClosed && s.pickedAt != null));

/// المرحلة: «حمّل أكياسك» حتّى يبدأ المسارَ ([groupStarted])، ثمّ «على الطريق»،
/// ثمّ «انتهى». [closed] مغلقُ الفترة — دليلُ بدءٍ بعد دخولٍ جديد.
RoutePhase phaseOf(String key, List<Stop> open, RouteLocal local, {Iterable<Stop> closed = const []}) {
  if (open.isEmpty) return RoutePhase.done;
  if (!groupStarted(key, [...open, ...closed], local)) return RoutePhase.loading;
  return RoutePhase.onRoute;
}

/// فترةٌ كما تعرضها شاشةُ «مساري».
class RouteGroupView {
  const RouteGroupView({
    required this.key,
    required this.slotLabel,
    required this.slotStart,
    required this.slotEnd,
    required this.slotSort,
    required this.phase,
    required this.all,
    required this.open,
    required this.closed,
    required this.current,
    required this.total,
    required this.closedCount,
    required this.loadedCount,
    required this.start,
    this.acked = false,
    this.started = false,
    this.past = false,
  });

  final String key;
  final String? slotLabel;
  final String? slotStart;
  final String? slotEnd;
  final int? slotSort;
  final RoutePhase phase;

  /// كلُّ المحطّات بترتيب ورقة المسار المطبوعة.
  final List<Stop> all;

  /// المفتوحُ بالترتيب الفعليّ، والحاليّةُ أوّلُه.
  final List<Stop> open;
  final List<Stop> closed;
  final Stop? current;
  final int total;
  final int closedCount;
  final int loadedCount;

  /// نقطةُ الانطلاق (الفرعُ الغالب) — null إن لم تُعرف.
  final LatLon? start;

  /// أقرّ المندوبُ بنهايتها («وصلتُ المطبخ»).
  final bool acked;

  /// بدأها ([groupStarted]) — فنهايتُها تُعرض ملخّصًا قبل الفترة التالية.
  final bool started;

  /// محطّاتٌ عالقة من يومٍ سابق ([pastGroupKey]) — لا تحميلَ لها ولا ملخّص.
  final bool past;

  bool get hasSlot => slotLabel != null;
  int get remaining => open.length;

  /// ما تعذّر — أكياسُه تعود إلى المطبخ.
  List<Stop> get failed => [for (final s in closed) if (s.status == StopStatus.failed) s];
  List<Stop> get delivered => [for (final s in closed) if (s.status == StopStatus.delivered) s];
  List<Stop> get notLoaded => [for (final s in open) if (!s.isLoaded) s];
}

/// المحطّاتُ الفعليّة + قراراتُ المندوب ⇒ فتراتُ الشاشة.
/// «اليوم» يومُ قرارات المندوب (`local.day` = يومُ المطعم)؛ والعالقُ من يومٍ
/// سابق يغيب حين يُغلق كلُّه — لا ملخّصَ ولا «وصلتُ المطبخ» لمسارٍ مضى.
List<RouteGroupView> buildRouteGroupViews(List<Stop> stops, RouteLocal local) => [
      for (final g in buildGroups(stops, today: parseDayKey(local.day)))
        if (!g.past || g.all.any((s) => s.isOpen)) groupView(g, local),
    ];

RouteGroupView groupView(StopGroup g, RouteLocal local) {
  final open = effectiveOpenOrder(g.all, local);
  final closed = [for (final s in g.all) if (s.isClosed) s];
  final started = !g.past && groupStarted(g.key, g.all, local);
  return RouteGroupView(
    key: g.key,
    slotLabel: g.slotLabel,
    slotStart: g.slotStart,
    slotEnd: g.slotEnd,
    slotSort: g.slotSort,
    // العالقُ أكياسُه في السيّارة منذ أمس: لا مرحلةَ تحميل.
    phase: g.past ? (open.isEmpty ? RoutePhase.done : RoutePhase.onRoute) : phaseOf(g.key, open, local, closed: closed),
    all: g.all,
    open: open,
    closed: closed,
    current: open.isEmpty ? null : open.first,
    total: g.all.length,
    closedCount: closed.length,
    loadedCount: g.all.where((s) => s.isLoaded).length,
    start: g.start,
    acked: local.acked.contains(g.key),
    started: started,
    past: g.past,
  );
}

// ═══════════════ ④ب عدُّ السجلّ ═══════════════

/// أقصى ما يُعيده `driver_history_v2` (الأحدثُ أوّلًا).
const int historyRowCap = 300;

/// المسلَّمُ منذ [from] في السجلّ. ⚠ السجلُّ مقطوعٌ عند [cap] صفّ: مندوبٌ مشغول
/// يتجاوزها في أيّام، فعدُّ «هذا الشهر» من قائمةٍ مقطوعة رقمٌ مخترَع. فإن امتلأت
/// القائمةُ وأقدمُ صفوفها ما زال داخل النافذة، فالعددُ **حدٌّ أدنى** (`atLeast`).
({int count, bool atLeast}) deliveredSince(
  List<HistoryEntry> list,
  DateTime from,
  DateTime Function(HistoryEntry) dayOf, {
  int cap = historyRowCap,
}) {
  final start = DateTime(from.year, from.month, from.day);
  var n = 0;
  DateTime? oldest;
  for (final e in list) {
    final d = dayOf(e);
    if (oldest == null || d.isBefore(oldest)) oldest = d;
    if (e.delivered && !d.isBefore(start)) n++;
  }
  final cut = list.length >= cap && oldest != null && !oldest.isBefore(start);
  return (count: n, atLeast: cut);
}

// ═══════════════ ⑤ العدد بالعربيّة ═══════════════

/// الأسماءُ المعدودة في الواجهة.
enum ArNoun { stop, delivery, meal, time, action }

const _forms = <ArNoun, List<String>>{
  //            مفرد      مثنّى(رفع)   مثنّى(نصب)    جمع(٣–١٠)
  ArNoun.stop: ['محطة', 'محطتان', 'محطتين', 'محطات'],
  ArNoun.delivery: ['توصيلة', 'توصيلتان', 'توصيلتين', 'توصيلات'],
  ArNoun.meal: ['وجبة', 'وجبتان', 'وجبتين', 'وجبات'],
  ArNoun.time: ['مرّة', 'مرّتان', 'مرّتين', 'مرّات'],
  ArNoun.action: ['عملية', 'عمليتان', 'عمليتين', 'عمليات'],
};

const _en = <ArNoun, List<String>>{
  ArNoun.stop: ['stop', 'stops'],
  ArNoun.delivery: ['delivery', 'deliveries'],
  ArNoun.meal: ['meal', 'meals'],
  ArNoun.time: ['time', 'times'],
  ArNoun.action: ['action', 'actions'],
};

/// «محطة واحدة · محطتان · 3 محطات · 11 محطة» — قاعدةُ العدد العربيّة.
/// [accusative] للمثنّى المنصوب/المجرور: «اتصلت مرّتين»، «بعد محطتين».
/// والأرقامُ غربيّة لتطابق ما على الملصق.
String arCount(int n, ArNoun noun, {bool accusative = false}) {
  final f = _forms[noun]!;
  if (n == 1) return '${f[0]} واحدة';
  if (n == 2) return accusative ? f[2] : f[1];
  final r = n % 100;
  if (r >= 3 && r <= 10) return '$n ${f[3]}';
  return '$n ${f[0]}';
}

/// النظيرُ الإنجليزيّ — «once/twice» للمرّات كما تُقال.
String enCount(int n, ArNoun noun) {
  if (noun == ArNoun.time) {
    if (n == 1) return 'once';
    if (n == 2) return 'twice';
  }
  final f = _en[noun]!;
  return '$n ${n == 1 ? f[0] : f[1]}';
}

String arStops(int n) => arCount(n, ArNoun.stop);
String arDeliveries(int n) => arCount(n, ArNoun.delivery);
String arMeals(int n) => arCount(n, ArNoun.meal);
String arTimes(int n, {bool accusative = false}) => arCount(n, ArNoun.time, accusative: accusative);
