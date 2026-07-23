import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// لغة التطبيق ('ar' | 'en') — تُحفظ محليًّا وتنعكس فورًا على الواجهة والاتجاه.
class LocaleNotifier extends Notifier<String> {
  static const _key = 'app_lang';

  @override
  String build() {
    _load();
    return 'ar';
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString(_key);
    if (v == 'en' && state != 'en') state = 'en';
  }

  Future<void> set(String lang) async {
    state = lang;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, lang);
  }

  Future<void> toggle() => set(state == 'ar' ? 'en' : 'ar');
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(LocaleNotifier.new);

/// نصوص الواجهة — كل نص بالعربية والإنجليزية معًا.
final stringsProvider = Provider<L>((ref) => L(ref.watch(localeProvider) == 'ar'));

class L {
  final bool ar;
  const L(this.ar);

  String _(String a, String e) => ar ? a : e;

  // ---------- عام ----------
  String get customer => _('العميل', 'Customer');
  String get driverFallback => _('مندوب', 'Driver');
  String get preferredDelivery => _('التوصيل المفضّل', 'Preferred time');
  String get today => _('اليوم', 'Today');

  // ---------- التنقّل ----------
  String get navHome => _('الرئيسية', 'Home');
  String get navPickup => _('الاستلام', 'Pickup');
  String get navCustomers => _('العملاء', 'Customers');
  String get navHistory => _('السجل', 'History');
  String get navProfile => _('حسابي', 'Profile');

  // ---------- خطوات التوصيل ----------
  String get stepPickup => _('الاستلام', 'Pickup');
  String get stepEnroute => _('التوجّه', 'En route');
  String get stepDeliver => _('التسليم', 'Deliver');

  // ---------- حالات الطلب ----------
  String statusLabel(OrderStatus s) => switch (s) {
        OrderStatus.preparing => _('قيد التحضير', 'Preparing'),
        OrderStatus.ready => _('جاهزة للاستلام', 'Ready for pickup'),
        OrderStatus.picked => _('تم الاستلام', 'Picked up'),
        OrderStatus.enroute => _('في الطريق', 'On the way'),
        OrderStatus.delivered => _('تم التسليم', 'Delivered'),
        OrderStatus.failed => _('تعذّر', 'Failed'),
      };

  // ---------- الدخول ----------
  String get loginSubtitle => _('سجّل الدخول لبدء مناوبتك', 'Sign in to start your shift');
  String get loginOtpSubtitle => _('أدخل رمز التحقّق المُرسَل إليك', 'Enter the verification code sent to you');
  String get orgCode => _('رمز المؤسسة', 'Restaurant code');
  String get phoneNumber => _('رقم الجوال', 'Phone number');
  String get sendOtp => _('إرسال رمز التحقّق', 'Send verification code');
  String get sending => _('جارٍ الإرسال…', 'Sending…');
  String get otpBySms => _('يصلك الرمز برسالة نصّية', 'You will receive the code by SMS');
  String sentTo(String to) => _('أُرسل إلى $to', 'Sent to $to');
  String get otp => _('رمز التحقّق', 'Verification code');
  String get signIn => _('دخول', 'Sign in');
  String get verifying => _('جارٍ التحقّق…', 'Verifying…');
  String get changeNumber => _('تغيير الرقم', 'Change number');
  String get enterOrgAndPhone => _('أدخل رمز المؤسسة ورقم الجوال', 'Enter the restaurant code and phone number');
  String get enterOtp => _('أدخل رمز التحقّق', 'Enter the verification code');
  String get welcome => _('أهلاً بك 👋', 'Welcome 👋');
  String get askName => _('ما اسمك؟ سيظهر لفريق المطعم في الداشبورد.', 'What is your name? It will appear to the restaurant team.');
  String get fullName => _('اسمك الكامل', 'Your full name');
  String get later => _('لاحقًا', 'Later');
  String get save => _('حفظ', 'Save');
  String get nameSavedLocally => _('حُفظ الاسم محليًّا (تعذّر إرساله للخادم)', 'Name saved locally (could not reach server)');

  // ---------- الرئيسية ----------
  String get greeting => _('أهلًا 👋', 'Hello 👋');
  String get deliveryStaff => _('موظف توصيل', 'Delivery staff');
  String get todaysOrders => _('طلبات اليوم', "Today's orders");
  String get deliveredStat => _('تم التسليم', 'Delivered');
  String get remainingStat => _('متبقٍ', 'Remaining');
  String get activeOrders => _('طلبات نشطة', 'Active orders');
  String get viewAll => _('عرض الكل', 'View all');
  String get noActiveOrders => _('لا طلبات نشطة حالياً 🎉', 'No active orders right now 🎉');

  // ---------- الاستلام ----------
  String get kitchenPickup => _('استلام من المطبخ', 'Kitchen pickup');
  String get noOrdersToPick => _('لا طلبات بانتظار الاستلام', 'No orders awaiting pickup');
  String get confirmPickup => _('تأكيد الاستلام', 'Confirm pickup');
  String pickedUpOrder(String name) => _('تم استلام طلب $name', "Picked up $name's order");
  String get done => _('تم', 'Done');

  // ---------- العملاء ----------
  String get deliveryCustomers => _('عملاء التوصيل', 'Delivery customers');
  String get allDeliveriesDone => _('أنهيت جميع التوصيلات 👏', 'All deliveries completed 👏');
  String get next => _('التالي', 'Next');
  String get waiting => _('بالانتظار', 'Waiting');
  String get confirmEnroute => _('تأكيد التوجّه', 'Start delivery');
  String calling(String name) => _('جارٍ الاتصال بـ $name', 'Calling $name');

  // ---------- المحادثة ----------
  String orderNo(String id) => _('طلب #$id', 'Order #$id');
  String get onlineNow => _('متصلة الآن', 'Online now');
  String get typeMessage => _('اكتب رسالة…', 'Type a message…');
  String messageFrom(String name) => _('رسالة من $name', 'Message from $name');

  // ---------- الخريطة ----------
  String get broadcastingLocation => _('يبثّ موقعك للعميل', 'Broadcasting your location');
  String get openInGoogleMaps => _('فتح في خرائط جوجل', 'Open in Google Maps');
  String get arrivedDeliver => _('وصلتُ — تسليم الطلب', 'Arrived — deliver order');

  // ---------- التسليم ----------
  String get confirmDelivery => _('تأكيد التسليم', 'Confirm delivery');
  String get deliveryPhoto => _('صورة التسليم ', 'Delivery photo ');
  String get required => _('(إلزامية)', '(required)');
  String get tapToCapture => _('اضغط لالتقاط صورة', 'Tap to take a photo');
  String get photoAtDoor => _('صورة الطلب عند باب العميل', "Photo of the order at the customer's door");
  String get retake => _('إعادة الالتقاط', 'Retake');
  String get cantDeliver => _('تعذّر التسليم؟ اختر السبب', "Can't deliver? Choose a reason");
  List<String> get failReasons => ar
      ? const ['العميل غير متواجد', 'لا يرد على الاتصال', 'عنوان غير صحيح', 'رفض استلام الطلب']
      : const ['Customer not available', 'Not answering calls', 'Wrong address', 'Refused the order'];
  String get saving => _('جارٍ الحفظ…', 'Saving…');
  String get enabledAfterPhoto => _('يتم التفعيل بعد إضافة صورة التسليم', 'Enabled after adding the delivery photo');
  String deliveredOrder(String name) => _('تم تسليم طلب $name ✅', "Delivered $name's order ✅");
  String get failureRecorded => _('سُجّل تعذّر التسليم', 'Delivery failure recorded');
  String get confirmFailed => _('تعذّر تأكيد التسليم — حاول مجددًا', 'Could not confirm — try again');
  String get saveFailed => _('تعذّر الحفظ — حاول مجددًا', 'Could not save — try again');

  // ---------- السجل ----------
  String get completedOrders => _('سجل الطلبات المكتملة', 'Completed orders');
  String get thisMonth => _('هذا الشهر', 'This month');
  String get deliveredLabel => _('تم التسليم', 'Delivered');
  String get failedLabel => _('تعذّر', 'Failed');

  // ---------- حسابي ----------
  String get connectionStatus => _('حالة الاتصال بالمطعم', 'Restaurant connection');
  String get connected => _('متصل', 'Connected');
  String get demo => _('تجريبي', 'Demo');
  String get settings => _('الإعدادات', 'Settings');
  String get newOrderNotifications => _('إشعارات الطلبات الجديدة', 'New order notifications');
  String get language => _('اللغة', 'Language');
  String get languageValue => _('العربية ›', 'English ›');
  String get helpSupport => _('المساعدة والدعم', 'Help & support');
  String get callRestaurant => _('اتصال بالمطعم ›', 'Call restaurant ›');
  String get restaurantSupport => _('دعم المطعم', 'Restaurant support');
  String get callSupport => _('اتصال بالدعم', 'Call support');
  String get noSupportPhone => _(
      'لم يُسجَّل رقم دعم للمطعم بعد — يُضاف من لوحة التحكّم (إعدادات المطعم → رقم التواصل)',
      'No support number registered yet — add it in the dashboard (Restaurant settings → contact phone)');
  String get signOut => _('تسجيل الخروج', 'Sign out');
}
