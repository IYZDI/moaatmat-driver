import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../models.dart';

class PickupScreen extends ConsumerStatefulWidget {
  const PickupScreen({super.key});

  @override
  ConsumerState<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends ConsumerState<PickupScreen> {
  bool _pickingAll = false;

  /// استلامُ الكلّ ثمّ الانتقال إلى «العملاء» — وهي الخطوةُ التالية في المسار.
  ///
  /// ⚠ ولا ينتقل إلّا إن **لم يبقَ** معلَّق: لو سقط تأكيدُ طلبٍ في الشبكة
  ///   فالانتقالُ يُخفي بقيّةً لم تُستلم، والمندوبُ يخرج من المطبخ ناقصًا.
  Future<void> _pickAll() async {
    setState(() => _pickingAll = true);
    final t = ref.read(stringsProvider);
    final n = await ref.read(driverProvider.notifier).confirmPickupAll();
    if (!mounted) return;
    setState(() => _pickingAll = false);
    if (n > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(t.pickedUpAll(n)),
            behavior: SnackBarBehavior.floating));
    }
    final left = ref
        .read(driverProvider)
        .orders
        .where((o) => o.active && !o.picked)
        .length;
    if (left == 0 && mounted) context.go('/customers');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final orders = ref.watch(driverProvider).orders;
    final pending = orders.where((o) => o.active && !o.picked).length;
    return Scaffold(
      backgroundColor: Colors.white,
      // (السحبُ للرجوع يُلَفّ في المُوجِّه لكلّ الشاشات — لا هنا شاشةً شاشة.)
      body: Column(
        children: [
          TealHeader(
            child: Column(
              children: [
                const StatusBar(dark: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/home'),
                        child: Icon(backChevron(context), color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(t.kitchenPickup, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const StepperBar(current: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
              children: [
                if (orders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(t.noOrdersToPick, style: const TextStyle(color: AppColors.muted))),
                  ),
                for (final o in orders) ...[
                  o.picked ? _doneCard(t, o) : _confirmCard(context, ref, t, o),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          // زرُّ «استلام الكل» أسفلَ الشاشة لا أعلاها: هو فعلُ الخروج من هذه
          // الصفحة، وموضعُه حيث يقع الإبهام بعد مراجعة القائمة. ولا يظهر إن لم
          // يبقَ معلَّق — زرٌّ لا يفعل شيئًا أسوأُ من غيابه.
          if (pending > 0)
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(22, 0, 22, 14),
              child: PrimaryButton(
                label: _pickingAll ? '…' : t.pickAll(pending),
                icon: Icons.done_all,
                onTap: _pickingAll ? null : _pickAll,
              ),
            ),
        ],
      ),
    );
  }

  Widget _confirmCard(BuildContext context, WidgetRef ref, L t, Order o) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text('#${shortId(o.id)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(o.items, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 14),
          PrimaryButton(
            label: t.confirmPickup,
            icon: Icons.check,
            fontSize: 15,
            padding: const EdgeInsets.all(13),
            radius: 12,
            onTap: () {
              ref.read(driverProvider.notifier).confirmPickup(o.id);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(t.pickedUpOrder(o.name)), behavior: SnackBarBehavior.floating));
            },
          ),
        ],
      ),
    );
  }

  Widget _doneCard(L t, Order o) {
    return AppCard(
      color: AppColors.tealTint2,
      borderColor: const Color(0xFFE2ECE9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.muted2)),
                const SizedBox(height: 3),
                Text('#${shortId(o.id)} · ${o.items}', style: const TextStyle(fontSize: 12, color: AppColors.muted3)),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.check, size: 15, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(t.done, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
            ],
          ),
        ],
      ),
    );
  }
}
