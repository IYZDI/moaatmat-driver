import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/bag_badge.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// «سجلّي» — ما سلّمه المندوبُ يومًا بيوم، بأرقام الأكياس كما على الملصق.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// طلبٌ جارٍ الآن — الدوّارةُ تدور ما دام هذا فقط؛ فشلٌ يُبقي `historyLoaded`
  /// كاذبًا، ودوّارةٌ معلّقةٌ عليه وحدَه لا تتوقّف أبدًا.
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // يُجلب عند أوّل فتحٍ فقط؛ والسحبُ للأسفل يحدّثه بعدها. و«جارٍ» يُرفع من
    // الإطار الأوّل كي لا يومض «تعذّر التحميل» قبل أن يبدأ الطلب أصلًا.
    if (!ref.read(driverProvider).historyLoaded) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      await ref.read(driverProvider.notifier).loadHistory();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    // «اليوم» بتوقيت المطعم (org_today) لا الجهاز — كي يطابق مسار اليوم.
    final today = _day(s.profile?.orgToday ?? DateTime.now());

    DateTime dayOf(HistoryEntry e) => _day(e.routeDate ?? e.deliveredAt?.toLocal() ?? today);

    // ⚠ السجلُّ آخرُ 300 صفٍّ فقط: مندوبٌ مشغولٌ يتجاوزها في أيّام، فعدُّ الشهر من
    //   قائمةٍ مقطوعة رقمٌ مخترَع. ما قد يكون مقطوعًا يُكتب «300+» (حدًّا أدنى).
    //   وقبل أوّل تحميلٍ ناجح لا رقم («—»): «0 سُلّمت» ادّعاءٌ لا نعرفه.
    final todayCount = deliveredSince(s.history, today, dayOf);
    final monthCount = deliveredSince(s.history, DateTime(today.year, today.month), dayOf);
    String shown(({int count, bool atLeast}) c) =>
        !s.historyLoaded ? '—' : (c.atLeast ? t.atLeast(c.count) : '${c.count}');

    // التجميعُ بتاريخ المسار، والأحدثُ أوّلًا (الخادمُ يرتّبها كذلك).
    final days = <DateTime, List<HistoryEntry>>{};
    for (final e in s.history) {
      days.putIfAbsent(dayOf(e), () => []).add(e);
    }
    final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(t.tabHistory,
                  style: TextStyle(fontSize: TextSizes.headline, fontWeight: FontWeight.w800, color: p.ink)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Stat(value: shown(todayCount), label: t.today, sub: t.deliveredCount)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: shown(monthCount), label: t.thisMonth, sub: t.deliveredCount)),
                ],
              ),
              if (s.historyLoaded && (monthCount.atLeast || todayCount.atLeast))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(t.historyCapped(historyRowCap),
                      style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
                ),
              if (!s.historyLoaded && s.history.isEmpty && _loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!s.historyLoaded && s.history.isEmpty)
                // فشل التحميل: لا نقول «لا سجلّ» ونحن لا نعرف — زرٌّ يعيد المحاولة.
                EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: t.loadFailed,
                  action: BigButton(label: t.retry, icon: Icons.refresh, outlined: true, onPressed: _load),
                )
              else if (s.history.isEmpty)
                EmptyState(icon: Icons.history, title: t.noHistory)
              else
                for (final d in keys) ...[
                  SectionHeader(t.dayTitle(d, today)),
                  CardBox(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < days[d]!.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: p.border),
                          _Row(entry: days[d]![i], t: t),
                        ],
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.sub});

  /// نصٌّ لا عدد: «12» أو «300+» أو «—».
  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w700, color: p.muted)),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: p.ink)),
          Text(sub, style: TextStyle(fontSize: TextSizes.caption, color: p.successText)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.t});

  final HistoryEntry entry;
  final L t;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final e = entry;
    final (icon, color) = !e.delivered
        ? (Icons.cancel_outlined, p.dangerText)
        : e.atDoor
            ? (Icons.door_front_door_outlined, p.successText)
            : (Icons.check_circle_outline, p.successText);
    final when = e.deliveredAt == null ? '' : t.time(e.deliveredAt!);
    final String detail;
    if (!e.delivered) {
      detail = (e.failureReason?.trim().isNotEmpty ?? false) ? e.failureReason!.trim() : t.failedTag;
    } else if (e.atDoor) {
      detail = when.isEmpty ? t.atDoor : t.doorAt(when);
    } else {
      detail = when.isEmpty ? t.deliveredTag : t.deliveredAt(when);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          BagBadge(e.bagLabel, fontSize: 15, muted: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.customerName.trim().isEmpty ? t.customer : e.customerName.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w700, color: p.ink)),
                Text(detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
          if ((e.slotLabel?.trim() ?? '').isNotEmpty)
            Flexible(
              child: Text(e.slotLabel!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
            ),
        ],
      ),
    );
  }
}
