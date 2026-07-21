import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../config/env.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notif = true;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(driverProvider);
    final name = data.name.trim().isNotEmpty ? data.name.trim() : 'مندوب';
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
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('موظف توصيل · مطعم مؤتمات', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                const SizedBox(height: 30),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              children: [
                _group([
                  _row(Icons.phone_outlined, 'رقم الجوال', trailing: Text(phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
                  _row(
                    Icons.mail_outline,
                    'حالة الاتصال بالمطعم',
                    trailing: Env.hasSupabase
                        ? const StatusBadge(label: 'متصل', fg: AppColors.teal, bg: AppColors.tealTint)
                        : const StatusBadge(label: 'تجريبي', fg: AppColors.amber, bg: AppColors.amberBg),
                    last: true,
                  ),
                ]),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(right: 4, bottom: 8),
                  child: Text('الإعدادات', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted3)),
                ),
                _group([
                  _row(
                    Icons.notifications_none,
                    'إشعارات الطلبات الجديدة',
                    iconColor: AppColors.muted2,
                    trailing: Switch(
                      value: _notif,
                      activeTrackColor: AppColors.teal,
                      onChanged: (v) => setState(() => _notif = v),
                    ),
                  ),
                  _row(Icons.language, 'اللغة', iconColor: AppColors.muted2, trailing: const Text('العربية ›', style: TextStyle(fontSize: 13, color: AppColors.muted))),
                  _row(Icons.info_outline, 'المساعدة والدعم', iconColor: AppColors.muted2, trailing: const Text('›', style: TextStyle(fontSize: 13, color: AppColors.muted3)), last: true),
                ]),
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

  Widget _row(IconData icon, String label, {Widget? trailing, Color iconColor = AppColors.teal, bool last = false}) {
    return Container(
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
  }

  Widget _logoutButton() {
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
            children: const [
              Icon(Icons.logout, size: 18, color: AppColors.danger),
              SizedBox(width: 8),
              Text('تسجيل الخروج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
            ],
          ),
        ),
      ),
    );
  }
}
