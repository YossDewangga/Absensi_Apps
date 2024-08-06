import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Login_Register/login_page.dart';

Future<void> logout(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    print('User ID: ${user.uid}'); // Logging user ID
    // Update Firestore dan tunggu sampai selesai
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'isLoggedIn': false,
    }).then((value) async {
      print('isLoggedIn diatur ke false'); // Logging sukses
      await FirebaseAuth.instance.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }).catchError((error) {
      // Tangani kesalahan, mungkin tampilkan Snackbar atau Dialog
      print('Gagal memperbarui isLoggedIn: $error'); // Logging kesalahan
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout gagal: $error')),
      );
    });
  } else {
    print('Tidak ada pengguna yang masuk'); // Logging jika tidak ada pengguna yang masuk
  }
}

void showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Konfirmasi Logout'),
        content: Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Menutup dialog
            },
            child: Text('Tidak'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Menutup dialog
              logout(context);
            },
            child: Text('Ya'),
          ),
        ],
      );
    },
  );
}