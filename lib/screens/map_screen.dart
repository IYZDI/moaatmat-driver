import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../data/repository.dart';
import '../data/location_broadcaster.dart';

/// خريطة تخطيطية مطابقة للتصميم (طرق ومبانٍ ومسار وموقع المندوب والوجهة).
/// الإحداثيات في فضاء 300×672 كما في التصميم ثم تُقاس إلى حجم الشاشة.
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300, sy = size.height / 672;
    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy);

    final road = Paint()..color = const Color(0xFFF3F4F0);
    canvas.drawRect(r(234, 0, 16, 672), road);
    canvas.drawRect(r(108, 0, 26, 672), road);
    canvas.drawRect(r(0, 188, 300, 20), road);
    canvas.drawRect(r(0, 470, 300, 14), road);

    final block = Paint()..color = const Color(0xFFDCDFD6);
    canvas.drawRRect(RRect.fromRectAndRadius(r(204, 228, 60, 52), const Radius.circular(4)), block);
    canvas.drawRRect(RRect.fromRectAndRadius(r(10, 296, 80, 70), const Radius.circular(4)), block);
    canvas.drawRRect(RRect.fromRectAndRadius(r(90, 497, 90, 60), const Radius.circular(6)), Paint()..color = const Color(0xFFD3DED3));

    // المسار
    final route = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * sx
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(70 * sx, 560 * sy)
      ..lineTo(70 * sx, 470 * sy)
      ..lineTo(200 * sx, 470 * sy)
      ..lineTo(200 * sx, 250 * sy)
      ..lineTo(110 * sx, 250 * sy)
      ..lineTo(110 * sx, 150 * sy);
    canvas.drawPath(path, route);

    // موقع المندوب
    final dot = Offset(70 * sx, 560 * sy);
    canvas.drawCircle(dot, 10 * sx, Paint()..color = AppColors.teal);
    canvas.drawCircle(dot, 5 * sx, Paint()..color = Colors.white);

    // دبوس الوجهة (أحمر)
    final pin = Offset(110 * sx, 150 * sy);
    final pinPaint = Paint()..color = const Color(0xFFC0392B);
    canvas.drawCircle(pin.translate(0, -12 * sy), 12 * sx, pinPaint);
    final tail = Path()
      ..moveTo(pin.dx - 7 * sx, pin.dy - 8 * sy)
      ..lineTo(pin.dx + 7 * sx, pin.dy - 8 * sy)
      ..lineTo(pin.dx, pin.dy + 4 * sy)
      ..close();
    canvas.drawPath(tail, pinPaint);
    canvas.drawCircle(pin.translate(0, -13 * sy), 4 * sx, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapScreen extends ConsumerStatefulWidget {
  final String orderId;
  const MapScreen({super.key, required this.orderId});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  LocationBroadcaster? _broadcaster;
  bool _broadcasting = false;

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
  }

  @override
  void dispose() {
    _broadcaster?.stop();
    super.dispose();
  }

  Future<void> _openMaps(String address) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;
    final order = ref.watch(driverProvider).orderById(orderId);
    final name = order?.name ?? 'العميل';
    final address = order?.address ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFE4E7E0),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const StatusBar(),
                // بطاقة الوصول — نقرها يؤكّد الوصول للتسليم
                InkWell(
                  onTap: () => context.go('/deliver/$orderId'),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
                    ),
                    child: Row(
                      children: [
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
                              Text('$name · ${order?.distance ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text(order?.eta ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_broadcasting)
                  Container(
                    margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('يبثّ موقعك للعميل', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // اللوحة السفلية
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, -8))],
              ),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.teal)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 26),
                    child: Text('#$orderId · التوصيل المفضّل ${order?.prefTime ?? ''}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SquareIconButton(icon: Icons.phone_outlined, teal: true, size: 48, onTap: () => context.go('/chat/$orderId')),
                      const SizedBox(width: 9),
                      Expanded(
                        child: PrimaryButton(
                          label: 'فتح في خرائط جوجل',
                          icon: Icons.location_on_outlined,
                          fontSize: 15,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          radius: 13,
                          onTap: () => _openMaps(address),
                        ),
                      ),
                    ],
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
