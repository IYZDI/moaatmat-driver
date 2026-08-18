#!/usr/bin/env bash
# ============================================================================
# gen_firebase_ios.sh — يولّد GoogleService-Info.plist للشركة وقت البناء
# ويضيفه لموارد مشروع Xcode.
# ----------------------------------------------------------------------------
# لماذا: على iOS يُصدر النظام رمز APNs لحظة الإقلاع. تهيئة Firebase من Dart
# تأتي بعد ذلك، فلا يلتقط الرمز أبدًا (خطأ apns-token-not-set). الحل القياسي
# هو تهيئة Firebase في AppDelegate — وهي تتطلّب هذا الملف داخل الحزمة.
#
# ولأن التطبيق أبيض العلامة (تطبيق لكل مطعم) لا يمكن التزام ملف واحد، فنولّده
# من متغيّرات البيئة عند كل بناء. بلا متغيّرات → تخطٍّ صامت (التطبيق يعمل بلا
# إشعارات فورية).
# ============================================================================
set -euo pipefail

OUT="ios/Runner/GoogleService-Info.plist"

# ⛔ **التخطّي الصامتُ كان يُنتج مندوبًا لا يصله إشعارٌ واحد.**
# قِيس على الإنتاج (١٨ أغسطس ٢٠٢٦): `driver_device_tokens` **صفرُ صفوف** بينما
# `device_tokens` للعملاء أربعة. وسجلُّ آخر بناءٍ للسائق (١٦ أغسطس) يقول
# «ℹ لا إعدادات Firebase — تخطّي...» **والخطوةُ خضراء**. فبقيت رسائلُ العملاء
# لا ترنّ عند المندوب، وبدا العطلُ في المشغّل أو في الشيفرة ولم يكن فيهما.
#
# فالنقصُ صار **يُوقف البناء**، ويُصرَّح بتجاوزه إن أُريد بناءٌ بلا إشعارات:
#     ALLOW_NO_FIREBASE=1
MISSING=""
for v in FIREBASE_API_KEY FIREBASE_DRIVER_APP_ID FIREBASE_SENDER_ID FIREBASE_PROJECT_ID; do
  eval "val=\${$v:-}"
  [ -n "$val" ] || MISSING="$MISSING $v"
done

if [ -n "$MISSING" ]; then
  if [ "${ALLOW_NO_FIREBASE:-}" = "1" ]; then
    echo "⚠ بناءٌ بلا إشعارات بطلبٍ صريح (ALLOW_NO_FIREBASE=1). الناقص:$MISSING"
    exit 0
  fi
  echo "✗ ينقص إعدادُ Firebase:$MISSING"
  echo "  بدونه لا يُولَّد GoogleService-Info.plist، فلا يُهيَّأ Firebase في"
  echo "  AppDelegate، فلا يصدر رمزُ جهاز، فلا يصل المندوبَ إشعارٌ واحد —"
  echo "  ولا رسالةُ عميلٍ ولا إسنادُ توصيلة."
  echo "  تُضبط في مجموعة متغيّرات Codemagic «platform_shared»."
  echo "  ولبناءٍ بلا إشعارات عمدًا: ALLOW_NO_FIREBASE=1"
  exit 1
fi

cat > "$OUT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FIREBASE_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>${FIREBASE_SENDER_ID}</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>com.moaatmat.moaatmatDriver</string>
	<key>PROJECT_ID</key>
	<string>${FIREBASE_PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${FIREBASE_PROJECT_ID}.appspot.com</string>
	<key>GOOGLE_APP_ID</key>
	<string>${FIREBASE_DRIVER_APP_ID}</string>
	<key>IS_ADS_ENABLED</key>
	<false/>
	<key>IS_ANALYTICS_ENABLED</key>
	<false/>
	<key>IS_APPINVITE_ENABLED</key>
	<true/>
	<key>IS_GCM_ENABLED</key>
	<true/>
	<key>IS_SIGNIN_ENABLED</key>
	<true/>
</dict>
</plist>
PLIST
echo "✅ كُتب $OUT (مشروع ${FIREBASE_PROJECT_ID})"

# --- إضافته لموارد هدف Runner (وإلا لم يُضمَّن في الحزمة) ---
# نستخدم جوهرة xcodeproj المتوفّرة مع CocoaPods على أجهزة البناء.
ruby <<'RUBY'
require 'xcodeproj'
path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(path)
target = project.targets.find { |t| t.name == 'Runner' }
group = project.main_group.find_subpath('Runner', true)
name = 'GoogleService-Info.plist'

ref = group.files.find { |f| f.display_name == name }
ref ||= group.new_reference(name)

already = target.resources_build_phase.files.any? { |bf| bf.file_ref && bf.file_ref.display_name == name }
target.add_resources([ref]) unless already
project.save
puts already ? "ℹ #{name} مُضاف مسبقًا لموارد Runner" : "✅ أُضيف #{name} لموارد Runner"
RUBY
