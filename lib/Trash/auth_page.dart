import 'package:absensi_apps/Admin/absensi_admin.dart';
import 'package:absensi_apps/Admin/admin_page.dart';
import 'package:absensi_apps/Company%20Super%20Admin/Company_Super_Page.dart';
import 'package:absensi_apps/Super%20Admin/super_admin_page.dart';
import 'package:absensi_apps/Company%20Super%20Admin/admin_absensi.dart';
import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:absensi_apps/User/user_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckLoginStatus extends StatefulWidget {
  @override
  _CheckLoginStatusState createState() => _CheckLoginStatusState();
}

class _CheckLoginStatusState extends State<CheckLoginStatus> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String role = prefs.getString('role')?.toLowerCase() ?? ''; // Ubah ke huruf kecil untuk konsistensi
    User? user = FirebaseAuth.instance.currentUser;

    if (isLoggedIn && user != null) {
      try {
        DocumentSnapshot<Map<String, dynamic>> userData =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userData.exists && userData.data()!['isLoggedIn'] == true) {
          if (role == 'super admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SuperAdminPage()),
            );
          } else if (role == 'secondadmin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminPage()),
            );
          } else if (role == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CompanySuperAdmin()),
            );
          } else if (role == 'karyawan') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserPage()),
            );
          } else {
            await prefs.setBool('isLoggedIn', false); // Reset jika role tidak dikenali
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          }
        } else {
          await prefs.setBool('isLoggedIn', false); // Reset jika data tidak valid
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        }
      } catch (e) {
        print('Error fetching user data: $e');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.teal),
      ),
    );
  }
}