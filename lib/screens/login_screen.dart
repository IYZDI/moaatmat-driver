import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';

/// دخول المندوب: رمز المؤسسة + الجوال → رمز تحقّق (OTP) → دخول.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _org = TextEditingController();
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  bool _otpStep = false;
  String _orgName = '';

  @override
  void dispose() {
    _org.dispose();
    _phone.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  Future<void> _send() async {
    if (_org.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      _snack('أدخل رمز المؤسسة ورقم الجوال');
      return;
    }
    setState(() => _busy = true);
    try {
      final org = await ref.read(driverProvider.notifier).sendOtp(_org.text, _phone.text);
      if (mounted) setState(() { _orgName = org; _otpStep = true; });
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length < 4) {
      _snack('أدخل رمز التحقّق');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(driverProvider.notifier).verifyOtp(_org.text, _phone.text, _otp.text, _name.text);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: Column(
        children: [
          const StatusBar(dark: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(26)),
                    child: const Icon(Icons.inventory_2_outlined, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text('Moaatmat Driver', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_otpStep ? 'أدخل رمز التحقّق المُرسَل إليك' : 'سجّل الدخول لبدء مناوبتك',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 34),
            child: _otpStep ? _otpForm() : _enterForm(),
          ),
        ],
      ),
    );
  }

  Widget _enterForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('رمز المؤسسة', Icons.qr_code_2, _org, 'A1B2C3', ltr: true, caps: true),
          const SizedBox(height: 14),
          _field('رقم الجوال', Icons.phone_outlined, _phone, '05xxxxxxxx', ltr: true, keyboard: TextInputType.phone),
          const SizedBox(height: 14),
          _field('الاسم (اختياري — أول مرة فقط)', Icons.person_outline, _name, 'اسمك'),
          const SizedBox(height: 18),
          PrimaryButton(label: _busy ? 'جارٍ الإرسال…' : 'إرسال رمز التحقّق', onTap: _busy ? null : _send),
          const SizedBox(height: 12),
          const Center(child: Text('يصلك الرمز برسالة نصّية', style: TextStyle(fontSize: 13, color: AppColors.muted))),
        ],
      );

  Widget _otpForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text('أُرسل إلى ${_phone.text}${_orgName.isNotEmpty ? ' · $_orgName' : ''}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          ),
          _field('رمز التحقّق', Icons.lock_outline, _otp, '••••', ltr: true, keyboard: TextInputType.number, big: true),
          const SizedBox(height: 18),
          PrimaryButton(label: _busy ? 'جارٍ التحقّق…' : 'دخول', onTap: _busy ? null : _verify),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() { _otpStep = false; _otp.clear(); }),
            child: const Text('تغيير الرقم', style: TextStyle(color: AppColors.muted)),
          ),
        ],
      );

  Widget _field(String label, IconData icon, TextEditingController c, String hint,
      {bool ltr = false, bool caps = false, bool big = false, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted2)),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(color: AppColors.surface2, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.only(right: 15, left: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.muted3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: keyboard,
                  textDirection: ltr ? TextDirection.ltr : null,
                  textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
                  textAlign: big ? TextAlign.center : TextAlign.start,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.muted3, fontSize: 15),
                  ),
                  style: TextStyle(fontSize: big ? 22 : 15, fontWeight: big ? FontWeight.w800 : FontWeight.w400,
                      letterSpacing: big ? 8 : (caps ? 3 : 0), color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
