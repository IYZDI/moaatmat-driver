import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/bag_badge.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/restaurant_header.dart';
import '../widgets/slot_chips.dart';
import '../widgets/stop_actions.dart';
import '../widgets/stop_card.dart';
import '../widgets/sync_banner.dart';
import 'problem_sheet.dart';

/// ============================================================================
/// «مساري اليوم» — الشاشةُ التي يعيش فيها المندوب.
/// ----------------------------------------------------------------------------
/// ثلاثُ مراحل لكلّ مسار (فترة): حمِّل أكياسك ⇒ على الطريق محطّةً محطّة ⇒ انتهى.
/// المرحلةُ يحسبها `state.dart` (لا الشاشة)، فالشاشةُ تعرض ولا تقرّر.
/// ============================================================================
class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = ref.watch(driverProvider);
    final groups = ref.watch(routeGroupsProvider);
    final group = ref.watch(currentGroupProvider);
    final today = s.profile?.orgToday ?? DateTime.now();

    final Widget body;
    if (groups.isEmpty) {
      if (s.loadError != null) {
        body = EmptyState(
          icon: Icons.cloud_off_outlined,
          title: t.loadFailed,
          // نصٌّ ولّده التطبيق (رفضٌ برمزٍ تقنيّ) يُترجَم؛ ونصُّ الخادم يبقى بلغته.
          body: t.event(s.loadError!),
          action: BigButton(
            label: t.retry,
            icon: Icons.refresh,
            outlined: true,
            busy: s.syncing,
            onPressed: () => ref.read(driverProvider.notifier).refresh(full: true),
          ),
        );
      } else if (s.lastSync == null) {
        // أوّلُ تحميلٍ بعد الدخول: لا نقول «لا توصيلات» قبل أن نعرف.
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Center(child: CircularProgressIndicator()),
        );
      } else {
        body = EmptyState(
          icon: Icons.route_outlined,
          title: t.noDeliveriesToday,
          body: t.noDeliveriesBody,
        );
      }
    } else if (group == null) {
      body = const SizedBox.shrink();
    } else {
      body = switch (group.phase) {
        RoutePhase.loading => _LoadingView(group: group),
        RoutePhase.onRoute => _OnRouteView(group: group),
        RoutePhase.done => _DoneView(group: group, groups: groups),
      };
    }

    // زرّا التحميل مثبّتان أسفلَ الشاشة لا في آخر القائمة: مع ثمانية أكياسٍ أو
    // أكثر كان «ابدأ المسار» تحت حافّة الشاشة، فلا يعرف المندوبُ أين يبدأ.
    final pinned = group != null && group.phase == RoutePhase.loading;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: RefreshIndicator(
          // السحبُ يقرأ إعدادَ المطعم أيضًا — «غيّر المالكُ الصورة؟ اسحب».
          onRefresh: () => ref.read(driverProvider.notifier).refresh(full: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // مساحةٌ تحت القائمة كي لا يغطّي شريطُ التراجع آخرَ سطر.
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              RestaurantHeader(
                profile: s.profile,
                title: t.myRouteToday,
                subtitle: t.longDate(today),
                actions: [
                  const SyncIndicator(),
                  IconButton(
                    tooltip: t.routeMap,
                    iconSize: 26,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: groups.isEmpty ? null : () => context.push('/map'),
                    icon: const Icon(Icons.map_outlined),
                  ),
                ],
              ),
              const OfflineBanner(),
              if (groups.length > 1) ...[
                const SizedBox(height: 12),
                SlotChips(
                  groups: groups,
                  selectedKey: group?.key,
                  t: t,
                  onSelect: (k) => ref.read(selectedGroupKeyProvider.notifier).state = k,
                ),
              ],
              const SizedBox(height: 16),
              body,
            ],
          ),
            )),
            if (pinned) _LoadingActions(group: group),
          ],
        ),
      ),
    );
  }
}

/// «امسح ملصق الكيس» و«ابدأ المسار» — مثبّتان فوق شريط التبويب.
class _LoadingActions extends ConsumerWidget {
  const _LoadingActions({required this.group});

  final RouteGroupView group;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final t = ref.read(stringsProvider);
    final missing = group.open.where((s) => !s.isLoaded).toList();
    if (missing.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t.startWithoutTitle),
          content: Text(t.startWithoutBody(t.bagList(missing.map((s) => s.bagLabel))),
              style: const TextStyle(fontSize: TextSizes.body, height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.back)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.startAnyway)),
          ],
        ),
      );
      if (go != true) return;
    }
    HapticFeedback.mediumImpact();
    await ref.read(driverProvider.notifier).startRoute(group.key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: BigButton(
              label: t.startRoute(group.open.length),
              icon: Icons.play_arrow_rounded,
              onPressed: group.open.isEmpty ? null : () => _start(context, ref),
            ),
          ),
          const SizedBox(width: 10),
          // المسحُ أيقونةٌ بكلمةٍ قصيرة: الزرُّ الأعرضُ هو الفعلُ الذي يُنهي هذه المرحلة.
          Expanded(
            child: BigButton(
              label: t.scanShort,
              icon: Icons.qr_code_scanner,
              outlined: true,
              onPressed: () => context.push('/scan?mode=bags'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ١) التحميل
// ============================================================================
class _LoadingView extends ConsumerWidget {
  const _LoadingView({required this.group});

  final RouteGroupView group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.loadBags, style: TextStyle(fontSize: TextSizes.headline, fontWeight: FontWeight.w800, color: p.ink)),
        const SizedBox(height: 4),
        Text(t.loadHint, style: TextStyle(fontSize: TextSizes.body, color: p.muted)),
        const SizedBox(height: 16),
        ProgressHeader(
          title: t.loadedOf(group.loadedCount, group.total),
          value: group.total == 0 ? 0 : group.loadedCount / group.total,
          success: true,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [for (final s in group.all) _BagTile(stop: s)],
        ),
      ],
    );
  }
}

/// بلاطةُ كيس: الرقمُ ضخمٌ، والحالةُ لونٌ وكلمة — لا لونٌ وحده (عمى الألوان).
class _BagTile extends ConsumerWidget {
  const _BagTile({required this.stop});

  final Stop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final loaded = stop.isLoaded;
    final kitchen = !loaded && stop.inKitchen;
    final bg = loaded ? p.success : (kitchen ? p.warnSoft : p.surface);
    final fg = loaded ? p.onSuccess : (kitchen ? p.warnText : p.ink);
    final border = loaded ? p.success : (kitchen ? p.warnBorder : p.borderStrong);
    final state = loaded ? t.loaded : (kitchen ? t.inKitchen : t.notLoadedTag);
    return Semantics(
      button: !loaded,
      label: '${stop.bagLabel} ${stop.customerName} — $state',
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // المحمَّلُ لا يُفكّ بلمسة: التراجعُ من الشريط، كي لا تُلغي لمسةٌ عابرة تحميلًا.
          onTap: loaded || stop.isClosed
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  ref.read(driverProvider.notifier).markLoaded(stop.id);
                },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  child: Text(
                    stop.bagLabel,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(firstName(stop.customerName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w600, color: fg)),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loaded) Icon(Icons.check_circle, size: 16, color: fg),
                    if (kitchen) Icon(Icons.soup_kitchen_outlined, size: 16, color: fg),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(state,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: loaded || kitchen ? fg : p.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ٢) على الطريق
// ============================================================================
class _OnRouteView extends ConsumerWidget {
  const _OnRouteView({required this.group});

  final RouteGroupView group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final current = group.current ?? (group.open.isEmpty ? null : group.open.first);
    final next = group.open.where((s) => s.id != current?.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressHeader(
          title: t.stopOf((group.closedCount + 1).clamp(1, group.total == 0 ? 1 : group.total), group.total),
          trailing: t.remaining(group.open.length),
          value: group.total == 0 ? 0 : group.closedCount / group.total,
        ),
        const SizedBox(height: 14),
        if (current != null)
          CurrentStopCard(
            key: ValueKey(current.id),
            stop: current,
            onProblem: () => showProblemSheet(context, current),
          ),
        if (next.isNotEmpty) ...[
          SectionHeader(t.next),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < next.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.pal.border),
                  NextStopRow(
                    // رقمُ المحطة في المسار كلّه — كرأس الشاشة («المحطة 3 من 8») والخريطة:
                    // الحاليّةُ = ما أُغلق + 1، والتي بعدها تليها.
                    index: group.closedCount + i + 2,
                    stop: next[i],
                    onTap: () => showNextStopSheet(context, ref, next[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (group.closed.isNotEmpty) _ClosedSection(closed: group.closed),
      ],
    );
  }
}

/// «أُغلقت (7)» — مطويّةٌ افتراضيًّا: ما انتهى لا يزاحم ما بقي.
class _ClosedSection extends ConsumerStatefulWidget {
  const _ClosedSection({required this.closed});

  final List<Stop> closed;

  @override
  ConsumerState<_ClosedSection> createState() => _ClosedSectionState();
}

class _ClosedSectionState extends ConsumerState<_ClosedSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text(t.closedCount(widget.closed.length),
                      style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w800, color: p.ink2)),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: p.muted),
              ],
            ),
          ),
        ),
        if (_open)
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [for (final s in widget.closed) ClosedStopRow(stop: s)]),
          ),
      ],
    );
  }
}

// ============================================================================
// ٣) انتهى المسار
// ============================================================================
class _DoneView extends ConsumerWidget {
  const _DoneView({required this.group, required this.groups});

  final RouteGroupView group;
  final List<RouteGroupView> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final delivered = group.closed.where((x) => x.status == StopStatus.delivered).toList();
    final door = delivered.where((x) => x.atDoor).length;
    final failed = group.closed.where((x) => x.status == StopStatus.failed).toList();
    final acked = s.local.acked.contains(group.key);
    final nextGroups = groups.where((g) => g.key != group.key && g.open.isNotEmpty);
    final nextGroup = nextGroups.isEmpty ? null : nextGroups.first;
    // الأكياسُ المتعذّرة تعود إلى المطبخ — **ما حُمّل منها وحدَه**: كيسٌ لم يغادر
    // المطبخَ (تعذّر قبل أن يُحمَّل) لا يُطلب إرجاعُه.
    final toReturn = failed.where((x) => x.pickedAt != null || x.enrouteAt != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: p.successSoft, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 60, color: p.success),
          ),
        ),
        const SizedBox(height: 14),
        Text(t.routeDone,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: TextSizes.headline, fontWeight: FontWeight.w800, color: p.ink)),
        if (group.slotLabel != null || group.past)
          Text(t.groupName(group),
              textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.body, color: p.muted)),
        const SizedBox(height: 18),
        // البلاطتان بارتفاعٍ واحد وإن حملت إحداهما سطرَ «عند الباب».
        IntrinsicHeight(
         child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                value: delivered.length,
                label: t.deliveredCount,
                sub: door > 0 ? t.ofThemAtDoor(door) : null,
                bg: p.successSoft,
                fg: p.successText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                value: failed.length,
                label: t.failedCount,
                bg: failed.isEmpty ? p.surface2 : p.dangerSoft,
                fg: failed.isEmpty ? p.muted : p.dangerText,
              ),
            ),
          ],
        ),
        ),
        const SizedBox(height: 16),
        if (toReturn.isNotEmpty && !acked) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.warnSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.warnBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.assignment_return_outlined, color: p.warnText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.returnToKitchenTitle,
                          style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w700, color: p.warnText)),
                      const SizedBox(height: 8),
                      // شاراتٌ لا نصٌّ مفصول بفواصل: «#12، #15» يتقلّب اتّجاهُه في سطرٍ عربيّ.
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final x in toReturn) BagBadge(x.bagLabel, fontSize: 16)],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          BigButton(
            label: t.backAtKitchen,
            icon: Icons.storefront_outlined,
            onPressed: () => ref.read(driverProvider.notifier).ackGroup(group.key),
          ),
        ] else if (nextGroup != null)
          BigButton(
            label: t.nextRoute(t.groupName(nextGroup)),
            icon: Icons.arrow_forward,
            onPressed: () => ref.read(selectedGroupKeyProvider.notifier).state = nextGroup.key,
          )
        else
          Text(t.dayDone,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: TextSizes.bodyLg, fontWeight: FontWeight.w700, color: p.successText)),
        if (group.closed.isNotEmpty) _ClosedSection(closed: group.closed),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.sub, required this.bg, required this.fg});

  final int value;
  final String label;
  final String? sub;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$value', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: fg)),
            Text(label, style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w700, color: fg)),
            if (sub != null) Text(sub!, style: TextStyle(fontSize: TextSizes.caption, color: fg)),
          ],
        ),
      );
}
