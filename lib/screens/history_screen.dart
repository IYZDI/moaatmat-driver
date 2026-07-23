import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../models.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final data = ref.watch(driverProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          TealHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusBar(dark: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(t.completedOrders, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
                  child: Row(
                    children: [
                      _stat('${data.delivered}', t.today),
                      const SizedBox(width: 10),
                      _stat('142', t.thisMonth),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              children: [
                Text(t.today, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted3)),
                const SizedBox(height: 10),
                for (final h in data.history) ...[
                  _item(t, h),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const BottomNav(current: '/history'),
        ],
      ),
    );
  }

  Widget _item(L t, HistoryItem h) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(shape: BoxShape.circle, color: h.ok ? AppColors.tealTint : AppColors.dangerBg),
            child: Icon(h.ok ? Icons.check : Icons.close, size: 18, color: h.ok ? AppColors.teal : AppColors.danger),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('#${shortId(h.id)} · ${h.sub}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Text(h.ok ? t.deliveredLabel : t.failedLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: h.ok ? AppColors.teal : AppColors.danger)),
        ],
      ),
    );
  }

  Widget _stat(String num, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(num, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
