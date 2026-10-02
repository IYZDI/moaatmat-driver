import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
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

/// لماذا لم تعُد الكاميرا بصورة.
enum PhotoFailure { cancelled, denied, error }

/// نتيجةُ الكاميرا: صورةٌ، أو سببُ غيابها.
class PhotoResult {
  const PhotoResult.ok(List<int> this.bytes) : failure = null;
  const PhotoResult.failed(PhotoFailure this.failure) : bytes = null;

  final List<int>? bytes;
  final PhotoFailure? failure;
}

/// صورةُ التسليم من الكاميرا — جودة 70 وعرضٌ أقصى 1600: صورةٌ تُقرأ فيها
/// اللافتةُ والكيس، وتصل على شبكة جوّالٍ ضعيفة.
///
/// 🚨 الإلغاءُ غيرُ الرفض: كانت كلُّ أخطاء الكاميرا تُعاد `null` كأنّ المندوبَ
///   ألغى، فمن رفض إذنَ الكاميرا مرّةً صار «تم التسليم» زرًّا لا يفعل شيئًا ولا
///   يقول شيئًا — ولا تُغلق محطّةٌ في مطعمٍ يُلزم بالصورة.
Future<PhotoResult> takeDeliveryPhoto() async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (x == null) return const PhotoResult.failed(PhotoFailure.cancelled);
    return PhotoResult.ok(await x.readAsBytes());
  } on PlatformException catch (e) {
    // image_picker: «camera_access_denied» (iOS وأندرويد) و«camera_access_restricted» (iOS).
    final denied = e.code.startsWith('camera_access');
    return PhotoResult.failed(denied ? PhotoFailure.denied : PhotoFailure.error);
  } catch (_) {
    return const PhotoResult.failed(PhotoFailure.error);
  }
}

/// نصُّ ما حال دون الصورة — null عند الإلغاء (فعلُ المندوب نفسه لا يحتاج شرحًا).
String? photoFailureText(L t, PhotoFailure f, {required bool required}) => switch (f) {
      PhotoFailure.cancelled => null,
      PhotoFailure.denied => required ? t.cameraDeniedRequired : t.cameraDeniedPhoto,
      PhotoFailure.error => t.cameraError,
    };

/// يفتح إعداداتِ التطبيق — من geolocator الموجود أصلًا، فلا حزمةَ لسطرٍ واحد.
Future<void> openAppSettings() async {
  try {
    await Geolocator.openAppSettings();
  } catch (_) {}
}

/// يلتقط صورةً، وإن تعذّرت قال السببَ في شريطٍ أسفل الشاشة (مع «الإعدادات» عند
/// رفض الإذن). يعيد البايتات أو null.
Future<List<int>?> takeDeliveryPhotoOrExplain(BuildContext context, L t, {required bool required}) async {
  final r = await takeDeliveryPhoto();
  if (r.bytes != null) return r.bytes;
  final msg = photoFailureText(t, r.failure!, required: required);
  if (msg != null && context.mounted) {
    showSnack(
      context,
      msg,
      actionLabel: r.failure == PhotoFailure.denied ? t.openSettings : null,
      onAction: openAppSettings,
    );
  }
  return null;
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

/// رسالةٌ عابرة في أسفل الشاشة — ومعها فعلٌ اختياريّ («الإعدادات»).
void showSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final withAction = actionLabel != null && onAction != null;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      // رسالةٌ تحتاج فعلًا تبقى أطول — المندوبُ يقرأ ويمدّ إصبعه.
      duration: withAction ? const Duration(seconds: 8) : const Duration(seconds: 4),
      action: withAction ? SnackBarAction(label: actionLabel, onPressed: onAction) : null,
    ));
}
