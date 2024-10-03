import 'package:absensi_apps/User/user_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LendAppPage extends StatefulWidget {
  const LendAppPage({super.key});

  @override
  _LendAppPageState createState() => _LendAppPageState();
}

class _LendAppPageState extends State<LendAppPage> {
  bool showAdmins = true;
  String? selectedDepartment;
  List<String> departments = [
    'Direktur',
    'Purchasing',
    'Finance',
    'Account Manager',
    'Marketing',
    'Mobile Apps Development',
    'Technical Support'
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fungsi untuk login menggunakan email dan password
  Future<void> _loginWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Jika berhasil, arahkan ke halaman UserPage
        _navigateToUserPage(userCredential.user!);
      } else {
        _showSnackBar('Gagal masuk. Coba lagi.');
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Gagal masuk: ${e.message}');
    }
  }

  // Navigasi ke halaman pengguna setelah login berhasil
  void _navigateToUserPage(User user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => UserPage(), // Sesuaikan dengan halaman Anda
      ),
    );
  }

  // Dialog untuk memasukkan password setelah memilih user
  void _showPasswordDialog(String email) {
    final TextEditingController _passwordController = TextEditingController();
    bool _obscureText = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Masukkan Kata Sandi'),
              content: TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText; // Toggle visibilitas password
                      });
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Tutup dialog
                  },
                  child: Text('Batal'),
                ),
                TextButton(
                  onPressed: () {
                    String password = _passwordController.text.trim();
                    if (password.isNotEmpty) {
                      _loginWithEmailAndPassword(email, password); // Coba login dengan email dan password
                      Navigator.of(context).pop(); // Tutup dialog setelah login
                    } else {
                      _showSnackBar('Harap masukkan kata sandi.');
                    }
                  },
                  child: Text('Masuk'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // SnackBar untuk menampilkan pesan error
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lend App', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ToggleButtons(
              isSelected: [showAdmins, !showAdmins],
              onPressed: (int index) {
                setState(() {
                  showAdmins = index == 0;
                  if (showAdmins) {
                    selectedDepartment = null; // Reset pilihan departemen jika Admin dipilih
                  }
                });
              },
              children: [
                Container(
                  width: 80,
                  height: 30,
                  alignment: Alignment.center,
                  child: Text('Admin', style: TextStyle(color: Colors.teal.shade900)),
                ),
                Container(
                  width: 80,
                  height: 30,
                  alignment: Alignment.center,
                  child: Text('Karyawan', style: TextStyle(color: Colors.teal.shade900)),
                ),
              ],
            ),
          ),

          // Dropdown untuk memilih departemen (hanya ditampilkan jika Karyawan dipilih)
          if (!showAdmins)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Pilih Departemen",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                value: selectedDepartment,
                items: departments.map((String department) {
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
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No employees found.'));
                }

                final employees = snapshot.data!.docs;

                // Filter karyawan berdasarkan role (Admin/Karyawan) dan departemen yang dipilih
                final filteredList = employees.where((employee) {
                  final roleMatch = employee['role'] == (showAdmins ? 'Admin' : 'Karyawan');
                  final departmentExists = employee.data().toString().contains('department');
                  final departmentMatch = selectedDepartment == null ||
                      (departmentExists && employee['department'] == selectedDepartment);

                  return roleMatch && departmentMatch;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(showAdmins ? 'Admin' : 'Karyawan'),
                    const Divider(height: 0, thickness: 2),
                    _buildEmployeeList(filteredList),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade900,
        ),
      ),
    );
  }

  Widget _buildEmployeeList(List<DocumentSnapshot> employeeList) {
    return Expanded(
      child: ListView.builder(
        itemCount: employeeList.length,
        itemBuilder: (context, index) {
          final employee = employeeList[index];
          String displayName = employee.data().toString().contains('displayName')
              ? employee['displayName']
              : 'No Display Name';
          String email = employee.data().toString().contains('Email')
              ? employee['Email']
              : 'No Email';

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.shade700,
                child: Text(
                  displayName[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('$email'),
              onTap: () {
                // Tampilkan dialog password saat karyawan dipilih
                _showPasswordDialog(email);
              },
            ),
          );
        },
      ),
    );
  }
}
