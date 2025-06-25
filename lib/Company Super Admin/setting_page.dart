// File: lib/User/profile_page.dart
import 'package:absensi_apps/Company%20Super%20Admin/admin_password.dart';
import 'package:absensi_apps/Company%20Super%20Admin/save_office_location_page.dart';
import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.teal.shade50, // Consistent with CompanyInfoSalary, AdminAbsensi
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade900, // Consistent teal theme
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null
          ? const Center(child: Text('No user logged in', style: TextStyle(color: Colors.teal)))
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                            child: user.photoURL == null
                                ? const Icon(Icons.person, size: 50, color: Colors.teal)
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user.email ?? 'No email',
                            style: const TextStyle(fontSize: 16, color: Colors.teal),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              // TODO: Implement Edit Profile functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Edit Profile not implemented yet')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.teal.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                              child: Text('Edit Profile', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.settings, color: Colors.teal),
                          ),
                          title: const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                  
                        ),
                        const Divider(color: Colors.teal),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.password, color: Colors.teal),
                          ),
                          title: const Text('Edit Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditPasswordPage()),
                            );
                          },
                        ),
                        const Divider(color: Colors.teal),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.logout, color: Colors.teal),
                          ),
                          title: const Text('Logout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                          onTap: () {
                            showLogoutDialog(context);
                          },
                        ),
                        const Divider(color: Colors.teal),
                        const SizedBox(height: 150),
                        const Center(
                          child: Text(
                            'version 1.0',
                            style: TextStyle(fontSize: 16, color: Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout', style: TextStyle(color: Colors.teal)),
          content: const Text('Apakah Anda yakin ingin logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tidak', style: TextStyle(color: Colors.teal)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                logout(context);
              },
              child: const Text('Ya', style: TextStyle(color: Colors.teal)),
            ),
          ],
        );
      },
    );
  }

  Future<void> logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      print('Gagal logout: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout gagal: $error')),
      );
    }
  }
}