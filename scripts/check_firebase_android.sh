#!/usr/bin/env bash
# ============================================================================
# check_firebase_android.sh — حارسُ إعداد Firebase لخطّ أندرويد.
# ----------------------------------------------------------------------------
# لا يولّد ملفًّا بخلاف نظيره على iOS: أندرويد لا يحتاج google-services.json
# هنا، لأنّ التطبيق يُهيّئ Firebase برمجيًّا بـ`Firebase.initializeApp(options:)`
# من قيم --dart-define (انظر lib/data/push_service.dart). فالمطلوب فحصُ ما
# سيُحقن في الحزمة، ثمّ تثبيتُه لخطوة البناء.
#
# ⛔ ولماذا يُوقف البناء بدل أن يُحذّر: العطلُ الذي سبقه كان صامتًا كلَّه.
# كانت بيئةُ `android-apk` سطرًا واحدًا (`flutter: stable`) بلا `groups:` وبلا
# أيّ --dart-define، فتخرج المفاتيحُ الأربعُ فارغةً، فيكذب `Env.hasFirebase`،
# فيخرج `PushService.init()` من أوّل سطرٍ بلا سجلٍّ ولا استثناء — وتُختم الحزمةُ
# **خضراء**. والقياسُ في الإنتاج: `driver_device_tokens` صفرُ صفوفٍ لأندرويد
# مقابل صفّين لـiOS. وتحذيرٌ هنا يعني تكرارَ ذلك بحرفٍ أصفرَ في سجلٍّ لا يُقرأ:
# الصمتُ هو العطل، فلا يُعالَج بصوتٍ خافت.
#
# المتغيّرات (مجموعة «platform_shared» في Codemagic — نفسُها التي يستعملها
# خطُّ ios-driver):
#   FIREBASE_API_KEY  ·  FIREBASE_SENDER_ID  ·  FIREBASE_PROJECT_ID
#   FIREBASE_DRIVER_APP_ID_ANDROID   معرّف تطبيق **أندرويد** في مشروع Firebase
#
# ولبناءٍ بلا إشعارات عمدًا:  ALLOW_NO_FIREBASE=1
# ============================================================================
set -euo pipefail

# معرّف تطبيق Firebase مربوطٌ بالمنصّة: 1:…:android:… و 1:…:ios:… ولا يصلح
# أحدُهما للأخرى. والقاعدةُ تفصلهما عمودين أصلًا في org_app_config
# (firebase_app_id_android مقابل firebase_app_id)، فيُفصلان هنا كذلك.
# والوقوعُ على معرّف iOS عند غياب الأندرويديّ متعمَّد: يجعل الغيابَ يسقط في
# فحص المنصّة برسالةٍ تقول ما ينقص، بدل أن يمرّ بمعرّفٍ لا يعمل.
APP_ID="${FIREBASE_DRIVER_APP_ID_ANDROID:-${FIREBASE_DRIVER_APP_ID:-}}"

# تُفرَّغ الأربعةُ معًا عند التجاوز الصريح: «لا إشعارات» أصدقُ من «إشعاراتٍ
# موعودةٍ لا تصل»، ومفتاحٌ ناجٍ وحدَه يبقى في الحزمة بلا فائدة.
disable_push() {
  if [ -n "${CM_ENV:-}" ]; then
    printf '%s\n' 'FIREBASE_API_KEY=' 'FIREBASE_DRIVER_APP_ID=' \
                  'FIREBASE_SENDER_ID=' 'FIREBASE_PROJECT_ID=' >> "$CM_ENV"
  fi
}

MISSING=""
[ -n "${FIREBASE_API_KEY:-}" ]    || MISSING="$MISSING FIREBASE_API_KEY"
[ -n "$APP_ID" ]                  || MISSING="$MISSING FIREBASE_DRIVER_APP_ID_ANDROID"
[ -n "${FIREBASE_SENDER_ID:-}" ]  || MISSING="$MISSING FIREBASE_SENDER_ID"
[ -n "${FIREBASE_PROJECT_ID:-}" ] || MISSING="$MISSING FIREBASE_PROJECT_ID"

if [ -n "$MISSING" ]; then
  if [ "${ALLOW_NO_FIREBASE:-}" = "1" ]; then
    echo "⚠ بناءٌ بلا إشعارات بطلبٍ صريح (ALLOW_NO_FIREBASE=1). الناقص:$MISSING"
    disable_push
    exit 0
  fi
  echo "✗ ينقص إعدادُ Firebase لأندرويد:$MISSING" >&2
  echo "  بدونه تخرج مفاتيحُ --dart-define فارغةً، فيكذب Env.hasFirebase،" >&2
  echo "  فيخرج PushService.init من أوّل سطرٍ بلا خطأ — ولا يُسجَّل للمندوب" >&2
  echo "  رمزُ جهاز، فلا تصله رسالةُ عميلٍ ولا إسنادُ توصيلة، والبناءُ أخضر." >&2
  echo "  تُضبط في مجموعة متغيّرات Codemagic «platform_shared»." >&2
  echo "  ولبناءٍ بلا إشعارات عمدًا: ALLOW_NO_FIREBASE=1" >&2
  exit 1
fi

case "$APP_ID" in
  *":android:"*) : ;;
  *)
    if [ "${ALLOW_NO_FIREBASE:-}" = "1" ]; then
      echo "⚠ معرّفُ التطبيق ليس لأندرويد — تُطفأ الإشعارات بطلبٍ صريح (ALLOW_NO_FIREBASE=1)."
      disable_push
      exit 0
    fi
    echo "✗ معرّفُ تطبيق Firebase ليس لأندرويد: $APP_ID" >&2
    echo "  المعرّف مربوطٌ بالمنصّة (1:…:android:… مقابل 1:…:ios:…)، ومعرّفُ" >&2
    echo "  المنصّة الخطأ يمرّ في التهيئة ويسقط عند طلب الرمز — إشعاراتٌ" >&2
    echo "  «مفعّلة» لا تصل أحدًا، بلا خطأ في أيّ شاشة." >&2
    echo "  سجّل تطبيق أندرويد بمعرّف الحزمة com.moaatmat.moaatmat_driver في" >&2
    echo "  مشروع ${FIREBASE_PROJECT_ID}، وضع معرّفَه في المتغيّر" >&2
    echo "  FIREBASE_DRIVER_APP_ID_ANDROID داخل «platform_shared»." >&2
    exit 1
    ;;
esac

# ما فُحص هنا هو ما يُبنى: يُصدَّر باسم الـdart-define نفسِه، فتبقى خطوةُ البناء
# نسخةً حرفيّةً من سطر iOS ولا يتفرّع الاسمان.
if [ -n "${CM_ENV:-}" ]; then
  echo "FIREBASE_DRIVER_APP_ID=$APP_ID" >> "$CM_ENV"
else
  echo "ℹ لا CM_ENV (تشغيلٌ خارج Codemagic) — مرّر المعرّف بنفسك في أمر البناء."
fi

# يُطبع الطولُ لا المفتاح: سجلّات Codemagic تُقرأ ويُشارَك رابطُها. والمعرّفُ
# والمشروعُ يظهران لأنّهما داخل الحزمة أصلًا.
echo "✅ إعدادُ Firebase لأندرويد مكتمل — مشروع ${FIREBASE_PROJECT_ID} · تطبيق ${APP_ID}"
echo "   مفتاح API بطول ${#FIREBASE_API_KEY} حرفًا · مُرسِل ${FIREBASE_SENDER_ID}"
