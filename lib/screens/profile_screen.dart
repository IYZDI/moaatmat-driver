import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../config/env.dart';
import '../data/push_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notif = true;

  /// تشخيص الإشعارات الفورية — مخفيّ، يظهر بضغطة مطوّلة على اسم المندوب.
  bool _showPush = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final data = ref.watch(driverProvider);
    final name = data.name.trim().isNotEmpty ? data.name.trim() : t.driverFallback;
    final phone = data.phone.trim().isNotEmpty ? data.phone.trim() : '—';
    return Scaffold(
      backgroundColor: AppColors.surface3,
      body: Column(
        children: [
          TealHeader(
            child: Column(
              children: [
                const StatusBar(dark: true),
                Container(
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.fromLTRB(0, 14, 0, 12),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
                  child: Text(driverInitial(name), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                ),
                GestureDetector(
                  onLongPress: () => setState(() => _showPush = !_showPush),
                  child: Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${t.deliveryStaff}${data.orgName.trim().isNotEmpty ? ' · ${data.orgName.trim()}' : ''}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              children: [
                _group([
                  _row(Icons.phone_outlined, t.phoneNumber, trailing: Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
                  _row(
                    Icons.mail_outline,
                    t.connectionStatus,
                    trailing: Env.hasSupabase
                        ? StatusBadge(label: t.connected, fg: AppColors.teal, bg: AppColors.tealTint)
                        : StatusBadge(label: t.demo, fg: AppColors.amber, bg: AppColors.amberBg),
                    last: true,
                  ),
                ]),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                  child: Text(t.settings, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted3)),
                ),
                _group([
                  _row(
                    Icons.notifications_none,
                    t.newOrderNotifications,
                    iconColor: AppColors.muted2,
                    trailing: Switch(
                      value: _notif,
                      activeTrackColor: AppColors.teal,
                      onChanged: (v) => setState(() => _notif = v),
                    ),
                  ),
                  _row(
                    Icons.language,
                    t.language,
                    iconColor: AppColors.muted2,
                    trailing: Text(t.languageValue, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    onTap: () => ref.read(localeProvider.notifier).toggle(),
                  ),
                  _row(
                    Icons.support_agent,
                    t.helpSupport,
                    iconColor: AppColors.muted2,
                    trailing: Text(t.callRestaurant, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    onTap: _contactSupport,
                    last: true,
                  ),
                ]),
                if (_showPush) ...[
                  const SizedBox(height: 16),
                  _group([
                    _row(Icons.notifications_active_outlined, 'الإشعارات الفورية',
                        iconColor: AppColors.muted2,
                        trailing: Flexible(
                          child: Text(PushService.instance.statusSummary,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.muted)),
                        ),
                        last: true),
                  ]),
                ],
                const SizedBox(height: 16),
                _logoutButton(),
              ],
            ),
          ),
          const BottomNav(current: '/profile'),
        ],
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _row(IconData icon, String label, {Widget? trailing, Color iconColor = AppColors.teal, bool last = false, VoidCallback? onTap}) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 13),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
          ?trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }

  /// «المساعدة والدعم»: يجلب رقم تواصل مطعم المندوب ويعرض ورقة اتصال.
  Future<void> _contactSupport() async {
    final t = ref.read(stringsProvider);
    final info = await ref.read(driverProvider.notifier).orgInfo();
    if (!mounted) return;
    final phone = info?.supportPhone.trim() ?? '';
    if (info == null || phone.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(t.noSupportPhone),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.support_agent, color: AppColors.teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name.isNotEmpty ? info.name : t.restaurantSupport,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: t.callSupport,
                icon: Icons.phone_outlined,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    final t = ref.watch(stringsProvider);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () async {
          await ref.read(driverProvider.notifier).logout();
          if (mounted) context.go('/login');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFF0D8D4)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout, size: 18, color: AppColors.danger),
              const SizedBox(width: 8),
              Text(t.signOut, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
            ],
          ),
        ),
      ),
    );
  }
}
