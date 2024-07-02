import 'dart:developer';

import 'package:absensi_apps/Admin/admin_page.dart';
import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:absensi_apps/User/user_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones(); // Inisialisasi timezone
  await _requestNotificationPermission(); // Meminta izin notifikasi
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
      home: UserPage(),
    );
  }
}
