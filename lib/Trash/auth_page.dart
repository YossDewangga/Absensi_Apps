import 'package:absensi_apps/Admin/admin_page.dart';
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
    String role = prefs.getString('role') ?? '';
    User? user = FirebaseAuth.instance.currentUser;

    if (isLoggedIn && user != null) {
      DocumentSnapshot<Map<String, dynamic>> userData =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userData.exists && userData.data()!['isLoggedIn'] == true) {
        if (role == 'Admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => AdminPage()),
                (Route<dynamic> route) => false,
          );
        } else if (role == 'Karyawan') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => UserPage()),
                (Route<dynamic> route) => false,
          );
        }
      } else {
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
        child: CircularProgressIndicator(),
      ),
    );
  }
}
