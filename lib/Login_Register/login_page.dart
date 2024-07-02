import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Admin/admin_page.dart';
import '../User/user_page.dart';
import 'forgot_password_page.dart';
import '../Components/my_button.dart';

class LoginPage extends StatefulWidget {
  final Function()? onTap;
  const LoginPage({Key? key, this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isObscure = true; // State untuk mengontrol apakah password tersembunyi atau tidak

  void toggleObscure() {
    setState(() {
      _isObscure = !_isObscure;
    });
  }

  void signUserIn() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorMessage('Please fill in all fields');
      return;
    }

    // Tampilkan dialog loading
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      // Dapatkan pengguna yang masuk
      User? user = userCredential.user;

      // Tutup dialog loading
      Navigator.pop(context);

      // Periksa apakah State masih aktif sebelum melakukan navigasi
      if (mounted) {
        // Periksa peran pengguna dan navigasikan ke halaman yang sesuai
        if (user != null) {
          DocumentSnapshot<Map<String, dynamic>> userData =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (userData.exists) {
            String role = userData.data()!['role'];

            if (role == 'Admin') {
              // Navigasi ke halaman admin jika peran adalah admin
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AdminPage()),
              );
            } else if (role == 'Karyawan') {
              // Navigasi ke halaman karyawan jika peran adalah karyawan
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => UserPage()),
              );
            }
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      // Tutup dialog loading terlebih dahulu
      Navigator.pop(context);
      // Periksa apakah State masih aktif sebelum menampilkan pesan error
      if (mounted) {
        if (e.code == 'user-not-found') {
          _showErrorMessage('Incorrect Email');
        } else if (e.code == 'wrong-password') {
          _showErrorMessage('Incorrect Password');
        } else {
          _showErrorMessage('An error occurred');
        }
      }
    }
  }

  void _showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Menghapus properti title agar tidak ada teks di AppBar
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/absensi.png',
              height: 200,
              width: 400,
              fit: BoxFit.fill,
            ),
            Text(
              'Welcome back, you\'ve been missed!',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10.0),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  hintText: 'Username',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
            ),
            SizedBox(height: 10.0),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: TextFormField(
                controller: passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  hintText: 'Password',
                  fillColor: Colors.grey[200],
                  filled: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility : Icons.visibility_off,
                      color: _isObscure ? Colors.grey : Colors.blueAccent,
                    ),
                    onPressed: toggleObscure,
                  ),
                ),
              ),
            ),
            SizedBox(height: 15),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return ForgotPasswordPage();
                          },
                        ),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),

            MyButton(
              text: "Sign In",
              onTap: signUserIn,
            ),
            SizedBox(height: 65),

            Image.asset(
              'assets/images/Logo TPI web.png',
              height: 70,
              width: 150,
              fit: BoxFit.fill,
            ),
          ],
        ),
      ),
    );
  }
}
