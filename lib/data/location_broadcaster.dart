import 'dart:async';
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

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
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
}
