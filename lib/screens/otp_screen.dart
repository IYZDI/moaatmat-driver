import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focus = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _filled => _controllers.every((c) => c.text.isNotEmpty);

  void _onChanged(int i, String v) {
    if (v.isNotEmpty && i < 3) _focus[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _focus[i - 1].requestFocus();
    setState(() {});
  }

  void _verify() {
    ref.read(driverProvider.notifier).verify();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(driverProvider).phone;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: InkWell(
              onTap: () => context.go('/login'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_right, size: 22, color: AppColors.ink),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 22, 30, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.smartphone, size: 30, color: AppColors.teal),
                  ),
                  const SizedBox(height: 22),
                  const Text('رمز التحقق', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
                      children: [
                        const TextSpan(text: 'أدخل الرمز المكوّن من 4 أرقام المُرسل عبر رسالة نصية إلى\n'),
                        TextSpan(
                          text: phone,
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          _box(i),
                          if (i < 3) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                        children: const [
                          TextSpan(text: 'لم يصلك الرمز؟ '),
                          TextSpan(text: 'إعادة الإرسال خلال 0:42', style: TextStyle(color: AppColors.muted3)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 14, 30, 34),
            child: PrimaryButton(label: 'تحقّق ودخول', onTap: _filled ? _verify : null),
          ),
        ],
      ),
    );
  }

  Widget _box(int i) {
    final filled = _controllers[i].text.isNotEmpty;
    return SizedBox(
      width: 60,
      height: 70,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focus[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => _onChanged(i, v),
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.teal),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: filled ? AppColors.tealTint2 : AppColors.surface2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: filled ? AppColors.teal : AppColors.border, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.teal, width: 2),
          ),
        ),
      ),
    );
  }
}
