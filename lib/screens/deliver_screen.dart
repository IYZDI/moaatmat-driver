import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  Uint8List? _photo;
  bool _reasonsOpen = false;
  bool _busy = false;

  Future<void> _capture() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      // على الويب/المنصّات بلا كاميرا يفتح مُنتقي الملفات؛ نتجاهل الإلغاء بهدوء.
    }
  }

  Future<void> _confirm(String name) async {
    if (_photo == null || _busy) return;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(driverProvider.notifier);
      await notifier.confirmDelivered(widget.orderId, _photo!);
      if (!mounted) return;
      _snack('تم تسليم طلب $name ✅');
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('تعذّر تأكيد التسليم — حاول مجددًا');
      }
    }
  }

  Future<void> _fail(String reason) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(driverProvider.notifier).markFailed(widget.orderId, reason);
      if (!mounted) return;
      _snack('سُجّل تعذّر التسليم');
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('تعذّر الحفظ — حاول مجددًا');
      }
    }
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تأكيد التسليم', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                            Text('$name · #${widget.orderId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                          ],
                        ),
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
                    decoration: BoxDecoration(color: AppColors.dangerBg, border: Border.all(color: AppColors.dangerBorder), borderRadius: BorderRadius.circular(14)),
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
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.dangerBorder), borderRadius: BorderRadius.circular(18)),
                    child: Column(
                      children: [
                        for (var i = 0; i < _reasons.length; i++)
                          InkWell(
                            onTap: () => _fail(_reasons[i]),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              decoration: BoxDecoration(border: i < _reasons.length - 1 ? const Border(bottom: BorderSide(color: AppColors.border2)) : null),
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
                PrimaryButton(label: _busy ? 'جارٍ الحفظ…' : 'تأكيد التسليم', fontSize: 15.5, onTap: (_photo != null && !_busy) ? () => _confirm(name) : null),
                if (_photo == null) ...[
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
    if (_photo != null) {
      return Container(
        decoration: BoxDecoration(color: AppColors.tealTint2, border: Border.all(color: AppColors.teal, width: 2), borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Image.memory(_photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
            TextButton(onPressed: _capture, child: const Text('إعادة الالتقاط', style: TextStyle(color: AppColors.muted))),
          ],
        ),
      );
    }
    return InkWell(
      onTap: _capture,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
        decoration: BoxDecoration(color: AppColors.surface2, border: Border.all(color: const Color(0xFFCFCDC8), width: 2), borderRadius: BorderRadius.circular(18)),
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
