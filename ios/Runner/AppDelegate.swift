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
    GMSServices.provideAPIKey("AIzaSyCzYsVCdvxN-F3RmfC1p-dfFW8SRB1YgH0")

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
