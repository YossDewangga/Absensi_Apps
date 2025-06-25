import 'package:absensi_apps/Admin/admin_page.dart';
import 'package:absensi_apps/Company%20Super%20Admin/Company_Super_Page.dart';
import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:absensi_apps/Super%20Admin/super_admin_page.dart';
import 'package:absensi_apps/User/user_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart'; // Tambahkan ini

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('id_ID', null); // Inisialisasi untuk lokal Indonesia
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String role = prefs.getString('role') ?? '';

  runApp(MyApp(isLoggedIn: isLoggedIn, role: role));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String role;

  const MyApp({Key? key, required this.isLoggedIn, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget initialPage;
    if (isLoggedIn) {
      switch (role.toLowerCase().trim()) {
        case 'super admin':
          initialPage = SuperAdminPage();
          break;
        case 'second admin':
        case 'secondadmin':
          initialPage = AdminPage();
          break;
        case 'admin':
          initialPage = CompanySuperAdmin();
          break;
        case 'karyawan':
          initialPage = UserPage();
          break;
        default:
          initialPage = LoginPage();
      }
    } else {
      initialPage = LoginPage();
    }

    return MaterialApp(
      title: 'Absensi Apps',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: initialPage,
    );
  }
}