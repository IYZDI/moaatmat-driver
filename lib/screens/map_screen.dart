import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../data/repository.dart';
import '../data/location_broadcaster.dart';

/// شاشة الملاحة: خريطة حقيقية (OpenStreetMap) تعرض موقع المندوب الحيّ
/// ودبوس وجهة العميل، مع بثّ الموقع للعميل وزرّ تسليم واضح.
class MapScreen extends ConsumerStatefulWidget {
  final String orderId;
  const MapScreen({super.key, required this.orderId});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _riyadh = LatLng(24.7136, 46.6753);

  final _map = MapController();
  LocationBroadcaster? _broadcaster;
  bool _broadcasting = false;

  StreamSubscription<Position>? _posSub;
  LatLng? _me;
  bool _follow = true; // الكاميرا تتبع المندوب
  bool _didFit = false; // ضبط الإطار الأولي (المندوب + الوجهة) مرة واحدة
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    // في الوضع المتّصل نبثّ موقع المندوب طوال وجوده على شاشة الملاحة.
    final repo = ref.read(driverRepositoryProvider);
    if (repo != null) {
      _broadcaster = LocationBroadcaster(repo);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final ok = await _broadcaster!.start();
        if (mounted) setState(() => _broadcasting = ok);
      });
    }
    _watchMyLocation();
  }

  /// تتبّع موقع الجهاز لعرضه على الخريطة (مستقل عن البثّ للخادم).
  Future<void> _watchMyLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

    // نبدأ بآخر موقع معروف فورًا ثم نتابع التدفّق.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() => _me = LatLng(last.latitude, last.longitude));
        _afterPositionUpdate();
      }
    } catch (_) {}

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((p) {
      if (!mounted) return;
      setState(() => _me = LatLng(p.latitude, p.longitude));
      _afterPositionUpdate();
    });
  }

  LatLng? get _dest {
    final o = ref.read(driverProvider).orderById(widget.orderId);
    if (o?.lat == null || o?.lng == null) return null;
    return LatLng(o!.lat!, o.lng!);
  }

  void _afterPositionUpdate() {
    if (!_mapReady || _me == null) return;
    final dest = _dest;
    if (!_didFit) {
      _didFit = true;
      if (dest != null) {
        // إطار يجمع المندوب والوجهة معًا
        _map.fitCamera(CameraFit.coordinates(
          coordinates: [_me!, dest],
          padding: const EdgeInsets.fromLTRB(60, 160, 60, 260),
        ));
        return;
      }
    }
    if (_follow) _map.move(_me!, _map.camera.zoom < 13 ? 15 : _map.camera.zoom);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _broadcaster?.stop();
    super.dispose();
  }

  /// فتح الملاحة في خرائط جوجل — بالإحداثيات إن وُجدت، وإلا بالعنوان النصي.
  Future<void> _openMaps(Order? order) async {
    final dest = _dest;
    final uri = dest != null
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(order?.address ?? '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final orderId = widget.orderId;
    final order = ref.watch(driverProvider).orderById(orderId);
    final name = (order?.name.trim().isNotEmpty ?? false) ? order!.name.trim() : t.customer;
    final address = order?.address ?? '';
    final distance = order?.distance.trim() ?? '';
    final eta = order?.eta.trim() ?? '';
    final prefTime = order?.prefTime.trim() ?? '';
    final dest = (order?.lat != null && order?.lng != null) ? LatLng(order!.lat!, order.lng!) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFE4E7E0),
      body: Stack(
        children: [
          // ===== الخريطة الحقيقية =====
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: dest ?? _me ?? _riyadh,
                initialZoom: 14,
                onMapReady: () {
                  _mapReady = true;
                  _afterPositionUpdate();
                },
                // أي سحب يدوي يوقف التتبّع التلقائي
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.moaatmat.moaatmatDriver',
                ),
                if (_me != null && dest != null)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [_me!, dest],
                      strokeWidth: 4,
                      color: AppColors.teal.withValues(alpha: 0.55),
                    ),
                  ]),
                MarkerLayer(markers: [
                  // دبوس الوجهة (رأسه على النقطة)
                  if (dest != null)
                    Marker(
                      point: dest,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_pin, size: 44, color: Color(0xFFC0392B)),
                    ),
                  // موقع المندوب الحيّ
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.teal,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.navigation, size: 13, color: Colors.white),
                      ),
                    ),
                ]),
              ],
            ),
          ),

          // ===== الطبقة العلوية: بطاقة معلومات + شارة البثّ =====
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const StatusBar(),
                Container(
                  margin: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.canPop() ? context.pop() : context.go('/customers'),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(backChevron(context), size: 24, color: AppColors.muted2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(12)),
                        child: Transform.flip(flipX: true, child: const Icon(Icons.send, color: AppColors.teal, size: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(distance.isNotEmpty ? '$name · $distance' : name,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            if (eta.isNotEmpty)
                              Text(eta, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_broadcasting)
                      Container(
                        margin: const EdgeInsets.fromLTRB(18, 8, 0, 0),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(t.broadcastingLocation, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    // زر إعادة التمركز على موقعي
                    Container(
                      margin: const EdgeInsets.fromLTRB(0, 8, 18, 0),
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() => _follow = true);
                            if (_me != null && _mapReady) _map.move(_me!, 15);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.my_location, size: 20, color: _follow ? AppColors.teal : AppColors.muted2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===== اللوحة السفلية =====
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, -8))],
              ),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.trim().isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.teal)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink))),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 26),
                    child: Text(
                      '#${shortId(orderId)}${prefTime.isNotEmpty ? ' · ${t.preferredDelivery} $prefTime' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // مساعدات: محادثة العميل + فتح خرائط جوجل
                  Row(
                    children: [
                      SquareIconButton(icon: Icons.chat_bubble_outline, teal: true, size: 48, onTap: () => context.go('/chat/$orderId')),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            onTap: () => _openMaps(order),
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.map_outlined, size: 18, color: AppColors.teal),
                                  const SizedBox(width: 8),
                                  Text(t.openInGoogleMaps, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.teal)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ===== الزرّ الرئيسي الواضح: وصلت → التسليم =====
                  PrimaryButton(
                    label: t.arrivedDeliver,
                    icon: Icons.check_circle_outline,
                    fontSize: 16,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    radius: 14,
                    onTap: () => context.go('/deliver/$orderId'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
