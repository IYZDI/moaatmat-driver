import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';

/// مؤشّرُ الإرسال في الرأس: سحابةٌ وعددُ ما لم يصل الخادمَ بعد.
/// المندوبُ في قبوٍ بلا شبكة يرى أنّ ضغطته حُفظت ولم تضِع.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final n = s.pending.length;
    final IconData icon;
    final Color color;
    if (s.offline) {
      icon = Icons.cloud_off_outlined;
      color = p.warnText;
    } else if (n > 0 || s.syncing) {
      icon = Icons.cloud_upload_outlined;
      color = p.primaryText;
    } else {
      icon = Icons.cloud_done_outlined;
      color = p.success;
    }
    final label = n > 0 ? t.pendingSync(n) : (s.syncing ? t.syncing : t.allSynced);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              if (n > 0) ...[
                const SizedBox(width: 3),
                Text('$n', style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w800, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// شريطُ «لا اتصال» — يظهر فقط حين يكون الهاتفُ بلا شبكة.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(driverProvider.select((s) => s.offline));
    if (!offline) return const SizedBox.shrink();
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.warnSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.warnBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 20, color: p.warnText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.offlineBanner,
                style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w600, color: p.warnText)),
          ),
        ],
      ),
    );
  }
}
