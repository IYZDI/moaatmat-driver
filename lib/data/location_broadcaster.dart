import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_repository.dart';

/// يبثّ موقع المندوب المباشر أثناء التوصيل عبر `driver_ping_location` — فيظهر
/// على خريطة تتبّع الطلب لدى العميل — ويُخبر الحالةَ بكلّ موقعٍ جديد ليُحسب
/// «1.2 كم منك» من موقعٍ حقيقيّ لا مقدَّر.
class LocationBroadcaster {
  final DriverRepository repo;

  /// يُنادى بكلّ موقع — حتّى إن فشل إرسالُه: المسافةُ على الشاشة لا تنتظر الشبكة.
  final void Function(double lat, double lng)? onPosition;
  StreamSubscription<Position>? _sub;
  bool _sending = false;

  /// بدءٌ جارٍ — يُعاد لكلّ من ينادي `start` أثناءه.
  Future<bool>? _starting;

  /// يزيد مع كلّ `stop`: بدءٌ انتظر الإذنَ ثمّ وجد الجيلَ تغيّر لا يشترك.
  int _gen = 0;

  LocationBroadcaster(this.repo, {this.onPosition});

  bool get active => _sub != null;

  /// يطلب الإذن ويبدأ البثّ. يعيد false إن رُفض الإذن أو تعذّر.
  ///
  /// ⚠ بدءٌ واحدٌ في كلّ وقت: نافذةُ الإذن تُغيّب التطبيقَ ثمّ تُعيده، فينادي
  ///   «العودة» `start` ثانيةً والأوّلُ ما زال ينتظر الإذن. لو مضى الاثنان لكتب
  ///   الثاني فوق اشتراك الأوّل، فيبقى GPS يعمل ويبثّ بعد نهاية المسار وبعد الخروج.
  Future<bool> start() {
    if (_sub != null) return Future.value(true);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<bool> _start() async {
    final gen = _gen;
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }
    // ترقية الإذن إلى "دائمًا" لمواصلة بثّ الموقع في الخلفية (التطبيق مغلق/الشاشة
    // مقفلة) أثناء التوصيل. إن بقي "أثناء الاستخدام" فقط، يستمر البثّ في المقدّمة.
    if (perm == LocationPermission.whileInUse) {
      final upgraded = await Geolocator.requestPermission();
      if (upgraded == LocationPermission.always) perm = upgraded;
    }
    // أُوقف أثناء انتظار الإذن (انتهى المسار أو خرج) — لا يُشترك.
    if (gen != _gen || _sub != null) return _sub != null;

    _sub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen((pos) async {
      onPosition?.call(pos.latitude, pos.longitude);
      if (_sending) return; // تجاوز التحديث إن كان سابقه لم يكتمل بعد
      _sending = true;
      try {
        await repo.pingLocation(pos.latitude, pos.longitude);
      } catch (_) {
        // نتجاهل أخطاء البثّ العابرة (شبكة/إذن) — التحديث التالي يعيد المحاولة.
      }
      _sending = false;
    });
    return true;
  }

  Future<void> stop() async {
    _gen++;
    await _sub?.cancel();
    _sub = null;
  }

  /// إعدادات تدفّق الموقع مع تمكين التحديث في الخلفية على iOS/Android.
  LocationSettings _locationSettings() {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        activityType: ActivityType.automotiveNavigation,
        // يواصل النظام تزويدنا بالموقع والتطبيق في الخلفية (يتطلب إذن "دائمًا"
        // + UIBackgroundModes=location في Info.plist).
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        // مؤشّر أزرق أعلى الشاشة يخبر المندوب أن موقعه يُبثّ في الخلفية.
        showBackgroundLocationIndicator: true,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'مؤتمت — المندوب',
          notificationText: 'يُبثّ موقعك أثناء التوصيل',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25);
  }
}
