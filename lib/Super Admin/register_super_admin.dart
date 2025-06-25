import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterSuperAdmin extends StatefulWidget {
  final Function()? onRegister;

  const RegisterSuperAdmin({Key? key, this.onRegister}) : super(key: key);

  @override
  State<RegisterSuperAdmin> createState() => _RegisterSuperAdminState();
}

class _RegisterSuperAdminState extends State<RegisterSuperAdmin> {
  // Kontroler untuk menangkap input pengguna
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController(); // Untuk Company Name
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  String? selectedDepartment;
  String? selectedRole; // Tidak ada default value
  User? user;

  // Status UI
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Daftar opsi role
  final List<String> roles = ['Admin'];

  @override
  void dispose() {
    // Bersihkan kontroler untuk mencegah kebocoran memori
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    companyNameController.dispose();
    firstnameController.dispose();
    lastnameController.dispose();
    super.dispose();
  }

  Future<void> signUserUp() async {
    if (!mounted) return;

    // Validasi input
    if (companyNameController.text.isEmpty ||
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

    // Validasi panjang minimum untuk Company Name
    if (companyNameController.text.length < 3) {
      _showErrorMessage('Nama perusahaan harus minimal 3 karakter!');
      return;
    }

    // Validasi panjang maksimum untuk Company Name
    if (companyNameController.text.length > 50) {
      _showErrorMessage('Nama perusahaan maksimal 50 karakter!');
      return;
    }

    // Validasi format email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(emailController.text)) {
      _showErrorMessage('Alamat email tidak valid!');
      return;
    }

    // Validasi kata sandi (minimal 6 karakter, mengandung huruf besar dan angka)
    if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).{6,}$')
        .hasMatch(passwordController.text)) {
      _showErrorMessage(
          'Kata sandi harus minimal 6 karakter, mengandung huruf besar dan angka!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (passwordController.text == confirmPasswordController.text) {
        // Buat akun di Firebase Authentication
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        user = userCredential.user;

        // Perbarui profil pengguna dengan nama lengkap
        String fullName =
            '${firstnameController.text.trim()} ${lastnameController.text.trim()}';
        await user!.updateDisplayName(fullName);

        // Simpan data ke Firestore
        String userId = user!.uid;
        await postDetailsToFirestore(userId);

        // Panggil callback onRegister jika ada
        widget.onRegister?.call();

        // Tampilkan pesan sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akun berhasil dibuat!'),
              duration: Duration(seconds: 5),
            ),
          );
        }

        // Bersihkan semua field setelah registrasi berhasil
        emailController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
        companyNameController.clear();
        firstnameController.clear();
        lastnameController.clear();
        setState(() {
          selectedDepartment = null;
          selectedRole = null; // Kembalikan ke null
        });
      } else {
        _showErrorMessage("Kata sandi tidak cocok!");
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Terjadi kesalahan';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Email sudah digunakan oleh akun lain';
          break;
        case 'invalid-email':
          errorMessage = 'Alamat email tidak valid';
          break;
        case 'weak-password':
          errorMessage = 'Kata sandi terlalu lemah';
          break;
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
      // Simpan data pengguna ke koleksi 'users' di Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'Company Name': companyNameController.text.trim(),
        'First Name': firstnameController.text.trim(),
        'Last Name': lastnameController.text.trim(),
        'Email': emailController.text.trim(),
        'role': selectedRole,
        'department': selectedDepartment,
        'displayName':
            '${firstnameController.text.trim()} ${lastnameController.text.trim()}',
       
      });
      print('Data pengguna berhasil ditambahkan ke Firestore');
    } catch (e) {
      print('Gagal menambahkan data pengguna ke Firestore: $e');
      _showErrorMessage('Gagal menambahkan data pengguna ke Firestore');
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi Company Super Admin'),
        backgroundColor: Colors.teal.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20.0),
              Text(
                'Buat akun Company Super Admin!',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10.0),

              // TextField untuk Company Name (dapat diedit, tidak terisi otomatis)
              TextField(
                controller: companyNameController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Nama Perusahaan',
                  hintText: 'Masukkan Nama Perusahaan',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              const SizedBox(height: 10.0),

              // TextField untuk Nama Depan
              TextField(
                controller: firstnameController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  labelText: 'Nama Depan',
                  hintText: 'Masukkan Nama Depan',
                  fillColor: Colors.grey[200],
                  filled: true,
                ),
              ),
              const SizedBox(height: 10.0),

              // TextField untuk Nama Belakang
              TextField(
                controller: lastnameController,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
              const SizedBox(height: 10.0),

              // Dropdown untuk Role (pilih secara manual)
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Role',
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
                hint: const Text('Pilih Role'),
                items: roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedRole = newValue;
                  });
                },
              ),
              const SizedBox(height: 10.0),

              // Dropdown untuk Departemen
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Departemen',
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
                hint: const Text('Pilih Departemen'),
                items: const <String>[
                  'Admin',
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
              const SizedBox(height: 10.0),

              // TextField untuk Email
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
              const SizedBox(height: 10.0),

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
                      color: Colors.teal.shade900,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
              const SizedBox(height: 10.0),

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
                      color: Colors.teal.shade900,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white),
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
              const SizedBox(height: 20.0),

              // Tombol Register
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                onPressed: _isLoading ? null : signUserUp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}