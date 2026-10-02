import 'package:flutter_test/flutter_test.dart';
import 'package:moaatmat_driver/l10n.dart';

void main() {
  test('رسائلُ الحالة: العربيّةُ كما هي، والمعروفةُ تُترجَم، ورفضُ الخادم يبقى بنصّه', () {
    const ar = L(true);
    const en = L(false);
    const known = 'صورة التسليم إلزاميّة في هذا المطعم';
    const server = 'رسالةٌ من الخادم لا نعرفها';
    expect(ar.event(known), known);
    expect(en.event(known), 'This restaurant requires a delivery photo');
    expect(en.event(server), server);
  });
}
