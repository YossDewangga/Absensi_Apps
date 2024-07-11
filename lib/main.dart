import 'package:absensi_apps/Admin/admin_page.dart';
import 'package:absensi_apps/Trash/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    int remainingTime = prefs.getInt('remainingTime') ?? 0;

    if (remainingTime > 0) {
      remainingTime--;
      await prefs.setInt('remainingTime', remainingTime);
    }

    return Future.value(true);
  });
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Jika pesan diterima saat aplikasi di background
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  tz.initializeTimeZones(); // Inisialisasi timezone
  await _requestNotificationPermission(); // Meminta izin notifikasi
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set ke false untuk release mode
  );
  runApp(MyApp());
}

Future<void> _requestNotificationPermission() async {
  if (await Permission.notification.request().isGranted) {
    print('Notification permission granted');
  } else {
    print('Notification permission denied');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: CheckLoginStatus(), // Ganti dengan halaman login atau halaman sesuai peran
    );
  }
}
