import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/push_service.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/restaurant_header.dart';
import '../widgets/stop_actions.dart';

/// رقمُ الإصدار المعروض — يُحدَّث مع `version:` في pubspec.yaml (لا حزمةَ
/// package_info في هذا التطبيق، وإضافتُها لسطرٍ واحد لا تستحقّ).
const kAppVersion = '2.0.0 (1)';

/// «حسابي»: سياسةُ المطعم كما يطبّقها الخادم، وهويّةُ المندوب، والإعدادات.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notif = true;
  bool _notifBusy = false;

  /// الخروجُ يرسل الطابورَ أوّلًا (حتّى ٨ ثوانٍ) — الزرُّ يدور ولا يُضغط مرّتين.
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    // المفتاحُ يعرض التفضيلَ المحفوظ لا قيمةً ثابتة.
    PushService.isEnabled().then((v) {
      if (mounted) setState(() => _notif = v);
    });
  }

  /// تشغيلُ إشعارات هذا الجهاز أو إيقافُها — **فعلٌ في الخادم لا حالةٌ محلّيّة**:
  /// الإطفاءُ يُلغي تسجيلَ رمز الجهاز، ومُرسِلُ الإشعارات يقرأ صفوفَ التسجيل.
  Future<void> _setNotif(bool on) async {
    final t = ref.read(stringsProvider);
    final session = ref.read(driverRepositoryProvider).sessionToken;
    if (session == null) return;
    setState(() => _notifBusy = true);
    bool ok;
    if (on) {
      await PushService.instance.registerToken(session);
      ok = PushService.instance.registered;
    } else {
      ok = await PushService.instance.unregisterThisDevice(session);
    }
    if (ok) await PushService.setEnabled(on);
    if (!mounted) return;
    // ⛔ المفتاحُ يتبع ما وقع في الخادم لا ما ضغطه الإصبع.
    setState(() {
      _notifBusy = false;
      if (ok) _notif = on;
    });
    if (!ok) showSnack(context, t.notifToggleFailed);
  }

  Future<void> _callRestaurant() async {
    final t = ref.read(stringsProvider);
    final phone = ref.read(driverProvider).profile?.supportPhone?.trim() ?? '';
    if (phone.isEmpty) {
      showSnack(context, t.noSupportPhone);
      return;
    }
    final ok = await callPhone(phone);
    if (!ok && mounted) showSnack(context, t.couldNotOpen);
  }

  Future<void> _logout() async {
    final t = ref.read(stringsProvider);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.signOut),
        content: Text(t.signOutConfirm, style: const TextStyle(fontSize: TextSizes.body)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.pal.danger, foregroundColor: ctx.pal.onDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.signOut),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    // المُوجِّهُ يعيد التوجيه إلى الدخول حين تتغيّر حالةُ الجلسة.
    final n = ref.read(driverProvider.notifier);
    setState(() => _loggingOut = true);
    try {
      if (await n.logout()) return;
      if (!mounted) return;
      // بقي ما لم يُرسَل (بلا شبكة): الخروجُ يمحوه وصورَه. الافتراضيُّ البقاء.
      final drop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.unsentTitle),
          content: Text(t.unsentBody(n.unsentCount), style: const TextStyle(fontSize: TextSizes.body, height: 1.6)),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: ctx.pal.dangerText),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.signOutAnyway),
            ),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.staySignedIn)),
          ],
        ),
      );
      if (drop == true) await n.logout(discardUnsent: true);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final profile = s.profile;
    final lang = ref.watch(localeProvider);
    final mode = ref.watch(themeModeProvider);
    final name = (profile?.name.trim().isNotEmpty ?? false) ? profile!.name.trim() : t.driverFallback;
    final phone = profile?.phone.trim() ?? '';
    final support = profile?.supportPhone?.trim() ?? '';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(t.tabProfile, style: TextStyle(fontSize: TextSizes.headline, fontWeight: FontWeight.w800, color: p.ink)),
            const SizedBox(height: 14),
            if (s.demo)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Tag(t.demo, bg: p.warnSoft, fg: p.warnText),
              ),
            // ===== المطعم =====
            CardBox(
              child: Column(
                children: [
                  Row(
                    children: [
                      RestaurantLogo(profile: profile, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(profile?.orgName ?? '',
                            style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.photo_camera_outlined,
                    label: t.photoPolicy,
                    value: (profile?.photoRequired ?? true) ? t.required : t.optional,
                  ),
                  _InfoRow(
                    icon: Icons.door_front_door_outlined,
                    label: t.doorPolicy,
                    value: (profile?.doorAllowed ?? true) ? t.allowed : t.notAllowed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ===== المندوب =====
            CardBox(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: p.primarySoft,
                    child: Text(name.characters.first,
                        style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.primaryText)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w800, color: p.ink)),
                        if (phone.isNotEmpty)
                          Text(phone,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(fontSize: TextSizes.small, color: p.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(t.settings),
            CardBox(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _notif,
                    onChanged: _notifBusy || s.demo ? null : _setNotif,
                    secondary: Icon(Icons.notifications_outlined, color: p.ink2),
                    title: Text(t.routeNotifications,
                        style: const TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w600)),
                  ),
                  Divider(height: 1, color: p.border),
                  _SettingRow(
                    icon: Icons.language,
                    label: t.language,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'ar', label: Text('العربية')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {lang},
                      onSelectionChanged: (v) => ref.read(localeProvider.notifier).set(v.first),
                    ),
                  ),
                  Divider(height: 1, color: p.border),
                  _SettingRow(
                    icon: Icons.contrast,
                    label: t.appearance,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: ThemeMode.system, label: Text(t.themeSystem)),
                        ButtonSegment(value: ThemeMode.light, label: Text(t.themeLight)),
                        ButtonSegment(value: ThemeMode.dark, label: Text(t.themeDark)),
                      ],
                      selected: {mode},
                      onSelectionChanged: (v) => ref.read(themeModeProvider.notifier).set(v.first),
                    ),
                  ),
                  Divider(height: 1, color: p.border),
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(Icons.support_agent, color: p.ink2),
                    title: Text(t.callRestaurant,
                        style: const TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w600)),
                    // الرقمُ يُقرأ يسارًا ليمين، ويبقى في جهة البداية تحت العنوان.
                    subtitle: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(support.isEmpty ? t.noSupportPhone : support,
                          textDirection: support.isEmpty ? null : TextDirection.ltr,
                          style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
                    ),
                    onTap: _callRestaurant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BigButton(
                label: t.signOut,
                icon: Icons.logout,
                tone: Tone.danger,
                outlined: true,
                busy: _loggingOut,
                onPressed: _loggingOut ? null : _logout),
            const SizedBox(height: 14),
            Text(t.version(kAppVersion),
                textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.ink2),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: TextSizes.body, color: p.ink2))),
          Text(value, style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w800, color: p.ink)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.child});

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: p.ink2),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
