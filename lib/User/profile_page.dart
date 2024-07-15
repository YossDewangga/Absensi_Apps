import 'package:absensi_apps/Admin/admin_password.dart';
import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
                        // Add action for edit profile
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
                      // Add action for settings
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
                      child: Icon(Icons.help_outline, color: Colors.black),
                    ),
                    title: Text('Help & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Add action for help & support
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
                    onTap: () async {
                      final user = FirebaseAuth.instance.currentUser;

                      if (user != null) {
                        print('User ID: ${user.uid}'); // Logging user ID
                        // Update Firestore and wait for it to complete
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                          'isLoggedIn': false,
                        }).then((value) async {
                          print('isLoggedIn set to false'); // Logging success
                          await FirebaseAuth.instance.signOut();
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => LoginPage()),
                          );
                        }).catchError((error) {
                          // Handle the error, maybe show a Snackbar or Dialog
                          print('Failed to update isLoggedIn: $error'); // Logging error
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Logout failed: $error')),
                          );
                        });
                      } else {
                        print('No user signed in'); // Logging if no user is signed in
                      }
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
