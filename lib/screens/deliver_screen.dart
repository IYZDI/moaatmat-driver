import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';

const _reasons = ['العميل غير متواجد', 'لا يرد على الاتصال', 'عنوان غير صحيح', 'رفض استلام الطلب'];

class DeliverScreen extends ConsumerStatefulWidget {
  final String orderId;
  const DeliverScreen({super.key, required this.orderId});
  @override
  ConsumerState<DeliverScreen> createState() => _DeliverScreenState();
}

class _DeliverScreenState extends ConsumerState<DeliverScreen> {
  bool _captured = false; // تُستبدل لاحقاً بـ image_picker (كاميرا فعلية)
  bool _reasonsOpen = false;

  void _confirm(String name) {
    if (!_captured) return;
    ref.read(driverProvider.notifier).confirmDelivered(widget.orderId);
    _snack('تم تسليم طلب $name ✅');
    context.go('/home');
  }

  void _fail(String reason) {
    ref.read(driverProvider.notifier).markFailed(widget.orderId, reason);
    _snack('سُجّل تعذّر التسليم');
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(driverProvider).orderById(widget.orderId);
    final name = order?.name ?? 'العميل';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          TealHeader(
            child: Column(
              children: [
                const StatusBar(dark: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تأكيد التسليم', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                          Text('$name · #${widget.orderId}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                const StepperBar(current: 3),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              children: [
                Row(
                  children: const [
                    Text('صورة التسليم ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('*', style: TextStyle(fontSize: 15, color: AppColors.danger)),
                    SizedBox(width: 6),
                    Text('(إلزامية)', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 10),
                _dropzone(),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _reasonsOpen = !_reasonsOpen),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      border: Border.all(color: AppColors.dangerBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                        SizedBox(width: 10),
                        Text('تعذّر التسليم؟ اختر السبب', style: TextStyle(fontSize: 13, color: Color(0xFFA13A2F), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                if (_reasonsOpen) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.dangerBorder),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < _reasons.length; i++)
                          InkWell(
                            onTap: () => _fail(_reasons[i]),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              decoration: BoxDecoration(
                                border: i < _reasons.length - 1
                                    ? const Border(bottom: BorderSide(color: AppColors.border2))
                                    : null,
                              ),
                              child: Text(_reasons[i], style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFFA13A2F))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
            child: Column(
              children: [
                PrimaryButton(label: 'تأكيد التسليم', fontSize: 15.5, onTap: _captured ? () => _confirm(name) : null),
                if (!_captured) ...[
                  const SizedBox(height: 8),
                  const Text('يتم التفعيل بعد إضافة صورة التسليم', style: TextStyle(fontSize: 11.5, color: AppColors.muted3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropzone() {
    if (_captured) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.tealTint2,
          border: Border.all(color: AppColors.teal, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.teal),
              child: const Icon(Icons.check, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 12),
            const Text('تم التقاط صورة التسليم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.teal)),
            TextButton(onPressed: () => setState(() => _captured = false), child: const Text('إعادة الالتقاط', style: TextStyle(color: AppColors.muted))),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () => setState(() => _captured = true),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: const Color(0xFFCFCDC8), width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.tealTint),
              child: const Icon(Icons.photo_camera_outlined, color: AppColors.teal, size: 26),
            ),
            const SizedBox(height: 12),
            const Text('اضغط لالتقاط صورة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            const Text('صورة الطلب عند باب العميل', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}
