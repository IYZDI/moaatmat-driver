import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import 'driver_repository.dart';
import 'supabase_driver_repository.dart';

/// المستودع الحيّ (Supabase) عند توفّر إعدادات البيئة، وإلا null فيبقى التطبيق
/// في الوضع التجريبي (state.dart). عند تفعيل Supabase تُستبدل مصادر البيانات
/// في DriverNotifier بهذه الاستدعاءات دون تغيير الشاشات.
final driverRepositoryProvider = Provider<DriverRepository?>((ref) {
  return Env.hasSupabase ? SupabaseDriverRepository() : null;
});
