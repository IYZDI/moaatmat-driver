import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../moaatmat_logo.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/stop_actions.dart';

/// آخرُ رمز مطعمٍ دخل به — المندوبُ يدخل لمطعمه نفسه كلَّ مرّة.
const _lastOrgKey = 'last_org_code';

/// ============================================================================
/// الدخول: رمزُ المطعم + الجوال ⇒ رمزُ تحقّق ⇒ دخول.
/// والمُوجِّهُ هو من ينقل المندوبَ إلى «مساري» حين تتغيّر حالةُ الجلسة — هذه
/// الشاشةُ لا تنتقل بنفسها، كي لا يتسابق مساران إلى الوجهة نفسها.
/// ============================================================================
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

  @override
  void initState() {
    super.initState();
    _loadLastOrg();
  }

  Future<void> _loadLastOrg() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_lastOrgKey);
      if (v != null && mounted && _org.text.isEmpty) _org.text = v;
    } catch (_) {}
  }

  @override
  void dispose() {
    _org.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _scanOrg() async {
    final code = await context.push<String>('/scan?mode=org');
    if (code != null && mounted) setState(() => _org.text = code);
  }

  Future<void> _send() async {
    final t = ref.read(stringsProvider);
    final org = _org.text.trim().toUpperCase();
    if (org.isEmpty || _phone.text.trim().isEmpty) {
      showSnack(context, t.enterOrgAndPhone);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(driverProvider.notifier).sendOtp(org, _phone.text.trim());
      try {
        await (await SharedPreferences.getInstance()).setString(_lastOrgKey, org);
      } catch (_) {}
      if (mounted) setState(() => _otpStep = true);
    } catch (e) {
      if (mounted) showSnack(context, _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final t = ref.read(stringsProvider);
    if (_otp.text.trim().length < 4) {
      showSnack(context, t.enterOtp);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(driverProvider.notifier)
          .verifyOtp(_org.text.trim().toUpperCase(), _phone.text.trim(), _otp.text.trim());
    } catch (e) {
      if (mounted) showSnack(context, _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MoaatmatLogo(size: 64)),
                    const SizedBox(height: 18),
                    Text(t.appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.ink)),
                    const SizedBox(height: 6),
                    Text(t.loginSubtitle,
                        textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.body, color: p.muted)),
                    const SizedBox(height: 32),
                    if (!_otpStep) ..._enterStep(t, p) else ..._otpStepUi(t, p),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _enterStep(L t, Palette p) => [
        Text(t.orgCode, style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w700, color: p.ink2)),
        const SizedBox(height: 6),
        TextField(
          controller: _org,
          textCapitalization: TextCapitalization.characters,
          textDirection: TextDirection.ltr,
          // الرمزُ يُكتب يسارًا ليمين، ويُحاذى كالتلميح في جهة البداية — لا يقفز عند أوّل حرف.
          textAlign: t.ar ? TextAlign.right : TextAlign.left,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(12),
            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
          ],
          style: const TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          decoration: InputDecoration(
            hintText: 'A1B2C3',
            suffixIcon: IconButton(
              tooltip: t.scanCode,
              onPressed: _busy ? null : _scanOrg,
              icon: const Icon(Icons.qr_code_scanner),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(t.phone, style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w700, color: p.ink2)),
        const SizedBox(height: 6),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: t.ar ? TextAlign.right : TextAlign.left,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
          style: const TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(hintText: '05xxxxxxxx'),
        ),
        const SizedBox(height: 24),
        BigButton(label: t.sendOtp, busy: _busy, onPressed: _send),
      ];

  List<Widget> _otpStepUi(L t, Palette p) => [
        Text(t.sentTo(_phone.text.trim()),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: TextSizes.body, color: p.ink2)),
        const SizedBox(height: 14),
        TextField(
          controller: _otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          onSubmitted: (_) => _verify(),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 12),
          decoration: InputDecoration(hintText: '••••', helperText: t.otpLabel),
        ),
        const SizedBox(height: 24),
        BigButton(label: t.signIn, busy: _busy, onPressed: _verify),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _otpStep = false;
                    _otp.clear();
                  }),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: Text(t.changeNumber, style: const TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w700)),
        ),
      ];
}
