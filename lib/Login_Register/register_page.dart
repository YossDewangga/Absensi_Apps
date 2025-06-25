import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  final Function()? onRegister;

  const RegisterPage({Key? key, this.onRegister}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Kontroler untuk menangkap input pengguna
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController userIdController = TextEditingController(); // Untuk Company Name
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  String? selectedDepartment;
  User? user;

  // Status UI
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String selectedRole = 'Admin'; // Nilai default untuk dropdown role
  String? adminCompanyName; // Untuk menyimpan Company Name dari admin

  @override
  void initState() {
    super.initState();
    _fetchAdminCompanyName();
  }

  Future<void> _fetchAdminCompanyName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          adminCompanyName = userData['Company Name'] ?? 'TES'; // Fallback ke 'TES' jika kosong
          userIdController.text = adminCompanyName!;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    userIdController.dispose();
    firstnameController.dispose();
    lastnameController.dispose();
    super.dispose();
  }

  Future<void> signUserUp() async {
    if (!mounted) return;

    if (userIdController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty ||
        firstnameController.text.isEmpty ||
        lastnameController.text.isEmpty ||
        selectedDepartment == null ||
        selectedRole == null) {
      _showErrorMessage('Semua field harus diisi!');
      return;
    }

    if (userIdController.text.length < 3) {
      _showErrorMessage('Nama perusahaan harus minimal 3 karakter!');
      return;
    }

    if (userIdController.text.length > 50) {
      _showErrorMessage('Nama perusahaan maksimal 50 karakter!');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
      _showErrorMessage('Alamat email tidak valid!');
      return;
    }

    if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).{6,}$').hasMatch(passwordController.text)) {
      _showErrorMessage('Kata sandi harus minimal 6 karakter, mengandung huruf besar dan angka!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (passwordController.text == confirmPasswordController.text) {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );

        user = userCredential.user;

        String fullName = '${firstnameController.text} ${lastnameController.text}';
        await user!.updateProfile(displayName: fullName);

        String userId = user!.uid;
        await postDetailsToFirestore(userId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun berhasil dibuat!'),
            duration: Duration(seconds: 5),
          ),
        );

        emailController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
        firstnameController.clear();
        lastnameController.clear();
        setState(() {
          selectedDepartment = null;
          selectedRole = 'Admin';
          userIdController.text = adminCompanyName ?? 'TES'; // Kembalikan ke Company Name admin
        });
      } else {
        _showErrorMessage("Kata sandi tidak cocok!");
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email sudah digunakan oleh akun lain';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Alamat email tidak valid';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Kata sandi terlalu lemah';
      }
      _showErrorMessage(errorMessage);
    } catch (e) {
      _showErrorMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> postDetailsToFirestore(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'Company Name': userIdController.text,
        'First Name': firstnameController.text,
        'Last Name': lastnameController.text,
        'Email': emailController.text,
        'role': selectedRole,
        'department': selectedDepartment,
        'displayName': '${firstnameController.text} ${lastnameController.text}',
      });
      print('Data pengguna berhasil ditambahkan ke Firestore');
    } catch (e) {
      print('Gagal menambahkan data pengguna ke Firestore: $e');
      _showErrorMessage('Gagal menambahkan data pengguna ke Firestore');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 20.0),
              Text(
                'Mari buat akun untuk Anda!',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10.0),

              // TextField untuk Company Name (tidak dapat diedit)
              TextField(
                controller: userIdController,
                enabled: false,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Nama Perusahaan',
                  hintText: adminCompanyName ?? 'TES',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              SizedBox(height: 10.0),

              // TextField untuk Nama Depan
              TextField(
                controller: firstnameController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Nama Depan',
                  hintText: 'Masukkan Nama Depan',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              SizedBox(height: 10.0),

              // TextField untuk Nama Belakang
              TextField(
                controller: lastnameController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Nama Belakang',
                  hintText: 'Masukkan Nama Belakang',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              SizedBox(height: 10.0),

              // Dropdown untuk Role
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Role',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
                value: selectedRole,
                items: <String>['Admin', 'SecondAdmin', 'Karyawan'].map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedRole = newValue!;
                  });
                },
              ),
              SizedBox(height: 10.0),

              // Dropdown untuk Departemen
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Departemen',
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
                value: selectedDepartment,
                items: <String>[
                  'Direktur',
                  'Purchasing',
                  'Finance',
                  'Account Manager',
                  'Marketing',
                  'Mobile Apps Development',
                  'Technical Support',
                ].map((String department) {
                  return DropdownMenuItem<String>(
                    value: department,
                    child: Text(department),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedDepartment = newValue;
                  });
                },
              ),
              SizedBox(height: 10.0),

              // TextField untuk Email
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Email',
                  hintText: 'Masukkan Email',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              SizedBox(height: 10.0),

              // TextField untuk Kata Sandi
              TextField(
                obscureText: !_isPasswordVisible,
                controller: passwordController,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Kata Sandi',
                  hintText: 'Masukkan Kata Sandi',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              SizedBox(height: 10.0),

              // TextField untuk Konfirmasi Kata Sandi
              TextField(
                obscureText: !_isConfirmPasswordVisible,
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Konfirmasi Kata Sandi',
                  hintText: 'Masukkan Konfirmasi Kata Sandi',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              SizedBox(height: 20.0),

              // Tombol Register
              ElevatedButton(
                onPressed: _isLoading ? null : signUserUp,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Register'),
              ),
              SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}