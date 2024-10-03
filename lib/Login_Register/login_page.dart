import 'package:absensi_apps/Admin/admin_absensi.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isObscure = true;

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

    // Menampilkan loading spinner
    showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Otentikasi pengguna menggunakan Firebase
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      User? user = userCredential.user;

      // Menghilangkan dialog spinner setelah login berhasil
      Navigator.pop(context);

      if (mounted && user != null) {
        // Mendapatkan data pengguna dari Firestore
        DocumentSnapshot<Map<String, dynamic>> userData =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userData.exists) {
          String role = userData.data()!['role'];

          // Simpan status login ke SharedPreferences
          _saveLoginStatus(true, role);

          // Perbarui status login di Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'isLoggedIn': true,
          });

          // Navigasi berdasarkan peran pengguna
          if (role == 'Admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminAbsensiPage()),
            );
          } else if (role == 'Karyawan') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserPage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
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

  // Fungsi untuk menyimpan status login ke SharedPreferences
  void _saveLoginStatus(bool isLoggedIn, String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('role', role);
  }

  // Fungsi untuk menampilkan pesan error
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
    // Menggunakan MediaQuery untuk mendapatkan ukuran layar
    var screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/absensi.png',
              height: screenWidth * 0.2, // Sesuaikan ukuran berdasarkan lebar layar
              width: screenWidth * 0.4,
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
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.15), // Sesuaikan padding
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
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
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.15), // Sesuaikan padding
              child: TextFormField(
                controller: passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  hintText: 'Password',
                  fillColor: Colors.grey[200],
                  filled: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscure ? Icons.visibility : Icons.visibility_off,
                      color: _isObscure ? Colors.teal.shade900 : Colors.teal.shade900,
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
            SizedBox(height: 100),
            Image.asset(
              'assets/images/Logo TPI web.png',
              height: screenWidth * 0.1, // Sesuaikan ukuran berdasarkan lebar layar
              width: screenWidth * 0.2,
              fit: BoxFit.fill,
            ),
          ],
        ),
      ),
    );
  }
}

// Widget MyButton yang sudah disesuaikan
class MyButton extends StatelessWidget {
  final String text;
  final Function()? onTap;

  const MyButton({
    Key? key,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15),
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.2), // Sesuaikan margin
        decoration: BoxDecoration(
          color: Colors.teal.shade900,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
