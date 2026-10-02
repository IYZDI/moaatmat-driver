import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/env.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/bag_badge.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/stop_actions.dart';
import '../widgets/stop_card.dart' show navigateStop;

/// يرسم دبّوسًا مرقّمًا (دائرةٌ ورقمٌ في وسطها) بـ`dart:ui` — خرائط جوجل لا
/// تعرف إلّا الصور، والدبّوسُ الأحمرُ الافتراضيّ لا يقول أيُّ المحطّات هذه.
Future<Uint8List> drawNumberedMarker(String label, {required Color fill, required Color text, required Color ring, double size = 40, double ratio = 3}) async {
  final px = size * ratio;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  final center = Offset(px / 2, px / 2);
  canvas.drawCircle(center, px / 2 - ratio, Paint()..color = fill);
  canvas.drawCircle(
    center,
    px / 2 - 2 * ratio,
    Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * ratio,
  );
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(color: text, fontSize: px * (label.length > 2 ? 0.34 : 0.44), fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  final img = await rec.endRecording().toImage(px.round(), px.round());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

LatLng _ll(LatLon p) => LatLng(p.lat, p.lng);

/// نمطُ الخريطة الليليّ (أسلوبُ «Night» من Google) — يُمرَّر لـ`GoogleMap.style`
/// حين يكون المظهرُ داكنًا.
const darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';

/// ============================================================================
/// خريطةُ المسار: المحطّاتُ المفتوحة مرقّمةً بترتيب المسار (الحاليّة رقم 1
/// وبلون التنقّل)، والمغلقةُ رماديّة، وخطٌّ يصلها من موقعي أو من الفرع.
/// ============================================================================
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _riyadh = LatLng(24.7136, 46.6753);

  GoogleMapController? _map;
  bool _locationOk = false;
  Set<Marker> _markers = const {};
  String _markersFor = '';
  bool _fitted = false;

  @override
  void initState() {
    super.initState();
    if (Env.hasMaps) _checkLocation();
  }

  /// النقطةُ الزرقاء تحتاج إذنَ الموقع — نقرؤه ولا نطلبه هنا: بثُّ الموقع
  /// (`LocationBroadcaster`) هو من يطلبه حين يبدأ المسار.
  Future<void> _checkLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      final ok = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
      if (mounted && ok != _locationOk) setState(() => _locationOk = ok);
    } catch (_) {}
  }

  /// الدبابيسُ تُرسم بلا تزامن، فتُعاد فقط حين يتغيّر ما ترسمه (الترتيب والحالة).
  Future<void> _rebuildMarkers(RouteGroupView g, Palette p, L t) async {
    final current = g.current ?? (g.open.isEmpty ? null : g.open.first);
    // ألوانُ الدبّوس من السطح كذلك — `primary` واحدٌ في المظهرين، فبدون السطح
    // بقيت الدبابيسُ بيضاءَ على خريطةٍ داكنة بعد تبديل المظهر.
    final sig = [
      for (final s in g.open) '${s.id}:${s.id == current?.id}',
      for (final s in g.closed) '${s.id}:c',
      p.primary.toARGB32(),
      p.surface.toARGB32(),
      p.borderStrong.toARGB32(),
    ].join('|');
    if (sig == _markersFor) return;
    _markersFor = sig;
    final out = <Marker>{};
    for (var i = 0; i < g.open.length; i++) {
      final s = g.open[i];
      if (!hasXY(s.pos)) continue;
      final isCurrent = s.id == current?.id;
      final bytes = await drawNumberedMarker(
        '${i + 1}',
        fill: isCurrent ? p.primary : p.surface,
        text: isCurrent ? p.onPrimary : p.primaryText,
        ring: isCurrent ? p.onPrimary : p.primary,
        size: isCurrent ? 48 : 40,
      );
      out.add(Marker(
        markerId: MarkerId(s.id),
        position: _ll(s.pos!),
        zIndexInt: isCurrent ? 3 : 2,
        icon: BitmapDescriptor.bytes(bytes, width: isCurrent ? 48 : 40, height: isCurrent ? 48 : 40),
        infoWindow: InfoWindow(title: '${s.bagLabel} · ${firstName(s.customerName)}'),
      ));
    }
    for (final s in g.closed) {
      if (!hasXY(s.pos)) continue;
      final bytes = await drawNumberedMarker('✓', fill: p.borderStrong, text: p.surface, ring: p.surface, size: 30);
      out.add(Marker(
        markerId: MarkerId(s.id),
        position: _ll(s.pos!),
        zIndexInt: 1,
        icon: BitmapDescriptor.bytes(bytes, width: 30, height: 30),
        infoWindow: InfoWindow(title: '${s.bagLabel} · ${firstName(s.customerName)}'),
      ));
    }
    if (mounted && sig == _markersFor) setState(() => _markers = out);
  }

  List<LatLng> _line(RouteGroupView g, LatLon? origin) => [
        if (hasXY(origin)) _ll(origin!),
        for (final s in g.open)
          if (hasXY(s.pos)) _ll(s.pos!),
      ];

  void _fit(List<LatLng> pts) {
    final map = _map;
    if (map == null || pts.isEmpty || _fitted) return;
    _fitted = true;
    if (pts.length == 1) {
      map.moveCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    var sw = pts.first, ne = pts.first;
    for (final x in pts) {
      sw = LatLng(x.latitude < sw.latitude ? x.latitude : sw.latitude, x.longitude < sw.longitude ? x.longitude : sw.longitude);
      ne = LatLng(x.latitude > ne.latitude ? x.latitude : ne.latitude, x.longitude > ne.longitude ? x.longitude : ne.longitude);
    }
    map.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 70));
  }

  Future<void> _openRoute(RouteGroupView g, LatLon? origin) async {
    final t = ref.read(stringsProvider);
    final uri = mapsDirUrl(origin, g.open);
    if (uri == null) return;
    final ok = await openUri(uri);
    if (!ok && mounted) showSnack(context, t.couldNotOpen);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final g = ref.watch(currentGroupProvider);
    final origin = s.myPos ?? g?.start;
    final current = g == null ? null : (g.current ?? (g.open.isEmpty ? null : g.open.first));
    final line = g == null ? const <LatLng>[] : _line(g, origin);

    if (g != null && Env.hasMaps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildMarkers(g, p, t);
      });
    }

    final Widget mapLayer;
    if (!Env.hasMaps) {
      // 🚨 لا تُنشأ `GoogleMap` بلا مفتاح: على iOS تُسقط `GMSMapView` التطبيقَ
      //    بانهيارٍ أصليٍّ لا يلتقطه Flutter. البديلُ لوحةٌ تقول السبب وقائمةٌ
      //    مرقّمة، والزرّان أسفلها يفتحان خرائط جوجل بلا مفتاحٍ أصلًا.
      mapLayer = _NoMapPanel(group: g);
    } else {
      final first = line.isNotEmpty ? line.first : _riyadh;
      mapLayer = GoogleMap(
        // مسارُ المساء في السيّارة ليلًا: خريطةٌ نهاريّة ساطعة تحت بطاقةٍ داكنة تُعمي.
        style: Theme.of(context).brightness == Brightness.dark ? darkMapStyle : null,
        initialCameraPosition: CameraPosition(target: current?.pos != null ? _ll(current!.pos!) : first, zoom: 13),
        onMapCreated: (c) {
          _map = c;
          _fit(line);
        },
        myLocationEnabled: _locationOk,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        markers: _markers,
        polylines: {
          if (line.length > 1)
            Polyline(
              polylineId: const PolylineId('route'),
              points: line,
              width: 4,
              color: p.primary,
            ),
        },
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: mapLayer),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    tooltip: t.back,
                    onTap: () => context.canPop() ? context.pop() : context.go('/route'),
                  ),
                  const Spacer(),
                  // «موقعي» بموقعٍ حقيقيّ فقط — الفرعُ بديلٌ لبداية الخطّ، لا «أنا».
                  if (Env.hasMaps && s.myPos != null)
                    _RoundButton(
                      icon: Icons.my_location,
                      tooltip: t.myLocation,
                      onTap: () => _map?.animateCamera(CameraUpdate.newLatLngZoom(_ll(s.myPos!), 15)),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (current == null)
                        Text(t.noOpenStops,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: TextSizes.body, color: p.muted))
                      else ...[
                        Row(
                          children: [
                            BagBadge(current.bagLabel, fontSize: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(current.customerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w800, color: p.ink)),
                                  if ((current.address?.trim() ?? '').isNotEmpty)
                                    Text(current.address!.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: TextSizes.small, color: p.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        BigButton(
                          label: canNavigate(current) ? t.navigate : t.noLocation,
                          icon: Icons.navigation_outlined,
                          onPressed: canNavigate(current) ? () => navigateStop(context, ref, current) : null,
                        ),
                      ],
                      const SizedBox(height: 10),
                      BigButton(
                        label: t.openRouteInMaps,
                        icon: Icons.alt_route,
                        outlined: true,
                        onPressed: g == null || mapsDirUrl(origin, g.open) == null ? null : () => _openRoute(g, origin),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Material(
      color: p.surface,
      shape: CircleBorder(side: BorderSide(color: p.border)),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon, color: p.ink),
      ),
    );
  }
}

/// بديلُ الخريطة حين لا مفتاح: السببُ مكتوبٌ، والمحطّاتُ مرقّمةً بالترتيب نفسه.
class _NoMapPanel extends ConsumerWidget {
  const _NoMapPanel({required this.group});

  final RouteGroupView? group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final open = group?.open ?? const <Stop>[];
    return Container(
      color: p.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 72, 16, 260),
          children: [
            Icon(Icons.map_outlined, size: 44, color: p.muted),
            const SizedBox(height: 10),
            Text(t.mapUnavailableTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w800, color: p.ink)),
            const SizedBox(height: 6),
            Text(t.mapUnavailableBody,
                textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.small, height: 1.6, color: p.muted)),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 16),
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < open.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 26,
                              child: Text('${i + 1}',
                                  style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w800, color: p.muted)),
                            ),
                            BagBadge(open[i].bagLabel, fontSize: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                [firstName(open[i].customerName), district(open[i].address)].where((x) => x.isNotEmpty).join(' — '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: TextSizes.small, color: p.ink2),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
