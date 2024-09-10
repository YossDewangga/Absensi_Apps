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

      // Cek apakah pengguna berhasil login
      if (userCredential.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Berhasil masuk sebagai ${userCredential.user!.email}'),
          backgroundColor: Colors.green,
        ));

        // Setelah login berhasil, arahkan ke halaman UserPage
        _navigateToUserPage(userCredential.user!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal masuk. Coba lagi.'),
          backgroundColor: Colors.red,
        ));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal masuk: ${e.message}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // Fungsi untuk mengarahkan pengguna ke halaman UserPage setelah login berhasil
  void _navigateToUserPage(User user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => UserPage(), // Ganti dengan halaman UserPage Anda
      ),
    );
  }

  // Dialog untuk memasukkan password setelah memilih karyawan
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
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
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
                      Navigator.of(context).pop(); // Tutup dialog setelah submit
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Harap masukkan kata sandi.'),
                        backgroundColor: Colors.red,
                      ));
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
          // Dropdown untuk memilih departemen (hanya menampilkan Karyawan)
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

                // Filter karyawan berdasarkan departemen yang dipilih
                final filteredList = employees.where((employee) {
                  final departmentExists = employee.data().toString().contains('department');
                  final departmentMatch = selectedDepartment == null ||
                      (departmentExists && employee['department'] == selectedDepartment);

                  return employee['role'] == 'Karyawan' && departmentMatch;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Karyawan'),
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
          String department = employee.data().toString().contains('department')
              ? employee['department']
              : 'No Department';
          String email = employee.data().toString().contains('Email')
              ? employee['Email']
              : 'No Email'; // Pastikan menggunakan kapitalisasi yang benar

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getAvatarColor(department),
                child: Text(
                  displayName[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(department), // Ganti dengan departemen
              onTap: () {
                // Menampilkan dialog untuk memasukkan password
                _showPasswordDialog(email);
              },
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String department) {
    switch (department) {
      case 'Karyawan':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
