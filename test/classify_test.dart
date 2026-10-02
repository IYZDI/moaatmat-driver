// ============================================================================
// تصنيفُ أخطاء الخادم — يقرّر هل يُعاد التسليمُ المحفوظ أم يُسقَط نهائيًّا.
// ============================================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/data/driver_repository.dart';
import 'package:moaatmat_driver/data/supabase_driver_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

DriverErrorKind kind(String? code, [String message = 'x']) =>
    SupabaseDriverRepository.classify(PostgrestException(message: message, code: code)).kind;

void main() {
  test('C-1 · رمزُ HTTP في `code` (جسمٌ لم يُفهم) عابرٌ — 429 ليس SQLSTATE «42…»', () {
    expect(kind('429'), DriverErrorKind.transient);
    expect(kind('422'), DriverErrorKind.transient);
    expect(kind('503'), DriverErrorKind.transient);
    expect(kind(null), DriverErrorKind.transient);
  });

  test('C-2 · SQLSTATE من خمسة محارف وPGRST2 ورسالةُ الخادم دائمة', () {
    expect(kind('42883'), DriverErrorKind.permanent, reason: 'دالّةٌ غيرُ موجودة');
    expect(kind('42501'), DriverErrorKind.permanent);
    expect(kind('22P02'), DriverErrorKind.permanent);
    expect(kind('PGRST202'), DriverErrorKind.permanent);
    final e = SupabaseDriverRepository.classify(
        const PostgrestException(message: 'صورة التسليم إلزاميّة في هذا المطعم', code: 'P0001'));
    expect(e.kind, DriverErrorKind.permanent);
    expect(e.message, 'صورة التسليم إلزاميّة في هذا المطعم');
    expect(kind('P0001', 'جلسة غير صالحة'), DriverErrorKind.session);
  });
}
