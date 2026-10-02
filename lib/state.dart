/// حالةُ تطبيق المندوب — «مساري اليوم».
///
/// كلُّ ضغطةٍ تمرّ بطابور الأفعال (`ActionQueue`): أثرُها يظهر فورًا على الشاشة
/// (طبقةٌ فوق ما قاله الخادم)، ثمّ يُرسَل بعد مهلة التراجع، ويُعاد إن انقطعت
/// الشبكة. فالمندوبُ في قبوٍ بلا إشارة يُكمل مسارَه، ولا يضيع تسليمٌ ضغطه.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/env.dart';
import 'data/action_queue.dart';
import 'data/driver_repository.dart';
import 'data/location_broadcaster.dart';
import 'data/mock_driver_repository.dart';
import 'data/notifications_service.dart';
import 'data/push_service.dart';
import 'data/route_local_store.dart';
import 'data/supabase_driver_repository.dart';
import 'l10n.dart' show localeProvider;
import 'models.dart';
import 'route_logic.dart';

export 'data/action_queue.dart' show PendingAction;
export 'data/driver_repository.dart' show DriverActionError, DriverErrorKind, DriverRepository;
export 'models.dart';
export 'route_logic.dart';

enum AuthStatus { restoring, signedOut, signedIn }

enum ScanResult { loaded, alreadyLoaded, unknown, invalid }

/// رسالةٌ عابرة للشاشة (SnackBar) — رفضُ الخادم يُقال بنصّه.
class UiEvent {
  const UiEvent(this.message, {this.error = false});
  final String message;
  final bool error;
}

/// المهلُ والإيقاعات — تُستبدل في الاختبار بأقصر منها.
class QueueTiming {
  const QueueTiming({
    this.loadGrace = const Duration(seconds: 4),
    this.closeGrace = const Duration(seconds: 10),
    this.pollEvery = const Duration(seconds: 20),
    this.chatPollEvery = const Duration(seconds: 8),
  });

  /// «حُمّل» — قصيرة: خطأٌ في لمس مربّعٍ مجاور يُلحظ فورًا.
  final Duration loadGrace;

  /// «سُلّم/تعذّر/عند الباب» — أطول: يُغلق محطّةً ويُرسل للعميل.
  final Duration closeGrace;
  final Duration pollEvery;
  final Duration chatPollEvery;
}

const Object _keep = Object();

class DriverState {
  const DriverState({
    this.auth = AuthStatus.restoring,
    this.profile,
    this.stops = const [],
    this.history = const [],
    this.historyLoaded = false,
    this.messages = const {},
    this.syncing = false,
    this.offline = false,
    this.lastSync,
    this.loadError,
    this.pending = const [],
    this.local = const RouteLocal(),
    this.myPos,
    this.broadcasting = false,
    this.demo = false,
  });

  final AuthStatus auth;
  final DriverProfile? profile;

  /// المحطّاتُ الفعليّة = الخادم + أثرُ الأفعال المعلّقة (`Stop.pending` معلَّم).
  final List<Stop> stops;
  final List<HistoryEntry> history;
  final bool historyLoaded;
  final Map<String, List<ChatMessage>> messages;
  final bool syncing;
  final bool offline;
  final DateTime? lastSync;
  final String? loadError;

  /// أفعالُ المندوب المعلّقة (بلا التوابع الآليّة) — آخرُها القابلُ للتراجع هو شريطُ «تراجع».
  final List<PendingAction> pending;
  final RouteLocal local;
  final LatLon? myPos;

  /// هل يُبثّ الموقعُ فعلًا (لا نيّةً)؟
  final bool broadcasting;
  final bool demo;

  bool get signedIn => auth == AuthStatus.signedIn;

  Stop? stopById(String id) {
    for (final s in stops) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// آخرُ فعلٍ ما زال يُتراجع عنه — أو null.
  PendingAction? get latestUndoable {
    for (final a in pending.reversed) {
      if (a.undoable) return a;
    }
    return null;
  }

  DriverState copyWith({
    AuthStatus? auth,
    Object? profile = _keep,
    List<Stop>? stops,
    List<HistoryEntry>? history,
    bool? historyLoaded,
    Map<String, List<ChatMessage>>? messages,
    bool? syncing,
    bool? offline,
    Object? lastSync = _keep,
    Object? loadError = _keep,
    List<PendingAction>? pending,
    RouteLocal? local,
    Object? myPos = _keep,
    bool? broadcasting,
    bool? demo,
  }) =>
      DriverState(
        auth: auth ?? this.auth,
        profile: identical(profile, _keep) ? this.profile : profile as DriverProfile?,
        stops: stops ?? this.stops,
        history: history ?? this.history,
        historyLoaded: historyLoaded ?? this.historyLoaded,
        messages: messages ?? this.messages,
        syncing: syncing ?? this.syncing,
        offline: offline ?? this.offline,
        lastSync: identical(lastSync, _keep) ? this.lastSync : lastSync as DateTime?,
        loadError: identical(loadError, _keep) ? this.loadError : loadError as String?,
        pending: pending ?? this.pending,
        local: local ?? this.local,
        myPos: identical(myPos, _keep) ? this.myPos : myPos as LatLon?,
        broadcasting: broadcasting ?? this.broadcasting,
        demo: demo ?? this.demo,
      );
}

// ═══════════════ المزوّدات ═══════════════

/// الخادمُ الحقيقيّ إن عُرفت إعداداتُه، وإلّا الخادمُ الوهميّ — والاختبارُ يستبدله.
final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  final repo = Env.hasSupabase ? SupabaseDriverRepository() : MockDriverRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final queueStoreProvider = Provider<QueueStore>((ref) => PrefsQueueStore());
final routeLocalStoreProvider = Provider<RouteLocalStore>((ref) => RouteLocalStore());
final queueTimingProvider = Provider<QueueTiming>((ref) => const QueueTiming());

final driverProvider = NotifierProvider<DriverNotifier, DriverState>(DriverNotifier.new);

final routeGroupsProvider = Provider<List<RouteGroupView>>((ref) {
  final s = ref.watch(driverProvider);
  return buildRouteGroupViews(s.stops, s.local);
});

final selectedGroupKeyProvider = StateProvider<String?>((ref) => null);

/// الفترةُ المعروضة: ما اختاره المندوب، وإلّا أوّلُ فترةٍ فيها مفتوح، وإلّا الأخيرة.
///
/// ⚠ وفترةٌ بدأها وانتهت ولم يُقرّ بها («وصلتُ المطبخ») تبقى معروضةً قبل التالية:
///   وإلّا قفزت الشاشةُ إلى مسار المساء لحظةَ آخر تسليم، ولم يرَ المندوبُ أبدًا
///   ملخّصَه ولا قائمةَ الأكياس التي يُعيدها إلى المطبخ.
final currentGroupProvider = Provider<RouteGroupView?>((ref) {
  final groups = ref.watch(routeGroupsProvider);
  if (groups.isEmpty) return null;
  final sel = ref.watch(selectedGroupKeyProvider);
  if (sel != null) {
    for (final g in groups) {
      if (g.key == sel) return g;
    }
  }
  final local = ref.watch(driverProvider.select((s) => s.local));
  for (final g in groups) {
    if (g.phase == RoutePhase.done && !g.acked && local.started.contains(g.key)) return g;
    if (g.open.isNotEmpty) return g;
  }
  return groups.last;
});

// ═══════════════ المُشغِّل ═══════════════

class _Committed {
  _Committed(this.action, this.at);
  final PendingAction action;
  final DateTime at;
}

class _Lifecycle with WidgetsBindingObserver {
  _Lifecycle(this.onResume);
  final VoidCallback onResume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) onResume();
  }
}

class DriverNotifier extends Notifier<DriverState> {
  late DriverRepository _repo;
  late ActionQueue _queue;
  late RouteLocalStore _localStore;
  late QueueTiming _timing;
  final _events = StreamController<UiEvent>.broadcast();

  List<Stop> _server = const [];

  /// أفعالٌ قبلها الخادمُ ولم يُقرأ مسارٌ بعدها — تبقى طبقةً كي لا ترمش المحطّة
  /// مفتوحةً بين القبول والقراءة.
  final List<_Committed> _recent = [];

  /// ترتيبُ إغلاق المحطّات في العرض التجريبيّ — منه «موقعي» المحاكى.
  final List<String> _demoTrail = [];

  Timer? _poll;
  Timer? _chatPoll;
  Timer? _refreshSoon;
  StreamSubscription<IncomingMessage>? _msgSub;
  LocationBroadcaster? _broadcaster;
  _Lifecycle? _lifecycle;
  String? _openChat;
  Stop? _lastScanned;
  String? _profileDay;
  bool _refreshing = false;
  bool _refreshAgain = false;
  bool _signingOut = false;
  bool _broadcastWanted = false;
  bool _disposed = false;

  Stream<UiEvent> get events => _events.stream;
  Stop? get lastScannedStop => _lastScanned;

  @override
  DriverState build() {
    _repo = ref.read(driverRepositoryProvider);
    _localStore = ref.read(routeLocalStoreProvider);
    _timing = ref.read(queueTimingProvider);
    _queue = ActionQueue(
      store: ref.read(queueStoreProvider),
      run: _runAction,
      onChange: _recompute,
      onCommitted: _onCommitted,
      onPermanent: _onPermanent,
      onTransient: _onTransient,
      onSession: (_) => _sessionDied(),
    );
    ref.onDispose(_dispose);
    scheduleMicrotask(_restore);
    return DriverState(demo: _repo.isDemo);
  }

  void _dispose() {
    _disposed = true;
    _poll?.cancel();
    _chatPoll?.cancel();
    _refreshSoon?.cancel();
    _msgSub?.cancel();
    _queue.dispose();
    unawaited(_broadcaster?.stop());
    if (_lifecycle != null) {
      try {
        WidgetsBinding.instance.removeObserver(_lifecycle!);
      } catch (_) {}
    }
    _events.close();
  }

  void _emit(String message, {bool error = false}) {
    if (!_events.isClosed) _events.add(UiEvent(message, error: error));
  }

  // ---------- الدخول ----------

  Future<void> _restore() async {
    await _queue.load();
    var ok = false;
    try {
      ok = await _repo.restoreSession();
    } catch (_) {}
    if (_disposed) return;
    if (!ok) {
      state = state.copyWith(auth: AuthStatus.signedOut);
      return;
    }
    state = state.copyWith(auth: AuthStatus.signedIn, profile: _profileFromIdentity());
    await _afterSignIn();
  }

  /// ملفٌّ مؤقّتٌ من هويّة الدخول حتّى يصل `driver_profile` — الاسمُ والجوالُ
  /// معروفان، وإعداداتُ المطعم تُفترض الأحوط (الصورةُ إلزاميّة) حتّى تُقرأ.
  DriverProfile? _profileFromIdentity() {
    final id = _repo.identity;
    if (id == null) return null;
    return DriverProfile(name: id.name, phone: id.phone, orgName: id.orgName);
  }

  /// يرسل رمز التحقّق؛ يعيد اسم المطعم. يرمي `Exception(رسالة)`.
  Future<String> sendOtp(String orgCode, String phone) => _repo.sendOtp(orgCode, phone);

  Future<void> verifyOtp(String orgCode, String phone, String otp) async {
    await _repo.verifyOtp(orgCode, phone, otp);
    state = state.copyWith(auth: AuthStatus.signedIn, profile: _profileFromIdentity());
    await _afterSignIn();
  }

  Future<void> _afterSignIn() async {
    _poll?.cancel();
    _poll = Timer.periodic(_timing.pollEvery, (_) => unawaited(refresh()));
    await _msgSub?.cancel();
    _msgSub = _repo.incomingMessages.listen((m) => unawaited(_onIncoming(m)));
    _observeLifecycle();
    await _loadProfile();
    await refresh();
    unawaited(_queue.pump());
    if (!_repo.isDemo) unawaited(_registerPush());
  }

  Future<void> _registerPush() async {
    try {
      await NotificationsService.instance.init();
    } catch (_) {}
    try {
      // تفضيلُ المندوب يُقرأ قبل التسجيل: من أطفأ الإشعارات لا يُعاد تسجيلُه بكلّ دخول.
      final token = _repo.sessionToken;
      if (token != null && await PushService.isEnabled()) {
        unawaited(PushService.instance.registerToken(token));
      }
    } catch (_) {}
  }

  void _observeLifecycle() {
    if (_lifecycle != null) return;
    try {
      _lifecycle = _Lifecycle(_onResume);
      WidgetsBinding.instance.addObserver(_lifecycle!);
    } catch (_) {
      _lifecycle = null;
    }
  }

  void _onResume() {
    if (!state.signedIn) return;
    unawaited(refresh());
    _queue.kick();
    // الإذنُ قد يُمنح من الإعدادات أثناء الغياب — يُحاوَل البثُّ من جديد.
    if (_broadcastWanted && !(_broadcaster?.active ?? false)) unawaited(_syncBroadcast(true));
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _repo.profile();
      if (_disposed || !state.signedIn) return;
      state = state.copyWith(profile: p);
    } on DriverActionError catch (e) {
      if (e.isSession) return _sessionDied();
    } catch (_) {}
    final day = dayKey(state.profile?.orgToday ?? DateTime.now());
    _profileDay = dayKey(DateTime.now());
    if (state.local.day != day) {
      final l = await _localStore.load(day);
      if (!_disposed) state = state.copyWith(local: l);
    }
  }

  Future<bool> setName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return false;
    try {
      await _repo.setName(n);
      final p = state.profile;
      if (p != null) state = state.copyWith(profile: p.copyWith(name: n));
      return true;
    } on DriverActionError catch (e) {
      if (e.isSession) await _sessionDied();
      return false;
    } catch (_) {
      return false;
    }
  }

  /// خروجٌ بطلب المندوب: يُرسَل ما في الطابور أوّلًا — تسليمٌ ضغطه قبل ثوانٍ لا
  /// يضيع لأنّه خرج داخل مهلة التراجع.
  Future<void> logout() async {
    try {
      await _queue.flush().timeout(const Duration(seconds: 8));
    } catch (_) {}
    await _signOutLocal();
  }

  Future<void> _sessionDied() async {
    if (_signingOut || !state.signedIn) return;
    _emit('انتهت جلستك — سجّل الدخول من جديد', error: true);
    await _signOutLocal();
  }

  Future<void> _signOutLocal() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      _poll?.cancel();
      _chatPoll?.cancel();
      _refreshSoon?.cancel();
      await _msgSub?.cancel();
      _msgSub = null;
      // البثُّ يتوقّف مع الجلسة: رمزٌ أُبطل لا يبقى يبثّ موقعَ صاحبه.
      _broadcastWanted = false;
      await _broadcaster?.stop();
      _broadcaster = null;
      await _queue.clear();
      await _localStore.clear();
      try {
        await _repo.signOut();
      } catch (_) {}
      _server = const [];
      _recent.clear();
      _demoTrail.clear();
      _openChat = null;
      if (!_disposed) state = DriverState(auth: AuthStatus.signedOut, demo: _repo.isDemo);
    } finally {
      _signingOut = false;
    }
  }

  // ---------- المزامنة ----------

  Future<void> refresh() async {
    if (_disposed || !state.signedIn) return;
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    state = state.copyWith(syncing: true);
    try {
      do {
        _refreshAgain = false;
        // يومُ المطعم تغيّر (منتصف الليل والتطبيقُ مفتوح)؟ يُقرأ الملفُّ من جديد.
        if (_profileDay != dayKey(DateTime.now())) await _loadProfile();
        final started = DateTime.now();
        final stops = await _repo.route();
        if (_disposed || !state.signedIn) return;
        _server = stops;
        _recent.removeWhere((c) => c.at.isBefore(started));
        state = state.copyWith(offline: false, lastSync: DateTime.now(), loadError: null);
        _cleanLocal();
      } while (_refreshAgain);
    } on DriverActionError catch (e) {
      if (e.isSession) {
        _refreshing = false;
        return _sessionDied();
      }
      if (!_disposed) {
        state = e.isTransient ? state.copyWith(offline: true) : state.copyWith(loadError: e.message);
      }
    } catch (_) {
      if (!_disposed) state = state.copyWith(offline: true);
    } finally {
      _refreshing = false;
      if (!_disposed && state.signedIn) {
        state = state.copyWith(syncing: false);
        _recompute();
      }
    }
  }

  void _scheduleRefresh() {
    _refreshSoon?.cancel();
    _refreshSoon = Timer(const Duration(milliseconds: 300), () => unawaited(refresh()));
  }

  /// قراراتٌ عن محطّاتٍ أغلقها الخادم لا معنى لها — تُحذف كي لا تكبر.
  void _cleanLocal() {
    final closed = {for (final s in _server) if (s.isClosed) s.id};
    final l = state.local;
    if (!l.deferred.any(closed.contains) && !(l.pinned != null && closed.contains(l.pinned))) return;
    _setLocal(l.copyWith(
      deferred: [for (final id in l.deferred) if (!closed.contains(id)) id],
      pinned: l.pinned != null && closed.contains(l.pinned) ? null : l.pinned,
    ));
  }

  void _setLocal(RouteLocal l) {
    state = state.copyWith(local: l);
    unawaited(_localStore.save(l));
  }

  /// يعيد بناءَ المحطّات الفعليّة من الخادم + المُلتزَم حديثًا + المعلَّق.
  void _recompute() {
    if (_disposed) return;
    final actions = <StopAction>[
      for (final c in _recent) (deliveryId: c.action.deliveryId, action: c.action.action, reason: c.action.reason),
      for (final a in _queue.items) (deliveryId: a.deliveryId, action: a.action, reason: a.reason),
    ];
    final eff = applyActions(_server, actions);
    var next = state.copyWith(
      stops: eff,
      pending: [for (final a in _queue.items) if (!a.isFollowUp) a],
    );
    if (_repo.isDemo) next = next.copyWith(myPos: _demoPos(eff));
    state = next;
    if (!state.signedIn) return;
    _repo.syncMessageChannels({for (final s in eff) if (s.isOpen) s.id});
    final wanted = !_repo.isDemo && eff.any((s) => s.status == StopStatus.enroute);
    if (wanted != _broadcastWanted) {
      _broadcastWanted = wanted;
      unawaited(_syncBroadcast(wanted));
    }
  }

  /// العرضُ التجريبيّ: «أنا» عند آخر محطّةٍ أغلقتُها، وإلّا عند الفرع.
  LatLon? _demoPos(List<Stop> eff) {
    final byId = {for (final s in eff) s.id: s};
    for (final id in _demoTrail.reversed) {
      final s = byId[id];
      if (s != null && s.isClosed && hasXY(s.pos)) return s.pos;
    }
    for (final s in eff) {
      if (hasXY(s.branchPos)) return s.branchPos;
    }
    return null;
  }

  /// البثُّ مربوطٌ بوجود محطّةٍ «في الطريق» لا بشاشةٍ مفتوحة، ويُطفأ صراحةً عند
  /// خلوّها: بثٌّ بعد آخر تسليمٍ يستنزف البطّاريّة فيمنع المناديبُ الإذنَ أصلًا.
  /// ⚠ ويُطلب عند التحوّل إلى «مطلوب» فقط — لا مع كلّ إعادة بناء، وإلّا تكرّر
  ///   سؤالُ الإذن على أندرويد حتّى يُرفض نهائيًّا.
  Future<void> _syncBroadcast(bool wanted) async {
    if (wanted) {
      _broadcaster ??= LocationBroadcaster(_repo, onPosition: (lat, lng) {
        if (!_disposed) state = state.copyWith(myPos: LatLon(lat, lng));
      });
      if (!_broadcaster!.active) {
        try {
          await _broadcaster!.start();
        } catch (_) {}
      }
    } else if (_broadcaster?.active ?? false) {
      await _broadcaster!.stop();
    }
    final on = _broadcaster?.active ?? false;
    if (!_disposed && on != state.broadcasting) state = state.copyWith(broadcasting: on);
  }

  // ---------- الطابور ----------

  Future<void> _runAction(PendingAction a, List<int>? photo) async {
    final closing = a.action == 'delivered' || a.action == 'delivered_door';
    if (closing && photo != null) {
      await _repo.uploadProof(a.deliveryId, photo, door: a.action == 'delivered_door');
    } else {
      await _repo.setStatus(a.deliveryId, a.action, reason: a.reason);
    }
  }

  void _onCommitted(PendingAction a) {
    _recent.add(_Committed(a, DateTime.now()));
    if (state.offline) state = state.copyWith(offline: false);
    _scheduleRefresh();
    if (state.historyLoaded && const {'delivered', 'delivered_door', 'failed'}.contains(a.action)) {
      unawaited(loadHistory());
    }
  }

  void _onPermanent(PendingAction a, String message) {
    _emit(message, error: true);
    _scheduleRefresh();
  }

  void _onTransient(PendingAction a, String message) {
    if (!state.offline) state = state.copyWith(offline: true);
  }

  // ---------- الأفعال ----------

  List<RouteGroupView> get _groups => buildRouteGroupViews(state.stops, state.local);

  RouteGroupView? _group(String key) {
    for (final g in _groups) {
      if (g.key == key) return g;
    }
    return null;
  }

  /// يوجّه المحطّةَ الحاليّة «في الطريق» إن كان كيسُها معه.
  ///
  /// ⚠ كيسٌ لم يُحمَّل لا يُرسَل «في الطريق»: الخادمُ يعدّه محمَّلًا عندها،
  ///   والعميلُ يرى مندوبَه قادمًا وكيسُه ما زال في المطبخ. تبقى حاليّةً بتحذير
  ///   «هذا الكيس لم يُحمَّل — هل هو معك؟» حتّى يقول «نعم، معي».
  Future<void> _advance(String key, {PendingAction? parent}) async {
    final g = _group(key);
    final next = g?.current;
    if (g == null || g.phase != RoutePhase.onRoute || next == null) return;
    if (next.status == StopStatus.enroute || !next.isLoaded) return;
    await _queue.enqueue(next.id, 'enroute', parentKey: parent?.key, commitAt: parent?.commitAt);
  }

  Future<void> markLoaded(String stopId) async {
    final s = state.stopById(stopId);
    if (s == null || s.isClosed || s.isLoaded) return;
    final wasCurrent = _group(s.slotKey)?.current?.id == stopId;
    final a = await _queue.enqueue(stopId, 'picked', grace: _timing.loadGrace);
    // «نعم، معي» على المحطّة الحاليّة يجعلها «في الطريق» — ويُلغى معها إن تراجع.
    if (wasCurrent) await _advance(s.slotKey, parent: a);
  }

  Future<ScanResult> markLoadedByScan(String raw) async {
    final id = parseBagQr(raw);
    if (id == null) {
      _lastScanned = null;
      return ScanResult.invalid;
    }
    Stop? hit;
    for (final s in state.stops) {
      if (s.subscriptionDayId?.toLowerCase() == id) hit = s;
    }
    _lastScanned = hit;
    if (hit == null) return ScanResult.unknown;
    if (hit.isLoaded) return ScanResult.alreadyLoaded;
    await markLoaded(hit.id);
    return ScanResult.loaded;
  }

  Future<void> startRoute(String groupKey) async {
    final l = state.local;
    if (!l.started.contains(groupKey)) _setLocal(l.copyWith(started: {...l.started, groupKey}));
    await _advance(groupKey);
  }

  Future<void> deliver(String stopId, {List<int>? photo}) async {
    final s = state.stopById(stopId);
    if (s == null || s.isClosed) return;
    final hasPhoto = photo != null && photo.isNotEmpty;
    // الخادمُ يحرس كذلك — والحارسُ هنا كي لا يُغلق التطبيقُ محطّةً ثمّ يُعيدها بعد ١٠ ثوانٍ.
    if ((state.profile?.photoRequired ?? false) && !hasPhoto) {
      _emit('صورة التسليم إلزاميّة في هذا المطعم', error: true);
      return;
    }
    await _close(s, 'delivered', photo: hasPhoto ? photo : null);
  }

  Future<void> leaveAtDoor(String stopId, List<int> photo) async {
    final s = state.stopById(stopId);
    if (s == null || s.isClosed) return;
    if (!(state.profile?.doorAllowed ?? true)) {
      _emit('الترك عند الباب غير مسموح في هذا المطعم', error: true);
      return;
    }
    if (photo.isEmpty) {
      _emit('الترك عند الباب يحتاج صورة', error: true);
      return;
    }
    await _close(s, 'delivered_door', photo: photo);
  }

  Future<void> fail(String stopId, String reason) async {
    final s = state.stopById(stopId);
    if (s == null || s.isClosed) return;
    final r = reason.trim();
    if (r.isEmpty) {
      _emit('اختر سبب التعذّر', error: true);
      return;
    }
    await _close(s, 'failed', reason: r);
  }

  Future<void> _close(Stop s, String action, {List<int>? photo, String? reason}) async {
    final wasCurrent = _group(s.slotKey)?.current?.id == s.id;
    final a = await _queue.enqueue(s.id, action, photo: photo, reason: reason, grace: _timing.closeGrace);
    if (_repo.isDemo) {
      _demoTrail
        ..remove(s.id)
        ..add(s.id);
      _recompute();
    }
    if (wasCurrent) await _advance(s.slotKey, parent: a);
  }

  Future<void> deferStop(String stopId) async {
    final s = state.stopById(stopId);
    if (s == null || s.isClosed) return;
    final key = s.slotKey;
    final l = state.local;
    _setLocal(l.copyWith(
      deferred: [...l.deferred.where((x) => x != stopId), stopId],
      pinned: l.pinned == stopId ? null : l.pinned,
    ));
    final next = _group(key)?.current;
    // آخرُ مفتوحٍ يبقى حاليًّا — لا معنى لإطفاء تتبّعه ثمّ إشعاله.
    if (next == null || next.id == stopId) return;
    if (s.status == StopStatus.enroute) await _queue.enqueue(stopId, 'defer');
    await _advance(key);
  }

  Future<void> goNow(String stopId) async {
    final s = state.stopById(stopId);
    if (s == null || s.isClosed) return;
    final key = s.slotKey;
    final l = state.local;
    _setLocal(l.copyWith(
      pinned: stopId,
      deferred: [for (final x in l.deferred) if (x != stopId) x],
      started: {...l.started, key},
    ));
    // كلُّ ما عداها «في الطريق» يُطفأ: عميلٌ واحدٌ يرى مندوبَه قادمًا.
    final g = _group(key);
    for (final o in g?.open ?? const <Stop>[]) {
      if (o.id != stopId && o.status == StopStatus.enroute) await _queue.enqueue(o.id, 'defer');
    }
    await _advance(key);
  }

  bool undo(String actionKey) => _queue.undo(actionKey);

  void recordCall(String stopId) {
    final l = state.local;
    _setLocal(l.copyWith(calls: {...l.calls, stopId: (l.calls[stopId] ?? 0) + 1}));
  }

  void ackGroup(String groupKey) {
    final l = state.local;
    if (!l.acked.contains(groupKey)) _setLocal(l.copyWith(acked: {...l.acked, groupKey}));
  }

  Future<void> loadHistory() async {
    try {
      final h = await _repo.history();
      if (!_disposed && state.signedIn) state = state.copyWith(history: h, historyLoaded: true);
    } on DriverActionError catch (e) {
      if (e.isSession) return _sessionDied();
      _emit(e.isTransient ? 'تعذّر تحميل السجلّ — تحقّق من الاتصال' : e.message, error: true);
    } catch (_) {
      _emit('تعذّر تحميل السجلّ — تحقّق من الاتصال', error: true);
    }
  }

  // ---------- المحادثة ----------

  Future<void> loadMessages(String stopId) async {
    try {
      final msgs = await _repo.messages(stopId);
      if (!_disposed && state.signedIn) state = state.copyWith(messages: {...state.messages, stopId: msgs});
    } on DriverActionError catch (e) {
      if (e.isSession) await _sessionDied();
    } catch (_) {}
  }

  Future<bool> sendMessage(String stopId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return false;
    try {
      await _repo.sendMessage(stopId, t);
    } on DriverActionError catch (e) {
      if (e.isSession) await _sessionDied();
      return false;
    } catch (_) {
      return false;
    }
    await loadMessages(stopId);
    return true;
  }

  /// المحادثةُ المفتوحة أمامه: لا إشعارَ عن رسائلها، وتُستطلع كلّ ٨ ثوانٍ احتياطًا
  /// لبثٍّ لحظيٍّ ضاع.
  void setOpenChat(String? stopId) {
    _openChat = stopId;
    _chatPoll?.cancel();
    _chatPoll = null;
    if (stopId == null) return;
    unawaited(loadMessages(stopId));
    _chatPoll = Timer.periodic(_timing.chatPollEvery, (_) => unawaited(loadMessages(stopId)));
  }

  Future<void> _onIncoming(IncomingMessage msg) async {
    if (msg.sender != 'customer') return; // رسائلُ المندوب نفسه لا تُشعِر
    final s = state.stopById(msg.deliveryId);
    if (s == null) return;
    // 🚨 النصُّ من المسار المحروس لا من الجرس (0457) — القناةُ عامّة.
    await loadMessages(s.id);
    if (_openChat == s.id || _repo.isDemo) return;
    ChatMessage? last;
    for (final m in (state.messages[s.id] ?? const <ChatMessage>[]).reversed) {
      if (!m.outgoing) {
        last = m;
        break;
      }
    }
    // الإشعارُ بلغة التطبيق التي اختارها المندوب، لا بالعربيّة دائمًا.
    final en = ref.read(localeProvider) == 'en';
    final who = s.customerName.isEmpty ? s.bagLabel : s.customerName;
    try {
      await NotificationsService.instance.showMessage(
        title: en ? 'Message from $who' : 'رسالة من $who',
        body: last?.text ?? (en ? 'New message' : 'رسالة جديدة'),
      );
    } catch (_) {}
  }
}
