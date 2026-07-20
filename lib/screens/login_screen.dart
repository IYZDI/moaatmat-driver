import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets.dart';
import '../state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    ref.read(driverProvider.notifier).login(_phone.text);
    context.go('/otp');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: Column(
        children: [
          const StatusBar(dark: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text('Moaatmat Driver', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('سجّل الدخول لبدء مناوبتك', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field('رقم الجوال', Icons.phone_outlined, _phone, '05X XXX XXXX', ltr: true, keyboard: TextInputType.phone),
                const SizedBox(height: 14),
                _field('رمز المطعم', Icons.apartment_outlined, _code, 'مثال: MOA-1024'),
                const SizedBox(height: 18),
                PrimaryButton(label: 'إرسال رمز التحقق', onTap: _submit),
                const SizedBox(height: 12),
                const Center(
                  child: Text('لا تملك رمز المطعم؟ تواصل مع الإدارة', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, IconData icon, TextEditingController c, String hint, {bool ltr = false, TextInputType? keyboard}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted2)),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.muted3),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: c,
                  keyboardType: keyboard,
                  textDirection: ltr ? TextDirection.ltr : null,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppColors.muted3, fontSize: 15),
                  ),
                  style: const TextStyle(fontSize: 15, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
