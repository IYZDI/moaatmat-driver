import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../l10n.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../models.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final orders = ref.watch(driverProvider).orders;
    return Scaffold(
      backgroundColor: Colors.white,
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
                      Text(t.deliveryCustomers, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const StepperBar(current: 2),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              children: [
                if (orders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text(t.allDeliveriesDone, style: const TextStyle(color: AppColors.muted))),
                  ),
                for (var i = 0; i < orders.length; i++) ...[
                  i == 0 ? _nextCard(context, ref, t, orders[i]) : _waitingCard(t, orders[i]),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressRow(String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.teal),
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(address, style: const TextStyle(fontSize: 13.5, color: AppColors.muted2, height: 1.5))),
      ],
    );
  }

  Widget _nextCard(BuildContext context, WidgetRef ref, L t, Order o) {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      shadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8))],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: t.next, fg: AppColors.teal, bg: AppColors.tealTint),
            ],
          ),
          const SizedBox(height: 10),
          _addressRow(o.address),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${o.id}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${t.preferredDelivery} ${o.prefTime}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SquareIconButton(icon: Icons.phone_outlined, teal: true, onTap: () => _snack(context, t.calling(o.name))),
              const SizedBox(width: 9),
              SquareIconButton(icon: Icons.location_on_outlined, onTap: () => context.go('/map/${o.id}')),
              const SizedBox(width: 9),
              SquareIconButton(icon: Icons.chat_bubble_outline, onTap: () => context.go('/chat/${o.id}')),
              const SizedBox(width: 9),
              Expanded(
                child: PrimaryButton(
                  label: t.confirmEnroute,
                  fontSize: 14.5,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  radius: 12,
                  onTap: () async {
                    await ref.read(driverProvider.notifier).confirmEnroute(o.id);
                    if (context.mounted) context.go('/map/${o.id}');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waitingCard(L t, Order o) {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: t.waiting, fg: AppColors.muted, bg: AppColors.border2),
            ],
          ),
          const SizedBox(height: 10),
          _addressRow(o.address),
          const SizedBox(height: 6),
          Text('#${o.id} · ${t.preferredDelivery} ${o.prefTime}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}
