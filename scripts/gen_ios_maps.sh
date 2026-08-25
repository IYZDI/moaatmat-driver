#!/usr/bin/env bash
# ============================================================================
# gen_ios_maps.sh — يكتب مفتاح خرائط جوجل في Info.plist وقت البناء.
#
# نسخةٌ من سكربت تطبيق العميل، بفارقٍ واحدٍ في المعنى: **تطبيقُ السائق ليس
# أبيضَ العلامة** — مستودعٌ واحدٌ ومعرّفُ حزمةٍ واحد لكلّ المطاعم. فالمفتاحُ
# هنا مفتاحُ المنصّة لا مفتاحُ مؤسّسة، والغرضُ من الحقن ليس الفصلَ بين
# المطاعم بل **إخراجُ المفتاح من المستودع**: كان مكتوبًا نصًّا في
# `AppDelegate.swift` و`AndroidManifest.xml`، والمستودعُ منشور.
#
# ⚠⚠ وبلا مفتاح: **انهيارٌ لا خريطةٌ رماديّة**. على iOS تُطلق `GMSMapView`
#    استثناءً أصليًّا لحظةَ إنشائها:
#
#      'GMSServicesException' … must be initialized via
#      [GMSServices provideAPIKey:…] prior to use
#
#    وهو انهيارٌ أصليٌّ لا استثناءُ Dart، فلا يظهر منه شيءٌ في أخطاء الواجهة —
#    عطلٌ بلا أثر. (كلّف تطبيقَ العميل بناءَ TestFlight رقم ٦٠.)
#    فالحارسُ الحقيقيّ في Dart: `Env.hasMaps` تمنع إنشاءَ الخريطة أصلًا،
#    وتضع مكانها لوحةً تقول السبب وتُبقي زرَّ «افتح في خرائط جوجل» عاملًا.
# ============================================================================
set -euo pipefail

PLIST="ios/Runner/Info.plist"

if [ ! -f "$PLIST" ]; then
  echo "⚠ لا Info.plist بعد — تُتخطّى كتابة مفتاح الخرائط" >&2
  exit 0
fi

if [ -z "${MAPS_API_KEY:-}" ]; then
  echo "⚠ لا مفتاح خرائط — لن تُعرض خريطةٌ في هذا البناء (iOS)."
  echo "  الحارس في Env.hasMaps يضع لوحةً بديلة، ولا ينهار التطبيق."
  echo "  أضف MAPS_API_KEY إلى مجموعة platform_shared في Codemagic."
  # يُحذف المدخل ولا يُكتب فارغًا: `PlistBuddy -c "Set :K "` بلا قيمة يُرفض
  # بـUnrecognized Argument، فيسقط السكربت بـ`set -e` ويوقف بناءً لا عيب فيه.
  /usr/libexec/PlistBuddy -c "Delete :GMSApiKey" "$PLIST" 2>/dev/null \
    && echo "   (حُذف مفتاحٌ سابق من الـplist)" || true
  exit 0
fi

/usr/libexec/PlistBuddy -c "Set :GMSApiKey ${MAPS_API_KEY}" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :GMSApiKey string ${MAPS_API_KEY}" "$PLIST"

# يُطبع الطول لا المفتاح: سجلّات Codemagic تُقرأ ويُشارَك رابطها.
echo "✅ كُتب مفتاح الخرائط في Info.plist (${#MAPS_API_KEY} حرفًا)"
