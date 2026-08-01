import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:tubitak/Pages/LoginPage.dart';
import 'package:tubitak/services/local_notifications.dart';
import 'package:tubitak/widgets/app_animations.dart';
import 'firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("📩 Background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  //Local notifications init
  await LocalNotifs.instance.init();
  //FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    //Uygulama açıkken gelen push'u ekranda göstermek için
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? "Bildirim";
      final body = message.notification?.body ?? "";
      LocalNotifs.instance.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tubitak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: SoftPageTransitionsBuilder(),
            TargetPlatform.iOS: SoftPageTransitionsBuilder(),
            TargetPlatform.windows: SoftPageTransitionsBuilder(),
            TargetPlatform.macOS: SoftPageTransitionsBuilder(),
            TargetPlatform.linux: SoftPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginPage(),
    );
  }
}
