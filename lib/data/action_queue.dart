import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'driver_repository.dart';

/// ساعةُ الطابور — تُستبدل في الاختبار. `PendingAction.undoable` تقرؤها أيضًا،
/// فالشريطُ والطابورُ يتّفقان على اللحظة نفسها.
class QueueClock {
  QueueClock._();
  static DateTime Function() now = DateTime.now;
}

/// فعلٌ ينتظر الإرسال: مهلةُ تراجع، ثمّ إرسال، ثمّ إعادةٌ إن تعثّرت الشبكة.
@immutable
class PendingAction {
  const PendingAction({
    required this.key,
    required this.deliveryId,
    required this.action,
    this.reason,
    required this.commitAt,
    this.attempts = 0,
    this.lastError,
    this.photoRef,
    this.parentKey,
    this.nextTryAt,
  });

  final String key;
  final String deliveryId;

  /// picked | enroute | defer | delivered | delivered_door | failed
  final String action;
  final String? reason;

  /// لا يُرسَل قبلها — وقبلها يُتراجع عنه بلا أثرٍ عند الخادم.
  final DateTime commitAt;
  final int attempts;
  final String? lastError;

  /// مرجعُ الصورة في المخزن (ملفٌّ على الجهاز، أو ذاكرةٌ على الويب).
  final String? photoRef;

  /// فعلٌ تابع (المحطّةُ التالية «في الطريق» بعد التسليم) — لا يُرسَل قبل أصله،
  /// ويسقط معه إن تراجع المندوبُ أو رفضه الخادم.
  final String? parentKey;
  final DateTime? nextTryAt;

  bool get undoable => QueueClock.now().isBefore(commitAt);
  bool get isFollowUp => parentKey != null;
  bool get hasPhoto => photoRef != null;

  PendingAction copyWith({DateTime? commitAt, int? attempts, String? lastError, DateTime? nextTryAt, bool clearNextTry = false}) =>
      PendingAction(
        key: key,
        deliveryId: deliveryId,
        action: action,
        reason: reason,
        commitAt: commitAt ?? this.commitAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
        photoRef: photoRef,
        parentKey: parentKey,
        nextTryAt: clearNextTry ? null : (nextTryAt ?? this.nextTryAt),
      );

  Map<String, dynamic> toJson() => {
        'k': key,
        'd': deliveryId,
        'a': action,
        if (reason != null) 'r': reason,
        'c': commitAt.millisecondsSinceEpoch,
        'n': attempts,
        if (lastError != null) 'e': lastError,
        if (photoRef != null) 'ph': photoRef,
        if (parentKey != null) 'p': parentKey,
        if (nextTryAt != null) 't': nextTryAt!.millisecondsSinceEpoch,
      };

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
        key: j['k'] as String,
        deliveryId: j['d'] as String,
        action: j['a'] as String,
        reason: j['r'] as String?,
        commitAt: DateTime.fromMillisecondsSinceEpoch((j['c'] as num).toInt()),
        attempts: (j['n'] as num?)?.toInt() ?? 0,
        lastError: j['e'] as String?,
        photoRef: j['ph'] as String?,
        parentKey: j['p'] as String?,
        nextTryAt: j['t'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      );
}

/// أين يُحفظ الطابورُ وصورُه. الطابورُ يعيش أطولَ من التطبيق: مندوبٌ ضغط «تم
/// التسليم» في قبوٍ بلا شبكة ثمّ أغلق التطبيق — يجب أن يصل تسليمُه حين يعود.
abstract class QueueStore {
  Future<String?> read();
  Future<void> write(String json);
  Future<String> savePhoto(String key, List<int> bytes);
  Future<List<int>?> loadPhoto(String ref);
  Future<void> deletePhoto(String ref);

  /// صاحبُ الطابور (معرّفُ المندوب) — جلسةٌ ماتت لا تمحو أفعالَه، فتُرسَل إن عاد
  /// هو، وتُمحى إن دخل غيرُه.
  Future<String?> readOwner();
  Future<void> writeOwner(String? driverId);
}

/// في الذاكرة — للاختبار، وللويب حيث لا ملفّات.
class MemoryQueueStore implements QueueStore {
  String? data;
  String? owner;
  final Map<String, List<int>> photos = {};

  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String json) async => data = json;
  @override
  Future<String?> readOwner() async => owner;
  @override
  Future<void> writeOwner(String? driverId) async => owner = driverId;
  @override
  Future<String> savePhoto(String key, List<int> bytes) async {
    photos['mem:$key'] = List.of(bytes);
    return 'mem:$key';
  }

  @override
  Future<List<int>?> loadPhoto(String ref) async => photos[ref];
  @override
  Future<void> deletePhoto(String ref) async => photos.remove(ref);
}

/// shared_preferences للطابور، ومجلّدُ المستندات للصور (لا تُحشر ميغاباتٌ في
/// التفضيلات). وعلى الويب — أو إن غاب المجلّد — تبقى الصورُ في الذاكرة.
class PrefsQueueStore implements QueueStore {
  static const _key = 'action_queue_v1';
  static const _ownerKey = 'action_queue_owner';
  final MemoryQueueStore _mem = MemoryQueueStore();

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String json) async => (await SharedPreferences.getInstance()).setString(_key, json);

  @override
  Future<String?> readOwner() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_ownerKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeOwner(String? driverId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      driverId == null ? await sp.remove(_ownerKey) : await sp.setString(_ownerKey, driverId);
    } catch (_) {}
  }

  /// مرجعُ الصورة = اسمُ ملفّها وحدَه، ويُحلّ مجلّدُ المستندات عند كلّ قراءة.
  ///
  /// ⚠ لا المسارُ المطلق: iOS يغيّر مسارَ حاوية التطبيق مع كلّ تحديث (بناءُ
  ///   TestFlight جديد)، فتسليمٌ صُوّر بلا شبكةٍ ثمّ حُدّث التطبيقُ قبل إرساله
  ///   كان يُقرأ «ضاعت صورة التسليم» فتُفتح المحطّةُ بعد أن غادر المندوب.
  static Future<File> _file(String ref) async {
    // مراجعُ قديمة كانت مساراتٍ مطلقة — يُؤخذ اسمُها ويُبحث في المجلّد الحاليّ.
    final name = ref.split(RegExp(r'[\\/]')).last;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/proof_queue/$name');
  }

  @override
  Future<String> savePhoto(String key, List<int> bytes) async {
    if (kIsWeb) return _mem.savePhoto(key, bytes);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/proof_queue');
      if (!await folder.exists()) await folder.create(recursive: true);
      final name = '$key.jpg';
      await File('${folder.path}/$name').writeAsBytes(bytes, flush: true);
      return name;
    } catch (_) {
      return _mem.savePhoto(key, bytes);
    }
  }

  @override
  Future<List<int>?> loadPhoto(String ref) async {
    if (ref.startsWith('mem:')) return _mem.loadPhoto(ref);
    if (kIsWeb) return null;
    try {
      final f = await _file(ref);
      return await f.exists() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deletePhoto(String ref) async {
    if (ref.startsWith('mem:') || kIsWeb) return _mem.deletePhoto(ref);
    try {
      final f = await _file(ref);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

typedef ActionRunner = Future<void> Function(PendingAction action, List<int>? photo);

/// طابورُ الأفعال: كلُّ ضغطةٍ تُسجَّل هنا أوّلًا ثمّ تُرسَل.
///
/// القواعد:
///   • مهلةُ تراجع (`commitAt`) قبل الإرسال — «تم التسليم» بالخطأ يُلغى بلا أثر.
///   • FIFO لكلّ توصيلة: «حُمّل» ثمّ «في الطريق» ثمّ «سُلّم» بترتيبها، وإلّا رفض
///     الخادمُ تعذّرًا وصل قبل التحميل أو عكس تسليمًا.
///   • التابعُ ينتظر أصله ويسقط معه.
///   • العابرُ يُعاد بتباعدٍ (2، 4، 8 … حتّى 60 ث)، والدائمُ يُسقَط ويُقال سببُه،
///     والجلسةُ الميّتة تُوقف الطابورَ كلَّه (الخروجُ يمسحه).
class ActionQueue {
  ActionQueue({
    required this.store,
    required this.run,
    this.onChange,
    this.onCommitted,
    this.onPermanent,
    this.onTransient,
    this.onSession,
    this.autoSchedule = true,
  });

  final QueueStore store;
  final ActionRunner run;
  final void Function()? onChange;
  final void Function(PendingAction a)? onCommitted;
  final void Function(PendingAction a, String message)? onPermanent;
  final void Function(PendingAction a, String message)? onTransient;
  final void Function(DriverActionError e)? onSession;

  /// false في اختبار الطابور: لا مؤقّتات، والاختبارُ ينادي [pump] بنفسه.
  final bool autoSchedule;

  final List<PendingAction> _items = [];
  String? _inFlight;
  Future<void>? _running;
  bool _again = false;
  bool _halted = false;
  bool _disposed = false;
  Timer? _timer;
  int _seq = 0;
  Future<void> _writing = Future.value();

  List<PendingAction> get items => List.unmodifiable(_items);
  String? get inFlight => _inFlight;
  bool get isEmpty => _items.isEmpty;

  static Duration backoff(int attempts) {
    final s = 1 << attempts.clamp(1, 6); // 2 … 64
    return Duration(seconds: s > 60 ? 60 : s);
  }

  // ---------- الحفظ ----------

  Future<void> load() async {
    try {
      final raw = await store.read();
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      _items
        ..clear()
        ..addAll([for (final j in list) PendingAction.fromJson(Map<String, dynamic>.from(j as Map))]);
    } catch (_) {
      // طابورٌ تالف لا يُسقط التطبيق — يُبدأ من جديد.
      _items.clear();
    }
    _changed();
  }

  Future<void> _persist() {
    final snapshot = jsonEncode([for (final a in _items) a.toJson()]);
    // الكتاباتُ متتابعة: كتابةٌ أقدم تنتهي بعد أحدث فتمحوها — فتعود أفعالٌ أُرسلت.
    return _writing = _writing.then((_) => store.write(snapshot)).catchError((_) {});
  }

  void _changed() {
    onChange?.call();
    _schedule();
  }

  // ---------- الإضافة والتراجع ----------

  Future<PendingAction> enqueue(
    String deliveryId,
    String action, {
    String? reason,
    List<int>? photo,
    Duration grace = Duration.zero,
    String? parentKey,
    DateTime? commitAt,
  }) async {
    final key = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_seq++}';
    // الصورةُ تُحفظ قبل أن يدخل الفعلُ الطابور: فعلٌ محفوظٌ بلا صورته يُرسَل تسليمًا
    // بلا إثبات أو يُرفض بعد ساعة.
    final ref = photo == null ? null : await store.savePhoto(key, photo);
    final a = PendingAction(
      key: key,
      deliveryId: deliveryId,
      action: action,
      reason: reason,
      commitAt: commitAt ?? QueueClock.now().add(grace),
      photoRef: ref,
      parentKey: parentKey,
    );
    _items.add(a);
    _halted = false;
    await _persist();
    _changed();
    if (autoSchedule && !a.commitAt.isAfter(QueueClock.now())) unawaited(pump());
    return a;
  }

  /// يتراجع عن فعلٍ ما زال في مهلته — ومعه كلُّ توابعه. false إن فات الأوان.
  bool undo(String key) {
    final i = _items.indexWhere((a) => a.key == key);
    if (i < 0 || _inFlight == key) return false;
    if (!QueueClock.now().isBefore(_items[i].commitAt)) return false;
    _dropChain(key);
    unawaited(_persist());
    _changed();
    return true;
  }

  /// يُسقط فعلًا وكلَّ من يتبعه (بأيّ عمق) ويمحو صورَهم.
  List<PendingAction> _dropChain(String key) {
    final dropped = <PendingAction>[];
    final keys = {key};
    var grew = true;
    while (grew) {
      grew = false;
      for (final a in _items) {
        if (a.parentKey != null && keys.contains(a.parentKey) && keys.add(a.key)) grew = true;
      }
    }
    _items.removeWhere((a) {
      if (!keys.contains(a.key)) return false;
      dropped.add(a);
      return true;
    });
    for (final a in dropped) {
      if (a.photoRef != null) unawaited(store.deletePhoto(a.photoRef!));
    }
    return dropped;
  }

  /// يُفرغ الطابورَ (عند الخروج): أفعالُ جلسةٍ انتهت لا تُرسَل برمز غيرها.
  Future<void> clear() async {
    for (final a in _items) {
      if (a.photoRef != null) await store.deletePhoto(a.photoRef!);
    }
    _items.clear();
    _halted = false;
    await _persist();
    _changed();
  }

  /// يُعيد المحاولة الآن (عودةُ التطبيق للمقدّمة، أو «أعد المحاولة»).
  void kick() {
    _halted = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].nextTryAt != null) _items[i] = _items[i].copyWith(clearNextTry: true);
    }
    unawaited(pump());
  }

  /// يُنهي المهلَ كلَّها ويرسل ما أمكن الآن، وينتظر — قبل الخروج.
  ///
  /// ⚠ ويُسقط انتظارَ الإعادة أيضًا (كـ[kick]): فعلٌ تعثّر مرّةً ينتظر حتّى دقيقة،
  ///   و`_nextDue` يتخطّاه — فكان الخروجُ بعد عودة الشبكة بثوانٍ لا يرسله أبدًا.
  Future<void> flush() async {
    final now = QueueClock.now();
    _halted = false;
    for (var i = 0; i < _items.length; i++) {
      final a = _items[i];
      if (a.commitAt.isAfter(now) || a.nextTryAt != null) {
        _items[i] = a.copyWith(commitAt: a.commitAt.isAfter(now) ? now : null, clearNextTry: true);
      }
    }
    _changed();
    await pump();
  }

  /// يوقف الإرسالَ ولا يمحو شيئًا (جلسةٌ ماتت): [kick] يستأنفه بعد الدخول.
  void pause() {
    _halted = true;
    _timer?.cancel();
    _timer = null;
  }

  // ---------- الإرسال ----------

  /// أوّلُ فعلٍ حان وقتُه: لا ينتظر أصلًا، ولا فعلًا أقدم لتوصيلته.
  PendingAction? _nextDue() {
    final now = QueueClock.now();
    final keys = {for (final a in _items) a.key};
    final busy = <String>{};
    for (final a in _items) {
      final blocked = busy.contains(a.deliveryId) || (a.parentKey != null && keys.contains(a.parentKey));
      busy.add(a.deliveryId);
      if (blocked) continue;
      if (a.commitAt.isAfter(now)) continue;
      if (a.nextTryAt != null && a.nextTryAt!.isAfter(now)) continue;
      return a;
    }
    return null;
  }

  /// يرسل كلَّ ما حان. وإن كان يعمل فعلًا يُعيد مستقبلَ الجولة الجارية — فمن
  /// ينتظر `pump()` ينتظر انتهاءَ الإرسال لا مجرّدَ تسجيل الطلب.
  Future<void> pump() {
    if (_disposed) return Future.value();
    final current = _running;
    if (current != null) {
      _again = true;
      return current;
    }
    final done = Completer<void>();
    _running = done.future;
    () async {
      try {
        do {
          _again = false;
          while (!_halted && !_disposed) {
            final a = _nextDue();
            if (a == null) break;
            await _runOne(a);
          }
        } while (_again && !_halted && !_disposed);
      } finally {
        _running = null;
        _schedule();
        done.complete();
      }
    }();
    return done.future;
  }

  Future<void> _runOne(PendingAction a) async {
    _inFlight = a.key;
    onChange?.call();
    try {
      List<int>? photo;
      if (a.photoRef != null) {
        photo = await store.loadPhoto(a.photoRef!);
        if (photo == null) {
          throw const DriverActionError.permanent('ضاعت صورة التسليم — صوّر من جديد');
        }
      }
      await run(a, photo);
      // يُبلَّغ بالالتزام **قبل** أيّ انتظار: بين خروجه من الطابور ووصوله إلى
      // «ما التُزم ولم يُقرأ بعد» لا تُرسم الشاشة — وإلّا رمشت المحطّةُ مفتوحةً.
      _items.removeWhere((x) => x.key == a.key);
      _inFlight = null;
      onCommitted?.call(a);
      if (a.photoRef != null) unawaited(store.deletePhoto(a.photoRef!));
      await _persist();
      _changed();
    } catch (e) {
      _inFlight = null;
      final err = e is DriverActionError ? e : DriverActionError.transient(e.toString());
      if (err.isSession) {
        _halted = true;
        onChange?.call();
        onSession?.call(err);
      } else if (err.isPermanent) {
        _dropChain(a.key);
        await _persist();
        onPermanent?.call(a, err.message);
        _changed();
      } else {
        final i = _items.indexWhere((x) => x.key == a.key);
        if (i >= 0) {
          final n = a.attempts + 1;
          _items[i] = a.copyWith(attempts: n, lastError: err.message, nextTryAt: QueueClock.now().add(backoff(n)));
        }
        await _persist();
        onTransient?.call(a, err.message);
        _changed();
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!autoSchedule || _disposed || _halted || _running != null || _items.isEmpty) return;
    final now = QueueClock.now();
    DateTime? soonest;
    // ⚠ المحجوبُ خلف غيره لا يُحسب: موعدُه موعدُ حاجبه. ولو حُسب لصار مؤقّتًا
    //   صفريًّا يدور بلا توقّف ما دام الحاجبُ ينتظر إعادته بعد دقيقة.
    final keys = {for (final a in _items) a.key};
    final busy = <String>{};
    for (final a in _items) {
      final blocked = busy.contains(a.deliveryId) || (a.parentKey != null && keys.contains(a.parentKey));
      busy.add(a.deliveryId);
      if (blocked) continue;
      var due = a.commitAt;
      if (a.nextTryAt != null && a.nextTryAt!.isAfter(due)) due = a.nextTryAt!;
      if (soonest == null || due.isBefore(soonest)) soonest = due;
    }
    if (soonest == null) return;
    var wait = soonest.difference(now);
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait + const Duration(milliseconds: 5), () => unawaited(pump()));
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
