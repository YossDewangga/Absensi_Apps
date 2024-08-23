import 'package:absensi_apps/Admin/History%20Karyawan/history_karyawan_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_apps/Login_Register/register_page.dart';

class KaryawanListPage extends StatefulWidget {
  const KaryawanListPage({super.key});

  @override
  _KaryawanListPageState createState() => _KaryawanListPageState();
}

class _KaryawanListPageState extends State<KaryawanListPage> {
  bool showAdmins = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karyawan List', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _navigateToRegisterPage,
          ),
        ],
        titleSpacing: 0.0,
        toolbarHeight: 70.0,
        flexibleSpace: Align(
          alignment: Alignment.topCenter,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
          final karyawanList = employees.where((employee) => employee['role'] == 'Karyawan').toList();
          final adminList = employees.where((employee) => employee['role'] == 'Admin').toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ToggleButtons(
                  isSelected: [showAdmins, !showAdmins],
                  onPressed: (int index) {
                    setState(() {
                      showAdmins = index == 0;
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(showAdmins ? 'Admin' : 'Karyawan'),
                      const Divider(height: 0, thickness: 2),
                      _buildEmployeeList(showAdmins ? adminList : karyawanList),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToRegisterPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
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
          String displayName = employee.data().toString().contains('displayName') ? employee['displayName'] : 'No Display Name';
          String role = employee.data().toString().contains('role') ? employee['role'] : 'No Role';

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getAvatarColor(role),
                child: Text(
                  displayName[0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(role),
              onTap: () => _navigateToEmployeeHistoryPage(employee.id, displayName),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String role) {
    switch (role) {
      case 'Admin':
        return Colors.blueAccent;
      case 'Karyawan':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _navigateToEmployeeHistoryPage(String employeeId, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeHistoryPage(
          employeeId: employeeId,
          displayName: displayName,
        ),
      ),
    );
  }
}
