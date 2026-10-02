import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state.dart';

/// ============================================================================
/// أفعالُ المحطة التي تخرج من التطبيق: اتصال · واتساب · ملاحة · كاميرا.
/// الروابطُ نفسُها تُبنى في `route_logic.dart` (مختبَرةً)، وهنا تُفتح فقط —
/// في موضعٍ واحد لأنّ البطاقةَ والأوراقَ والخريطةَ كلَّها تحتاجها.
/// ============================================================================

Future<bool> openUri(Uri? uri) async {
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> callPhone(String? phone) => openUri(telUri(phone));

Future<bool> openWhatsapp(String? phone) => openUri(whatsappUri(phone));

/// تستطيع المحطةُ أن تُقاد إليها؟ بالإحداثيّات، وإلّا بالعنوان المكتوب بحثًا.
bool canNavigate(Stop s) => navigationUri(s) != null;

Future<bool> navigateTo(Stop s) => openUri(navigationUri(s));

/// صورةُ التسليم من الكاميرا — جودة 70 وعرضٌ أقصى 1600: صورةٌ تُقرأ فيها
/// اللافتةُ والكيس، وتصل على شبكة جوّالٍ ضعيفة. `null` إن ألغى المندوب.
Future<List<int>?> takeDeliveryPhoto() async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (x == null) return null;
    return await x.readAsBytes();
  } catch (_) {
    return null;
  }
}

/// الحيّ من العنوان «الحيّ، الشارع، المبنى» — يكفي سطرَ «التالي».
String district(String? address) {
  final a = address?.trim() ?? '';
  if (a.isEmpty) return '';
  return a.split(RegExp('[،,]')).first.trim();
}

/// الاسمُ الأوّل — يكفي في البلاطة والشريط، والاسمُ الكامل في البطاقة.
String firstName(String name) {
  final n = name.trim();
  if (n.isEmpty) return '';
  return n.split(RegExp(r'\s+')).first;
}

/// رسالةٌ عابرة في أسفل الشاشة.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
