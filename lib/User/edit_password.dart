import 'package:absensi_apps/Login_Register/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditPasswordPage extends StatefulWidget {
  const EditPasswordPage({Key? key}) : super(key: key);

  @override
  _EditPasswordPageState createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<EditPasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text == _confirmPasswordController.text) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'Pengguna tidak ditemukan.',
          );
        }

        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text.trim(),
        );

        // Reauthenticate user
        await user.reauthenticateWithCredential(credential);

        // Update password in Firebase Authentication
        await user.updatePassword(_newPasswordController.text.trim());

        // Update password in Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'password': _newPasswordController.text.trim(),
        });

        // Show success dialog
        showDialog(
          context: context,
          builder: (context) {
            return const AlertDialog(
              content: Text('Kata sandi telah diperbarui dengan sukses! Silakan masuk kembali.'),
            );
          },
        );

        // Delay for a few seconds before navigating to login page
        await Future.delayed(const Duration(seconds: 2));

        // Sign out the user to apply the new password and force re-authentication
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'wrong-password':
            errorMessage = 'Kata sandi saat ini yang Anda masukkan salah.';
            break;
          case 'user-not-found':
            errorMessage = 'Pengguna tidak ditemukan.';
            break;
          case 'requires-recent-login':
            errorMessage = 'Anda harus login kembali untuk mengubah kata sandi.';
            break;
          default:
            errorMessage = 'Terjadi kesalahan: ${e.message}';
        }
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text(errorMessage),
            );
          },
        );
      }
    } else {
      // Show error dialog if passwords do not match
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            content: Text('Kata sandi baru dan konfirmasi kata sandi tidak cocok.'),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubah Kata Sandi'),
        backgroundColor: Colors.blue[500],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Saat Ini',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _currentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentPasswordVisible = !_currentPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_currentPasswordVisible,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi Baru',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _newPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _newPasswordVisible = !_newPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_newPasswordVisible,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Kata Sandi Baru',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _confirmPasswordVisible = !_confirmPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_confirmPasswordVisible,
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _changePassword,
                  child: const Text('Perbarui Kata Sandi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[500],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
