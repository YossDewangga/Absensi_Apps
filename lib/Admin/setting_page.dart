import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Lend App/lend_app.dart';
import 'admin_password.dart';  // Ganti dengan path halaman edit password yang sesuai

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                      backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null ? Icon(Icons.person, size: 50, color: Colors.black) : null,
                    ),
                    SizedBox(height: 10),
                    Text(
                      user?.displayName ?? 'User',
                      style: TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Tambahkan aksi untuk edit profil
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
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
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.settings, color: Colors.black),
                    ),
                    title: Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Tambahkan aksi untuk settings
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.all_inclusive, color: Colors.black), // Ganti ikon jika perlu
                    ),
                    title: Text('Lend App', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context)=> LendAppPage()),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.password, color: Colors.black),
                    ),
                    title: Text('Edit Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditPasswordPage()),
                      );
                    },
                  ),
                  Divider(),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.logout, color: Colors.black),
                    ),
                    title: Text('Logout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      showLogoutDialog(context); // Panggil dialog konfirmasi logout
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              logout(context); // Panggil fungsi logout
            },
            child: Text('Ya'),
          ),
        ],
      );
    },
  );
}

Future<void> logout(BuildContext context) async {
  try {
    // Logout dari Firebase
    await FirebaseAuth.instance.signOut();

    // Clear SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigasi ke halaman login dan hapus semua halaman sebelumnya
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
    );
  } catch (error) {
    print('Gagal logout: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logout gagal: $error')),
    );
  }
}
