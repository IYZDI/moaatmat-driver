import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // نفس مفتاح خرائط Google المستخدم في تطبيق العميل (مقيّد بحِزم التطبيقات)
    // المفتاحُ من Info.plist لا مثبَّتًا هنا — يُكتب وقت البناء من
    // MAPS_API_KEY. وكان مكتوبًا نصًّا والمستودعُ منشور.
    //
    // ⚠ وبلا مفتاحٍ لا نُمرّر سلسلةً فارغة: `provideAPIKey("")` تُسجّل خطأً
    //   عند كلّ إقلاع بلا فائدة. تُترك المكتبةُ بلا تهيئة، و**الحارسُ في
    //   Dart** (`Env.hasMaps`) هو ما يمنع إنشاءَ GMSMapView — فبدونه
    //   ينهار التطبيقُ بـGMSServicesException، وهو انهيارٌ أصليٌّ لا يظهر
    //   في أخطاء Flutter إطلاقًا.
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.trimmingCharacters(in: .whitespaces).isEmpty {
      GMSServices.provideAPIKey(key)
    } else {
      NSLog("لا مفتاح خرائط في Info.plist — GMS بلا تهيئة. الحارس في Dart يمنع إنشاء الخريطة.")
    }

    // تهيئة Firebase هنا (قبل تشغيل Flutter) ضرورية للإشعارات: النظام يُصدر
    // رمز APNs لحظة الإقلاع، والتهيئة من Dart تأتي متأخرة فلا يُلتقط الرمز
    // (خطأ apns-token-not-set). الملف يُولَّد وقت البناء؛ فإن غاب نتخطّى بأمان.
    if FirebaseApp.app() == nil,
       Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
      FirebaseApp.configure()
      application.registerForRemoteNotifications()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
