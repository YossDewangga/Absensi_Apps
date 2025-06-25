import 'package:absensi_apps/Super%20Admin/register_super_admin.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_apps/Login_Register/register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:absensi_apps/Login_Register/login_page.dart';

class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({Key? key}) : super(key: key);

  @override
  _SuperAdminPageState createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  final List<String> defaultRoles = ['Karyawan', 'Admin', 'Super Admin', 'SecondAdmin'];
  final List<Map<String, String>> features = [
    {'key': 'visit', 'label': 'Visit'},
    {'key': 'clock', 'label': 'Clock'},
    {'key': 'cuti', 'label': 'Cuti'},
    {'key': 'Slip Gaji', 'label': 'Slip Gaji'},
  ];

  void _openRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterSuperAdmin()),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (route) => false,
    );
  }

  void _showRoleDialog(BuildContext context, String userId, String currentRole, List<dynamic>? currentAccess) {
    String? selectedRole = currentRole;
    List<String> selectedAccess = List<String>.from(currentAccess ?? []);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Pengguna',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal.shade900),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: selectedRole,
                      hint: Text('Pilih Role'),
                      items: defaultRoles.map((String role) {
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
                      isExpanded: true,
                      underline: Container(
                        height: 1,
                        color: Colors.teal.shade700,
                      ),
                      style: TextStyle(color: Colors.teal.shade900, fontSize: 15),
                      dropdownColor: Colors.white,
                    ),
                    if (selectedRole == 'Super Admin' || selectedRole == 'Admin')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Chip(
                          label: Text(selectedRole!, style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.teal.shade700,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text('Akses Fitur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: features.map((feature) {
                        bool isSelected = selectedAccess.contains(feature['key']);
                        return CheckboxListTile(
                          title: Text(
                            feature['label']!,
                            style: TextStyle(
                              color: Colors.teal.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedAccess.add(feature['key']!);
                              } else {
                                selectedAccess.remove(feature['key']);
                              }
                            });
                          },
                          activeColor: Colors.teal.shade700,
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: Text('Batal', style: TextStyle(color: Colors.grey.shade700)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
              ),
              onPressed: () async {
                try {
                  print("Mengupdate pengguna $userId dengan role: $selectedRole, akses: $selectedAccess");
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'role': selectedRole,
                    'access': selectedAccess.isNotEmpty ? selectedAccess : [],
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Data pengguna berhasil diupdate')),
                  );
                } catch (e) {
                  print("Error mengupdate pengguna: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengupdate data: $e')),
                  );
                }
                Navigator.pop(context);
              },
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
        title: const Text('Panel Super Admin'),
        backgroundColor: Colors.teal.shade900,
        centerTitle: true,
        elevation: 2,
        leading: IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          tooltip: 'Keluar',
          onPressed: _logout,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add, color: Colors.white),
            tooltip: 'Daftar Pengguna',
            onPressed: _openRegisterPage,
          ),
        ],
      ),
      body: Container(
        color: Colors.teal.shade50,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!.docs;
            if (users.isEmpty) {
              return const Center(child: Text('Tidak ada pengguna ditemukan.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              itemCount: users.length,
              separatorBuilder: (context, idx) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];
                final data = user.data() as Map<String, dynamic>;
                final displayName = data['displayName'] ?? data['email'] ?? '-';
                final email = data['email'] ?? '-';
                final role = data['role'] ?? 'Karyawan';
                final access = data['access'] ?? [];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade700,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(displayName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: TextStyle(color: Colors.teal.shade700)),
                        Text('Role: $role', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        if (!defaultRoles.contains(role))
                          Text('Role tidak standar', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ],
                    ),
                    onTap: () => _showRoleDialog(context, user.id, role, access),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class NoAccessWidget extends StatelessWidget {
  final String featureName;
  const NoAccessWidget({required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            'Akses Ditolak',
            style: TextStyle(fontSize: 20, color: Colors.red, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Anda tidak memiliki akses ke fitur $featureName.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}