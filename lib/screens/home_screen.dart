import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';
import '../models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(driverProvider);
    final name = data.name.trim().isNotEmpty ? data.name.trim() : 'مندوب';
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          TealHeader(
            child: Column(
              children: [
                const StatusBar(dark: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مساءً 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                            Text(name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(kDriver.place, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                          ],
                        ),
                      ),
                      _avatar(driverInitial(name), 48, 18),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                  child: Row(
                    children: [
                      _stat('${data.total}', 'طلبات اليوم'),
                      const SizedBox(width: 10),
                      _stat('${data.delivered}', 'تم التسليم'),
                      const SizedBox(width: 10),
                      _stat('${data.remaining}', 'متبقٍ', solid: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('طلبات نشطة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    InkWell(
                      onTap: () => context.go('/customers'),
                      child: const Text('عرض الكل', style: TextStyle(fontSize: 13, color: AppColors.teal, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (data.orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('لا طلبات نشطة حالياً 🎉', style: TextStyle(color: AppColors.muted))),
                  ),
                for (final o in data.orders) ...[
                  _orderCard(context, o),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const BottomNav(current: '/home'),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, Order o) {
    final meta = statusMeta(o.status);
    return InkWell(
      onTap: () => context.go('/customers'),
      borderRadius: BorderRadius.circular(18),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(o.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                StatusBadge(label: meta.label, fg: meta.fg, bg: meta.bg),
              ],
            ),
            const SizedBox(height: 8),
            Text('#${o.id} · التوصيل المفضّل ${o.prefTime}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String num, String label, {bool solid = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: solid ? Colors.white : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(num, style: TextStyle(color: solid ? AppColors.teal : Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: (solid ? AppColors.teal : Colors.white).withValues(alpha: 0.85), fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String txt, double size, double font) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
      child: Text(txt, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: font)),
    );
  }
}
