import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n.dart';
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
  final _otp = TextEditingController();
  bool _busy = false;
  bool _otpStep = false;
  String _orgName = '';

  @override
  void dispose() {
    _org.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }

  L get _t => ref.read(stringsProvider);

  Future<void> _send() async {
    if (_org.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      _snack(_t.enterOrgAndPhone);
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
      _snack(_t.enterOtp);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(driverProvider.notifier).verifyOtp(_org.text, _phone.text, _otp.text, '');
      if (!mounted) return;
      // أول دخول ولا اسم مسجّل في الداشبورد → نطلب الاسم مرّة واحدة فقط.
      if (ref.read(driverProvider).name.trim().isEmpty) {
        await _promptName();
      }
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// نافذة إدخال الاسم لأول مرة (يمكن تخطّيها بـ«لاحقًا»).
  Future<void> _promptName() async {
    final ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) {
        var saving = false;
        return StatefulBuilder(
          builder: (dctx, setD) => AlertDialog(
            title: Text(_t.welcome),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_t.askName, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(hintText: _t.fullName, border: const OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(dctx).pop(),
                child: Text(_t.later, style: const TextStyle(color: AppColors.muted)),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (ctrl.text.trim().isEmpty) return;
                        setD(() => saving = true);
                        final ok = await ref.read(driverProvider.notifier).setDriverName(ctrl.text);
                        if (dctx.mounted) Navigator.of(dctx).pop();
                        if (!ok && mounted) _snack(_t.nameSavedLocally);
                      },
                child: Text(_t.save, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal)),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
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
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 8))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/app_icon.png', width: 96, height: 96, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Moaatmat Driver', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(_otpStep ? t.loginOtpSubtitle : t.loginSubtitle,
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
          _field(_t.orgCode, Icons.qr_code_2, _org, 'A1B2C3', ltr: true, caps: true),
          const SizedBox(height: 14),
          _field(_t.phoneNumber, Icons.phone_outlined, _phone, '05xxxxxxxx', ltr: true, keyboard: TextInputType.phone),
          const SizedBox(height: 18),
          PrimaryButton(label: _busy ? _t.sending : _t.sendOtp, onTap: _busy ? null : _send),
          const SizedBox(height: 12),
          Center(child: Text(_t.otpBySms, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        ],
      );

  Widget _otpForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(_t.sentTo('${_phone.text}${_orgName.isNotEmpty ? ' · $_orgName' : ''}'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          ),
          _field(_t.otp, Icons.lock_outline, _otp, '••••', ltr: true, keyboard: TextInputType.number, big: true),
          const SizedBox(height: 18),
          PrimaryButton(label: _busy ? _t.verifying : _t.signIn, onTap: _busy ? null : _verify),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() { _otpStep = false; _otp.clear(); }),
            child: Text(_t.changeNumber, style: const TextStyle(color: AppColors.muted)),
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
