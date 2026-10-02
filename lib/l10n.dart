import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'route_logic.dart' show ArNoun, arDeliveries, arMeals, arStops, arTimes, enCount;

/// ============================================================================
/// نصوصُ التطبيق ولغتُه ومظهرُه.
/// ----------------------------------------------------------------------------
/// العربيّةُ أوّلًا: المندوبُ يقرأ في الشمس وبيدٍ واحدة، فالجملةُ قصيرةٌ وفعليّة.
/// والإنجليزيّةُ ترجمةٌ لها لا العكس. كلُّ نصٍّ يمرّ من هنا — نصٌّ مكتوبٌ في
/// شاشةٍ مباشرةً لا يُترجَم أبدًا ويُنسى.
/// ============================================================================

/// لغةُ التطبيق ('ar' | 'en') — تُحفظ في الجهاز وتنعكس فورًا على النصّ والاتّجاه.
class LocaleNotifier extends Notifier<String> {
  static const _key = 'app_lang';

  @override
  String build() {
    _load();
    return 'ar';
  }

  Future<void> _load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_key);
      if (v == 'en' && state != 'en') state = 'en';
    } catch (_) {/* تعذّرت القراءة: تبقى العربيّة */}
  }

  Future<void> set(String lang) async {
    state = lang == 'en' ? 'en' : 'ar';
    try {
      await (await SharedPreferences.getInstance()).setString(_key, state);
    } catch (_) {/* التفضيلُ راحةٌ لا حقيقة: يبقى للجلسة */}
  }

  Future<void> toggle() => set(state == 'ar' ? 'en' : 'ar');
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

/// المظهر: تلقائيّ (يتبع الجهاز) · فاتح · داكن — يُحفظ في `app_theme`.
/// مسارُ المساء في السيّارة ليلًا يحتاج الداكن، ونهارُ الشمس يحتاج الفاتح.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'app_theme';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  static ThemeMode _parse(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> _load() async {
    try {
      final v = _parse((await SharedPreferences.getInstance()).getString(_key));
      if (v != state) state = v;
    } catch (_) {}
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(_key, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

final stringsProvider = Provider<L>((ref) => L(ref.watch(localeProvider) == 'ar'));

class L {
  final bool ar;
  const L(this.ar);

  /// أسبابُ التعذّر تُرسَل بالعربيّة دائمًا: يقرؤها فريقُ المطعم في لوحته
  /// العربيّة، ولغةُ هاتف المندوب لا تغيّر لغةَ السجلّ.
  static const reasons = L(true);

  String _(String a, String e) => ar ? a : e;

  /// «#12» داخل جملةٍ عربيّة ينقلب إلى «12#» عند طرف السطر: نعزله اتّجاهًا
  /// بين LRI (U+2066) وPDI (U+2069).
  static String iso(String bagLabel) => String.fromCharCode(0x2066) + bagLabel + String.fromCharCode(0x2069);

  /// قائمةُ أكياس «#4، #17» — كلٌّ معزولٌ اتّجاهًا.
  String bagList(Iterable<String> labels) => labels.map(iso).join(ar ? '، ' : ', ');

  // ---------- الجمع العربيّ ----------
  // القاعدةُ نفسُها في `route_logic.dart` (مختبَرة): محطة واحدة · محطتان ·
  // 3 محطات · 11 محطة — والأرقامُ غربيّةٌ كما على الملصق.
  String stops(int n) => ar ? arStops(n) : enCount(n, ArNoun.stop);
  String deliveries(int n) => ar ? arDeliveries(n) : enCount(n, ArNoun.delivery);
  String meals(int n) => ar ? arMeals(n) : enCount(n, ArNoun.meal);

  /// «اتصلت مرّتين» — المفعولُ منصوب، فالمثنّى بالياء.
  String calledTimes(int n) =>
      ar ? 'اتصلت ${arTimes(n, accusative: true)}' : 'Called ${enCount(n, ArNoun.time)}';

  // ---------- عامّ ----------
  String get appName => _('مندوب مؤتمت', 'Moaatmat Driver');
  String get tagline => _('مسارك اليوم، محطّةً محطّة', 'Your route today, stop by stop');
  String get customer => _('العميل', 'Customer');
  String get cancel => _('إلغاء', 'Cancel');
  String get back => _('رجوع', 'Back');
  String get done => _('تم', 'Done');
  String get save => _('حفظ', 'Save');
  String get later => _('لاحقًا', 'Later');
  String get retry => _('أعد المحاولة', 'Try again');
  String get noSlot => _('بلا فترة', 'No slot');
  String get today => _('اليوم', 'Today');
  String get yesterday => _('أمس', 'Yesterday');
  String get sending => _('يُرسَل…', 'Sending…');
  String get couldNotOpen => _('تعذّر فتح التطبيق المطلوب', "Couldn't open the app");

  /// رسائلُ الحالة تولد عربيّةً في `state.dart` وطبقة البيانات (لا تعرف اللغة)،
  /// فتُترجَم هنا عند العرض. ما ليس في الجدول (رفضُ الخادم بنصّه) يُعرض كما هو:
  /// تخمينُ ترجمةٍ لجملةٍ كتبها الخادم أسوأ من عرضها بلغتها.
  String event(String message) {
    if (ar) return message;
    const en = {
      'انتهت جلستك — سجّل الدخول من جديد': 'Your session ended — sign in again',
      'تعذّر تحميل السجلّ — تحقّق من الاتصال': "Couldn't load history — check your connection",
      'اختر سبب التعذّر': 'Choose a reason',
      'صورة التسليم إلزاميّة في هذا المطعم': 'This restaurant requires a delivery photo',
      'الترك عند الباب غير مسموح في هذا المطعم': "This restaurant doesn't allow leaving at the door",
      'الترك عند الباب يحتاج صورة': 'Leaving at the door needs a photo',
      'ضاعت صورة التسليم — صوّر من جديد': 'The delivery photo was lost — take it again',
      'الصورة كبيرة جدًّا — التقطها من جديد': 'The photo is too large — take it again',
      'تعذّرت قراءة الصورة — التقطها من جديد': "Couldn't read the photo — take it again",
      'هذه التوصيلةُ ليست لك': 'This delivery is not assigned to you',
      'أُلغيت هذه التوصيلة': 'This delivery was cancelled',
      'تعذّر تأكيد التسليم': "Couldn't confirm the delivery",
    };
    return en[message] ?? message;
  }

  // ---------- التبويبات ----------
  String get tabRoute => _('مساري', 'Route');
  String get tabHistory => _('سجلّي', 'History');
  String get tabProfile => _('حسابي', 'Account');

  // ---------- الدخول ----------
  String get loginSubtitle => _('سجّل دخولك لتبدأ مسارك', 'Sign in to start your route');
  String get orgCode => _('رمز المطعم', 'Restaurant code');
  String get scanCode => _('امسح الرمز', 'Scan code');
  String get phone => _('رقم الجوال', 'Mobile number');
  String get sendOtp => _('أرسل رمز التحقّق', 'Send verification code');
  String get enterOrgAndPhone => _('أدخل رمز المطعم ورقم الجوال', 'Enter the restaurant code and mobile number');
  String sentTo(String to) => _('أرسلناه إلى $to', 'Sent to $to');
  String get otpLabel => _('رمز التحقّق', 'Verification code');
  String get changeNumber => _('تغيير الرقم', 'Change number');
  String get signIn => _('دخول', 'Sign in');
  String get enterOtp => _('أدخل الرمز كاملًا', 'Enter the full code');
  String get askNameTitle => _('ما اسمك؟', "What's your name?");
  String get askNameBody => _('يظهر لفريق المطعم.', 'The restaurant team will see it.');
  String get fullName => _('اسمك', 'Your name');
  String get nameNotSaved => _('لم يُحفظ الاسم — جرّب من «حسابي» لاحقًا', "Name not saved — try again from Account");

  // ---------- رأس المسار ----------
  String get myRouteToday => _('مساري اليوم', "Today's route");
  String get routeMap => _('خريطة المسار', 'Route map');
  String pendingSync(int n) => _('$n بانتظار الإرسال', '$n waiting to send');
  String get allSynced => _('كلّ شيءٍ مُرسَل', 'All sent');
  String get offlineBanner => _('لا اتصال — أفعالك محفوظة وتُرسَل حين يعود', "Offline — your actions are saved and will send when you're back");
  String get syncing => _('يحدّث…', 'Updating…');

  // ---------- التحميل ----------
  String get loadBags => _('حمّل أكياسك', 'Load your bags');
  String get loadHint => _('طابِق الرقم مع ملصق الكيس ثمّ المسه', 'Match the number with the bag label, then tap it');
  String loadedOf(int a, int b) => _('حمّلت $a من $b', 'Loaded $a of $b');
  String get inKitchen => _('في المطبخ', 'In kitchen');
  String get loaded => _('حُمّل', 'Loaded');
  String get scanBagLabel => _('امسح ملصق الكيس', 'Scan bag label');
  String startRoute(int n) => _('ابدأ المسار · ${stops(n)}', 'Start route · ${stops(n)}');
  String get startWithoutTitle => _('ابدأ بدونها؟', 'Start without them?');
  String startWithoutBody(String bags) =>
      _('لم تحمّل: $bags\nتبقى في مسارك، وتحمّلها متى وصلتَ إليها.', "Not loaded: $bags\nThey stay on your route.");
  String get startAnyway => _('ابدأ', 'Start');

  // ---------- على الطريق ----------
  String stopOf(int a, int b) => _('المحطة $a من $b', 'Stop $a of $b');
  String remaining(int n) => _('باقي $n', '$n left');
  String get addressOnMapOnly => _('العنوان على الخريطة فقط', 'Location on map only');
  String get noAddress => _('لا عنوان مكتوب', 'No written address');
  String get customerNote => _('ملاحظة العميل', 'Customer note');
  String kmFromYou(String d) => _('$d منك', '$d away');
  String km(double d) => d < 1
      ? _('${(d * 1000).round()} م', '${(d * 1000).round()} m')
      : _('${d.toStringAsFixed(1)} كم', '${d.toStringAsFixed(1)} km');
  String get call => _('اتصال', 'Call');
  String get noPhone => _('لا رقم', 'No number');
  String get whatsapp => _('واتساب', 'WhatsApp');
  String get chat => _('محادثة', 'Chat');
  String get navigate => _('الملاحة', 'Navigate');
  String get noLocation => _('لا موقع', 'No location');
  String get delivered => _('تم التسليم', 'Delivered');
  String get withPhoto => _('بصورة', 'Photo');
  String get photoRequiredHint => _('يفتح الكاميرا: صورة التسليم إلزاميّة', 'Opens the camera: photo required');
  String get notLoadedWarning => _('هذا الكيس لم يُحمَّل — هل هو معك؟', "This bag wasn't loaded — do you have it?");
  String get yesWithMe => _('نعم، معي', 'Yes, I have it');
  String get deliveryProblem => _('مشكلة في التسليم', 'Delivery problem');
  String get next => _('التالي', 'Next');
  String get notLoadedTag => _('لم يُحمَّل', 'Not loaded');
  String closedCount(int n) => _('أُغلقت ($n)', 'Closed ($n)');
  String get goNow => _('اذهب إليها الآن', 'Go there now');
  String get atDoor => _('عند الباب', 'At the door');
  String get failedTag => _('تعذّر', 'Failed');
  String get deliveredTag => _('سُلّم', 'Delivered');

  // ---------- انتهى المسار ----------
  String get routeDone => _('انتهى المسار', 'Route finished');
  String get deliveredCount => _('سُلّمت', 'Delivered');
  String ofThemAtDoor(int n) => _('منها $n عند الباب', '$n at the door');
  String get failedCount => _('تعذّرت', 'Failed');
  String returnToKitchen(String bags) => _('أعِد إلى المطبخ: $bags', 'Return to kitchen: $bags');
  String get backAtKitchen => _('وصلتُ المطبخ', "I'm back at the kitchen");
  String nextRoute(String slot) => _('المسار التالي: $slot', 'Next route: $slot');
  String get dayDone => _('انتهى يومك — شكرًا لك', 'Your day is done — thank you');

  // ---------- فارغ ----------
  String get noDeliveriesToday => _('لا توصيلات اليوم', 'No deliveries today');
  String get noDeliveriesBody => _('سيصلك إشعار حين يُسند إليك مسار.', "You'll get a notification when a route is assigned.");
  String get loadFailed => _('تعذّر تحميل المسار', "Couldn't load the route");

  // ---------- التراجع ----------
  String get undo => _('تراجع', 'Undo');
  String undoLabel(String action, String bag, String name) {
    final verb = switch (action) {
      'picked' => _('حُمّل', 'Loaded'),
      'delivered' => _('سُلّم', 'Delivered'),
      'delivered_door' => _('عند الباب', 'At door'),
      'failed' => _('تعذّر', 'Failed'),
      'defer' => _('أُجّل', 'Moved to end'),
      _ => _('سُجّل', 'Saved'),
    };
    return name.isEmpty ? '$verb ${iso(bag)}' : '$verb ${iso(bag)} — $name';
  }

  // ---------- ورقة المشكلة ----------
  String get whatHappened => _('ما الذي حدث؟', 'What happened?');
  String get leftAtDoor => _('تركته عند الباب', 'Left at the door');
  String get leftAtDoorSub => _('بصورة · يُحسب تسليمًا', 'With photo · counts as delivered');
  String get noAnswer => _('لا يردّ على الاتصال', 'Not answering calls');
  String get notCalledYet => _('لم تتصل بعد', "Haven't called yet");
  String get callNow => _('اتصل الآن', 'Call now');
  String get notThere => _('العميل غير متواجد', 'Customer not there');
  String get wrongAddress => _('العنوان غير صحيح', 'Wrong address');
  String get refused => _('رفض الاستلام', 'Refused delivery');
  String get otherReason => _('سبب آخر…', 'Other reason…');
  String get otherReasonHint => _('اكتب السبب', 'Write the reason');
  String get comeBackLater => _('أعود إليه آخر المسار', "I'll come back at the end");
  String get photoAndDeliver => _('صوّر وسلّم', 'Photo & deliver');
  String get confirmFailure => _('تأكيد التعذّر', 'Confirm failure');
  String get moveToEnd => _('أجّله إلى آخر المسار', 'Move to end of route');
  String get undoWithin10 => _('تستطيع التراجع خلال 10 ثوانٍ', 'You can undo within 10 seconds');
  String get writeReason => _('اكتب السبب أوّلًا', 'Write the reason first');

  // ---------- الماسح ----------
  String get scanTitleBags => _('امسح ملصقات الأكياس', 'Scan bag labels');
  String get scanTitleOrg => _('امسح رمز المطعم', 'Scan restaurant code');
  String get scanHintBags => _('وجّه الكاميرا إلى رمز QR على الملصق', 'Point the camera at the QR on the label');
  String get scanHintOrg => _('وجّه الكاميرا إلى رمز QR الذي أعطاك إياه المطعم', 'Point the camera at the QR the restaurant gave you');
  String scanLoaded(String bag) => _('${iso(bag)} حُمّل', '${iso(bag)} loaded');
  String scanAlready(String bag) => _('${iso(bag)} محمّل مسبقًا', '${iso(bag)} already loaded');
  String get scanUnknown => _('هذا الملصق ليس في مسارك', 'This label is not on your route');
  String get scanInvalid => _('ليس ملصق كيس', 'Not a bag label');
  String get cameraDenied => _('لا إذن للكاميرا. افتح الإعدادات واسمح للتطبيق باستعمال الكاميرا لمسح الملصقات.',
      'No camera permission. Open Settings and allow the camera to scan labels.');
  String get torch => _('الكشّاف', 'Flashlight');
  String get cameraError =>_('تعذّر تشغيل الكاميرا', "Couldn't start the camera");

  // ---------- الخريطة ----------
  String get mapUnavailableTitle => _('الخريطة غير متاحة في هذا الإصدار', 'Map unavailable in this build');
  String get mapUnavailableBody => _('لم يُضبط مفتاح الخرائط في هذا البناء. الملاحة تعمل من الأزرار أدناه.',
      'No maps key in this build. Navigation still works from the buttons below.');
  String get openRouteInMaps => _('افتح المسار في خرائط جوجل', 'Open route in Google Maps');
  String get noOpenStops => _('لا محطات مفتوحة', 'No open stops');
  String get myLocation => _('موقعي', 'My location');

  // ---------- المحادثة ----------
  String get chatEmpty => _('لا رسائل بعد. اكتب للعميل أو اختر ردًّا سريعًا.', 'No messages yet. Write or pick a quick reply.');
  String get typeMessage => _('اكتب رسالة…', 'Type a message…');
  String get send => _('إرسال', 'Send');
  String get messageNotSent => _('لم تُرسَل الرسالة', 'Message not sent');
  List<String> get quickReplies => ar
      ? const ['وصلت، أنا عند الباب', 'أنا في الطريق، أصل خلال 10 دقائق', 'لم أجد العنوان، أرسل لي موقعك', 'تركت طلبك عند الباب']
      : const ["I've arrived, I'm at the door", "On my way, there in 10 minutes", "Couldn't find the address, send me your location", 'I left your order at the door'];

  // ---------- السجلّ ----------
  String get thisMonth => _('هذا الشهر', 'This month');
  String get noHistory => _('لا توصيلات في سجلّك بعد', 'No deliveries in your history yet');
  String deliveredAt(String t) => _('سُلّم $t', 'Delivered $t');
  String doorAt(String t) => _('عند الباب · $t', 'At the door · $t');

  // ---------- الحساب ----------
  String get photoPolicy => _('صورة التسليم', 'Delivery photo');
  String get required => _('إلزاميّة', 'Required');
  String get optional => _('اختياريّة', 'Optional');
  String get doorPolicy => _('الترك عند الباب', 'Leave at door');
  String get allowed => _('مسموح', 'Allowed');
  String get notAllowed => _('غير مسموح', 'Not allowed');
  String get settings => _('الإعدادات', 'Settings');
  String get routeNotifications => _('إشعارات المسار', 'Route notifications');
  String get notifToggleFailed => _('تعذّر تغيير الإشعارات — تحقّق من الاتصال والإذن', "Couldn't change notifications — check connection and permission");
  String get language => _('اللغة', 'Language');
  String get appearance => _('المظهر', 'Appearance');
  String get themeSystem => _('تلقائي', 'Auto');
  String get themeLight => _('فاتح', 'Light');
  String get themeDark => _('داكن', 'Dark');
  String get callRestaurant => _('اتصال بالمطعم', 'Call the restaurant');
  String get noSupportPhone => _('لم يضع المطعم رقم تواصل بعد', "The restaurant hasn't added a contact number yet");
  String get demo => _('وضع تجريبي — بيانات وهميّة', 'Demo mode — sample data');
  String version(String v) => _('الإصدار $v', 'Version $v');
  String get signOut => _('تسجيل الخروج', 'Sign out');
  String get signOutConfirm => _('ستحتاج رمز تحقّق جديدًا للدخول', "You'll need a new verification code to sign in");
  String get driverFallback => _('مندوب', 'Driver');

  // ---------- الوقت والتاريخ ----------
  static const _arDays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _enDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _arMonths = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// «8:12 م» — بتوقيت الجهاز.
  String time(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return ar ? '$h:$m ${l.hour < 12 ? 'ص' : 'م'}' : '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  /// «الخميس 2 أكتوبر».
  String longDate(DateTime d) => ar
      ? '${_arDays[d.weekday - 1]} ${d.day} ${_arMonths[d.month - 1]}'
      : '${_enDays[d.weekday - 1]} ${d.day} ${_enMonths[d.month - 1]}';

  /// عنوانُ يومٍ في السجلّ: اليوم · أمس · «الثلاثاء 30 سبتمبر».
  String dayTitle(DateTime d, DateTime today) {
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(today.year, today.month, today.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return this.today;
    if (diff == 1) return yesterday;
    return longDate(a);
  }
}
