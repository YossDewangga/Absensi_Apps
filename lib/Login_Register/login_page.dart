import 'package:absensi_apps/Admin/admin_page.dart';
import 'package:absensi_apps/Company%20Super%20Admin/Company_Super_Page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../User/user_page.dart';
import 'forgot_password_page.dart';
import '../Components/my_button.dart';
import 'package:absensi_apps/Super%20Admin/super_admin_page.dart';

class LoginPage extends StatefulWidget {
  final Function()? onTap;
  const LoginPage({Key? key, this.onTap}) : super(key: key);

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
      _showErrorMessage('Harap isi semua kolom');
      return;
    }

    // Menampilkan loading spinner
    showDialog(
      context: context,
      builder: (context) {
        return const Center(
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
          String role = userData.data()!['role'] ?? 'unknown';
          print("Detected role from Firestore: $role"); // Debugging

          // Simpan status login ke SharedPreferences
          _saveLoginStatus(true, role);

          // Perbarui status login di Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'isLoggedIn': true,
          });

          // Navigasi berdasarkan peran pengguna
          final roleLower = role.toLowerCase().trim();
          if (roleLower == 'super admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SuperAdminPage()),
            );
          } else if (roleLower == 'second admin' || roleLower == 'secondadmin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminPage()),
            );
          } else if (roleLower == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CompanySuperAdmin()),
            );
          } else if (roleLower == 'karyawan') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserPage()),
            );
          } else {
            _showErrorMessage('Role tidak dikenali: $role');
          }
        } else {
          _showErrorMessage('Data pengguna tidak ditemukan');
        }
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      if (mounted) {
        if (e.code == 'user-not-found') {
          _showErrorMessage('Email salah');
        } else if (e.code == 'wrong-password') {
          _showErrorMessage('Kata sandi salah');
        } else {
          _showErrorMessage('Terjadi kesalahan: ${e.code}');
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
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;
    double logoHeight = screenHeight * 0.28;
    double logoWidth = screenWidth * 0.5;
    double tpiLogoHeight = screenHeight * 0.13;
    double tpiLogoWidth = screenWidth * 0.28;
    double inputFontSize = 18;
    double inputPadding = screenWidth * 0.08;
    double buttonFontSize = 20;
    double buttonPadding = 20;
    double verticalSpace = 24;

    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/absensi.png',
                height: logoHeight,
                width: logoWidth,
                fit: BoxFit.contain,
              ),
              SizedBox(height: verticalSpace),
              Text(
                'Selamat datang kembali!',
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: verticalSpace),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inputPadding),
                child: TextField(
                  controller: emailController,
                  style: TextStyle(fontSize: inputFontSize),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade900),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    hintText: 'Email',
                    hintStyle: TextStyle(fontSize: inputFontSize, color: Colors.grey[500]),
                    fillColor: Colors.grey[200],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inputPadding),
                child: TextFormField(
                  controller: passwordController,
                  obscureText: _isObscure,
                  style: TextStyle(fontSize: inputFontSize),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal.shade900),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    hintText: 'Kata Sandi',
                    hintStyle: TextStyle(fontSize: inputFontSize, color: Colors.grey[500]),
                    fillColor: Colors.grey[200],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.teal.shade900,
                      ),
                      onPressed: toggleObscure,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inputPadding),
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
                        'Lupa Kata Sandi?',
                        style: TextStyle(
                          color: Colors.teal.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: verticalSpace),
              MyButton(
                text: "Masuk",
                onTap: signUserIn,
                fontSize: buttonFontSize,
                verticalPadding: buttonPadding,
              ),
              SizedBox(height: screenHeight * 0.08),
              Image.asset(
                'assets/images/Logo TPI web.png',
                height: tpiLogoHeight,
                width: tpiLogoWidth,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyButton extends StatelessWidget {
  final String text;
  final Function()? onTap;
  final double fontSize;
  final double verticalPadding;

  const MyButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.fontSize = 18,
    this.verticalPadding = 15,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.18),
        decoration: BoxDecoration(
          color: Colors.teal.shade900,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}