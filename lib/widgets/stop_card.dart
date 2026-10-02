import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import 'bag_badge.dart';
import 'buttons.dart';
import 'common.dart';
import 'stop_actions.dart';

/// «1.2 كم منك» — يُحذف حين لا نعرف موقعَ المندوب أو المحطة: رقمٌ مخمَّن أسوأ من لا رقم.
String? distanceLabel(L t, LatLon? me, Stop s) {
  if (me == null || s.pos == null) return null;
  final d = distanceKm(me, s.pos!);
  if (d == null) return null;
  return t.km(d);
}

/// اتصالٌ يُحسب: ورقةُ المشكلة تقول «اتصلت مرّتين» من هذا العدّاد.
Future<void> callStop(BuildContext context, WidgetRef ref, Stop stop) async {
  final phone = stop.phone?.trim() ?? '';
  if (phone.isEmpty) return;
  ref.read(driverProvider.notifier).recordCall(stop.id);
  final ok = await callPhone(phone);
  if (!ok && context.mounted) showSnack(context, ref.read(stringsProvider).couldNotOpen);
}

Future<void> navigateStop(BuildContext context, WidgetRef ref, Stop stop) async {
  final ok = await navigateTo(stop);
  if (!ok && context.mounted) showSnack(context, ref.read(stringsProvider).couldNotOpen);
}

/// «تم التسليم»: إن ألزم المطعمُ بالصورة فتحت الكاميرا أوّلًا — والخادمُ يرفض
/// التسليمَ بلا صورةٍ على أيّ حال، فالأفضلُ ألّا يُكتشف ذلك بعد عشر ثوانٍ.
/// وإن تعذّرت الكاميرا (إذنٌ مرفوض) قيل السببُ — زرٌّ لا يفعل شيئًا بصمتٍ كذبة.
Future<void> deliverStop(BuildContext context, WidgetRef ref, Stop stop, {bool withPhoto = false}) async {
  final required = ref.read(driverProvider).profile?.photoRequired ?? true;
  final n = ref.read(driverProvider.notifier);
  if (required || withPhoto) {
    final photo = await takeDeliveryPhotoOrExplain(context, ref.read(stringsProvider), required: required);
    if (photo == null) return; // ألغى أو تعذّرت (والسببُ قيل): لا شيءَ سُلِّم
    HapticFeedback.mediumImpact();
    await n.deliver(stop.id, photo: photo);
  } else {
    HapticFeedback.mediumImpact();
    await n.deliver(stop.id);
  }
}

/// بطاقةُ المحطة الحاليّة — كلُّ ما يحتاجه المندوبُ أمام الباب في شاشةٍ واحدة.
class CurrentStopCard extends ConsumerWidget {
  const CurrentStopCard({super.key, required this.stop, required this.onProblem});

  final Stop stop;
  final VoidCallback onProblem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final s = ref.watch(driverProvider);
    final photoRequired = s.profile?.photoRequired ?? true;
    final phone = stop.phone?.trim() ?? '';
    final address = stop.address?.trim() ?? '';
    final notes = stop.notes?.trim() ?? '';
    final dist = distanceLabel(t, s.myPos, stop);
    // اسمُ الفترة كما يراه العميل («صباحًا (6 - 9 ص)»)، وإلّا الساعتان — ونطاقُ
    // الساعات في سطرٍ عربيّ ينقلب بصريًّا، فالاسمُ أوضح.
    final window = stop.slotLabel ??
        ((stop.slotStart != null && stop.slotEnd != null) ? '${stop.slotStart} - ${stop.slotEnd}' : null);
    final items = stop.items?.trim() ?? '';

    return CardBox(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BagBadge(stop.bagLabel),
              const Spacer(),
              if (stop.pending != null)
                Tag(t.sending, bg: p.primarySoft, fg: p.primaryText),
            ],
          ),
          const SizedBox(height: 12),
          Text(stop.customerName.trim().isEmpty ? t.customer : stop.customerName.trim(),
              style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.ink)),
          const SizedBox(height: 4),
          Text(
            address.isNotEmpty ? address : (hasXY(stop.pos) ? t.addressOnMapOnly : t.noAddress),
            style: TextStyle(
              fontSize: TextSizes.bodyLg,
              height: 1.5,
              color: address.isNotEmpty ? p.ink2 : p.muted,
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.warnSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.warnBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.sticky_note_2_outlined, size: 18, color: p.warnText),
                    const SizedBox(width: 6),
                    Text(t.customerNote,
                        style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w800, color: p.warnText)),
                  ]),
                  const SizedBox(height: 4),
                  Text(notes, style: TextStyle(fontSize: TextSizes.body, height: 1.5, color: p.warnText)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (window != null && window.trim().isNotEmpty) InfoChip(icon: Icons.schedule, label: window),
              if (dist != null) InfoChip(icon: Icons.near_me_outlined, label: t.kmFromYou(dist)),
              if (stop.isSubscription && stop.mealsCount > 0)
                InfoChip(icon: Icons.restaurant_outlined, label: t.meals(stop.mealsCount))
              else if (items.isNotEmpty)
                InfoChip(icon: Icons.receipt_long_outlined, label: items),
            ],
          ),
          if (!stop.isLoaded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: p.warnSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.warnBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: p.warnText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.notLoadedWarning,
                        style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w700, color: p.warnText)),
                  ),
                  TextButton(
                    onPressed: () => ref.read(driverProvider.notifier).markLoaded(stop.id),
                    style: TextButton.styleFrom(foregroundColor: p.warnText, minimumSize: const Size(48, 48)),
                    child: Text(t.yesWithMe, style: const TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ActionTile(
                  icon: Icons.call_outlined,
                  label: t.call,
                  disabledLabel: t.noPhone,
                  onPressed: phone.isEmpty ? null : () => callStop(context, ref, stop),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionTile(
                  icon: Icons.forum_outlined,
                  label: t.whatsapp,
                  disabledLabel: t.noPhone,
                  onPressed: phone.isEmpty
                      ? null
                      : () async {
                          final ok = await openWhatsapp(phone);
                          if (!ok && context.mounted) showSnack(context, t.couldNotOpen);
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionTile(
                  icon: Icons.chat_bubble_outline,
                  label: t.chat,
                  onPressed: () => context.push('/chat/${stop.id}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ActionTile(
                  icon: Icons.navigation_outlined,
                  label: t.navigate,
                  disabledLabel: t.noLocation,
                  onPressed: canNavigate(stop) ? () => navigateStop(context, ref, stop) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BigButton(
                  label: t.delivered,
                  // الكاميرا في الأيقونة حين تُفتح فعلًا — لا يُفاجأ المندوب.
                  icon: photoRequired ? Icons.photo_camera_outlined : Icons.check_circle_outline,
                  tone: Tone.success,
                  height: 60,
                  onPressed: () => deliverStop(context, ref, stop),
                ),
              ),
              if (!photoRequired) ...[
                const SizedBox(width: 8),
                SquareButton(
                  icon: Icons.photo_camera_outlined,
                  label: t.withPhoto,
                  size: 60,
                  onPressed: () => deliverStop(context, ref, stop, withPhoto: true),
                ),
              ],
            ],
          ),
          if (photoRequired)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.photoRequiredHint,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onProblem,
            icon: const Icon(Icons.report_problem_outlined),
            label: Text(t.deliveryProblem),
            style: TextButton.styleFrom(
              foregroundColor: p.dangerText,
              minimumSize: const Size.fromHeight(48),
              // من نصوص الثيم لا نمطٌ جديد: نمطٌ جديد يُسقط عائلةَ الخطّ.
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: TextSizes.body, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// سطرٌ في «التالي»: الترتيب · رقمُ الكيس · الاسم — الحيّ أو المسافة.
class NextStopRow extends ConsumerWidget {
  const NextStopRow({super.key, required this.index, required this.stop, required this.onTap});

  final int index;
  final Stop stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final myPos = ref.watch(driverProvider.select((s) => s.myPos));
    final dist = distanceLabel(t, myPos, stop);
    final sub = [district(stop.address), ?dist].where((x) => x.isNotEmpty).join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$index',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w800, color: p.muted)),
              ),
              const SizedBox(width: 6),
              BagBadge(stop.bagLabel, fontSize: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.customerName.trim().isEmpty ? t.customer : stop.customerName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: TextSizes.body, fontWeight: FontWeight.w700, color: p.ink)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: TextSizes.caption, color: p.muted)),
                  ],
                ),
              ),
              if (!stop.isLoaded) Tag(t.notLoadedTag, bg: p.warnSoft, fg: p.warnText),
              Icon(Icons.chevron_right, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// سطرٌ في «أُغلقت»: ✓ سُلّم · باب · ✗ تعذّر.
class ClosedStopRow extends ConsumerWidget {
  const ClosedStopRow({super.key, required this.stop});

  final Stop stop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final p = context.pal;
    final delivered = stop.status == StopStatus.delivered;
    final (icon, color) = !delivered
        ? (Icons.cancel_outlined, p.dangerText)
        : stop.atDoor
            ? (Icons.door_front_door_outlined, p.successText)
            : (Icons.check_circle_outline, p.successText);
    final sub = !delivered
        ? (stop.failureReason?.trim().isNotEmpty ?? false ? stop.failureReason!.trim() : t.failedTag)
        : stop.atDoor
            ? t.atDoor
            : t.deliveredTag;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          BagBadge(stop.bagLabel, fontSize: 15, muted: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(stop.customerName.trim().isEmpty ? t.customer : stop.customerName.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: TextSizes.small, fontWeight: FontWeight.w600, color: p.ink2)),
          ),
          Flexible(
            child: Text(stop.pending != null ? t.sending : sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: TextSizes.caption, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// ورقةُ محطّةٍ من «التالي»: اذهب إليها الآن · اتصال · الملاحة.
Future<void> showNextStopSheet(BuildContext context, WidgetRef ref, Stop stop) {
  final t = ref.read(stringsProvider);
  return showModalBottomSheet<void>(
    context: context,
    // فوق شريط التبويبات وشريط التراجع — لا تحتهما.
    useRootNavigator: true,
    builder: (ctx) {
      final p = ctx.pal;
      final phone = stop.phone?.trim() ?? '';
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  BagBadge(stop.bagLabel, fontSize: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(stop.customerName.trim().isEmpty ? t.customer : stop.customerName.trim(),
                        style: TextStyle(fontSize: TextSizes.title, fontWeight: FontWeight.w800, color: p.ink)),
                  ),
                ],
              ),
              if ((stop.address?.trim() ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(stop.address!.trim(), style: TextStyle(fontSize: TextSizes.body, color: p.ink2)),
              ],
              const SizedBox(height: 16),
              BigButton(
                label: t.goNow,
                icon: Icons.near_me,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(driverProvider.notifier).goNow(stop.id);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: BigButton(
                      label: phone.isEmpty ? t.noPhone : t.call,
                      icon: Icons.call_outlined,
                      outlined: true,
                      onPressed: phone.isEmpty ? null : () => callStop(context, ref, stop),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BigButton(
                      label: canNavigate(stop) ? t.navigate : t.noLocation,
                      icon: Icons.navigation_outlined,
                      outlined: true,
                      onPressed: canNavigate(stop) ? () => navigateStop(context, ref, stop) : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
