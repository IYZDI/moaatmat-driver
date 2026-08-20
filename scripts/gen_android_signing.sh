#!/usr/bin/env bash
# ============================================================================
# gen_android_signing.sh — يُنزل مخزنَ مفاتيح الإصدار من متغيّرٍ مُعمّى ويكتب
# android/key.properties وقت البناء.
# ----------------------------------------------------------------------------
# لماذا base64: متغيّرُ بيئةٍ متعدّد الأسطر يُشوَّه في Codemagic — وهي المصيدةُ
# نفسُها التي أكلت مفتاح توقيع iOS حتى خُزّن مُعمّى في سطرٍ واحد. والمخزن ملفٌّ
# ثنائيّ أصلًا فلا سبيل غيرها.
#
# المتغيّرات (مجموعة «platform_shared» في Codemagic):
#   ANDROID_KEYSTORE_B64        ملفّ .jks مُعمّى بـbase64 في سطرٍ واحد
#   ANDROID_KEYSTORE_PASSWORD   كلمة مرور المخزن
#   ANDROID_KEY_ALIAS           اسم المفتاح داخل المخزن
#   ANDROID_KEY_PASSWORD        كلمة مرور المفتاح (غالبًا = كلمة مرور المخزن)
#
# ولا يُتّخذ هنا قرارُ «أيمضي البناءُ بلا مفتاح أم يسقط»: ذلك في
# android/app/build.gradle.kts وحدَه — لأنّه يعرف أهدفُ إصدارٍ يُبنى أم تصحيح،
# ولأنّه يسقط ولو نُزعت هذه الخطوةُ من الخطّ. هذا الملفّ يُحضّر لا يحكم.
# ============================================================================
set -euo pipefail

if [ -z "${ANDROID_KEYSTORE_B64:-}" ]; then
  echo "ℹ لا ANDROID_KEYSTORE_B64 — لن يُكتب android/key.properties."
  echo "  وبناءُ الإصدار سيسقط في Gradle برسالةٍ تقول ما ينقص،"
  echo "  ولن يُوقَّع بمفتاح التصحيح صامتًا."
  exit 0
fi

for v in ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
  eval "val=\${$v:-}"
  if [ -z "$val" ]; then
    echo "✗ $v ناقص بينما ANDROID_KEYSTORE_B64 مضبوط — التوقيع لا يكتمل بنصفه." >&2
    exit 1
  fi
done

KS="$PWD/android/moaatmat-driver-upload.jks"

# يُفكّ بـopenssl أوّلًا لا بـ`base64`: خيارُ «سطرٌ واحد» (-A) خيارُ openssl وحدَه،
# و`base64 -A` يسقط بـ«unknown option» على GNU وعلى BSD معًا — فالسطرُ الذي كان
# هنا كان يفشل دائمًا ويتّكل على `base64 --decode` صامتًا، وهو غيرُ مضمونٍ على
# macOS (القديمُ لا يعرف غير -D) وآلةُ البناء macOS. وopenssl مضمونٌ عليها أصلًا:
# خطُّ iOS يفكّ به مفتاحَ الشهادة في codemagic.yaml بالخيار نفسِه.
# وكلُّ محاولةٍ تكتب الملفَّ من أوّله كي لا يلتحم نصفُ فكٍّ فاشلٍ بنصفٍ ناجح.
decoded=0
for dec in "openssl base64 -d -A" "base64 -d" "base64 -D"; do
  if printf '%s' "$ANDROID_KEYSTORE_B64" | $dec > "$KS" 2>/dev/null && [ -s "$KS" ]; then
    decoded=1
    break
  fi
done

if [ "$decoded" != "1" ]; then
  echo "✗ فكّ التعمية أنتج ملفًّا فارغًا — تحقّق أنّ ANDROID_KEYSTORE_B64 سطرٌ واحد بلا فراغات." >&2
  exit 1
fi

# فحصٌ يسقط الآن بدل أن يسقط داخل Gradle برسالةٍ مبهمة بعد دقائق.
if ! keytool -list -keystore "$KS" -storepass "$ANDROID_KEYSTORE_PASSWORD" -alias "$ANDROID_KEY_ALIAS" >/dev/null 2>&1; then
  echo "✗ المخزن لا يُفتح بهذه الكلمة أو لا يحوي المفتاح «$ANDROID_KEY_ALIAS»." >&2
  echo "   الأسماء المتاحة فيه:" >&2
  keytool -list -keystore "$KS" -storepass "$ANDROID_KEYSTORE_PASSWORD" 2>&1 | grep -i "PrivateKeyEntry" >&2 || true
  exit 1
fi

cat > android/key.properties <<PROPS
storeFile=$KS
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
PROPS

echo "🔐 مفتاح الرفع جاهز — الحزمة ستُوقَّع توقيعًا ثابتًا عبر الأبنية"
# بصمةُ الشهادة تُطبع لأنّها تُطلب عند ربط الحزمة بـFirebase وبـPlay، وهي
# ليست سرًّا (تُستخرج من أيّ حزمةٍ موقّعة). وطبعُها هنا يُغني عن تنزيل الحزمة.
keytool -list -v -keystore "$KS" -storepass "$ANDROID_KEYSTORE_PASSWORD" -alias "$ANDROID_KEY_ALIAS" 2>/dev/null \
  | grep -E "SHA1:|SHA256:" || true
