import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../models.dart';

class PickupScreen extends ConsumerWidget {
  const PickupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text('استلام من المطبخ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا طلبات بانتظار الاستلام', style: TextStyle(color: AppColors.muted))),
                  ),
                for (final o in orders) ...[
                  o.picked ? _doneCard(o) : _confirmCard(context, ref, o),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmCard(BuildContext context, WidgetRef ref, Order o) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(o.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text('#${o.id}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(o.items, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'تأكيد الاستلام',
            icon: Icons.check,
            fontSize: 15,
            padding: const EdgeInsets.all(13),
            radius: 12,
            onTap: () {
              ref.read(driverProvider.notifier).confirmPickup(o.id);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('تم استلام طلب ${o.name}'), behavior: SnackBarBehavior.floating));
            },
          ),
        ],
      ),
    );
  }

  Widget _doneCard(Order o) {
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
                Text('#${o.id} · ${o.items}', style: const TextStyle(fontSize: 12, color: AppColors.muted3)),
              ],
            ),
          ),
          const Row(
            children: [
              Icon(Icons.check, size: 15, color: AppColors.teal),
              SizedBox(width: 5),
              Text('تم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
            ],
          ),
        ],
      ),
    );
  }
}
