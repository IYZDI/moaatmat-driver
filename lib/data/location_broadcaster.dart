import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_repository.dart';

/// يبثّ موقع المندوب المباشر أثناء التوصيل عبر
/// `broadcast_my_delivery_location` — فيظهر على خريطة تتبّع الطلب لدى العميل.
class LocationBroadcaster {
  final DriverRepository repo;
  StreamSubscription<Position>? _sub;
  bool _sending = false;

  LocationBroadcaster(this.repo);

  bool get active => _sub != null;

  /// يطلب الإذن ويبدأ البثّ. يعيد false إن رُفض الإذن أو تعذّر.
  Future<bool> start() async {
    if (_sub != null) return true;
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

    _sub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen((pos) async {
      if (_sending) return; // تجاوز التحديث إن كان سابقه لم يكتمل بعد
      _sending = true;
      try {
        await repo.broadcastLocation(pos.latitude, pos.longitude);
      } catch (_) {
        // نتجاهل أخطاء البثّ العابرة (شبكة/إذن) — التحديث التالي يعيد المحاولة.
      }
      _sending = false;
    });
    return true;
  }

  Future<void> stop() async {
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
          notificationTitle: 'مُعتمَّات المندوب',
          notificationText: 'يُبثّ موقعك أثناء التوصيل',
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25);
  }
}
