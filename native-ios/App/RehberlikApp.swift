import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import FirebaseFirestore
import FirebaseFunctions
import UserNotifications

@main
struct RehberlikApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .task { await store.start() }
                .onReceive(NotificationCenter.default.publisher(for: .nativeTokenChanged)) { _ in
                    Task { await store.syncDevice() }
                }
                .onReceive(NotificationCenter.default.publisher(for: .nativeNotificationOpened)) { notification in
                    store.openNotification(notification.userInfo)
                }
        }
    }
}
extension Notification.Name {
    static let nativeTokenChanged = Notification.Name("nativeTokenChanged")
    static let nativeNotificationOpened = Notification.Name("nativeNotificationOpened")
}
final class NotificationInbox {
    static let shared = NotificationInbox()
    var pending: [AnyHashable: Any]?
}
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard !ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return true }
        // Firebase client identifiers are public configuration, never server credentials.
        let config=FirebaseOptions(googleAppID:"1:939453696359:ios:3fb7a7da7e2b1be63dc7c2",gcmSenderID:"939453696359")
        config.apiKey="AIzaSyC7D0Wkq2YFvviAkfBVhm07Bi9QbLa6984"
        config.projectID="tubitak-86d68"; config.bundleID="com.tubitak.tubitak"
        config.storageBucket="tubitak-86d68.firebasestorage.app"
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-emulator-testing") {config.projectID="demo-rehberlik"}
        #endif
        FirebaseApp.configure(options:config)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-emulator-testing") {
            // Explicit debug-only integration mode; never connects test accounts to production.
            Auth.auth().useEmulator(withHost:"127.0.0.1",port:9099)
            let settings=Firestore.firestore().settings
            settings.host="127.0.0.1:8080";settings.isSSLEnabled=false
            Firestore.firestore().settings=settings
            Functions.functions(region:"europe-west1").useEmulator(withHost:"127.0.0.1",port:5001)
        }
        #endif
        UNUserNotificationCenter.current().delegate=self
        Messaging.messaging().delegate=self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Messaging.messaging().apnsToken=token
        NotificationCenter.default.post(name:.nativeTokenChanged,object:nil)
    }
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async { NotificationCenter.default.post(name:.nativeTokenChanged,object:nil) }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completion: @escaping (UNNotificationPresentationOptions)->Void) {
        completion([.banner,.sound,.badge])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completion: @escaping ()->Void) {
        let payload=response.notification.request.content.userInfo
        DispatchQueue.main.async {
            NotificationInbox.shared.pending=payload
            NotificationCenter.default.post(name:.nativeNotificationOpened,object:nil,userInfo:payload)
        }
        completion()
    }
}
