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
  String? selectedDepartment;
  List<String> departments = ['Direktur', 'Purchasing', 'Finance', 'Account Manager',
    'Marketing', 'Mobile Apps Development', 'Technical Support'];

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ToggleButtons(
              isSelected: [showAdmins, !showAdmins],
              onPressed: (int index) {
                setState(() {
                  showAdmins = index == 0;
                  // Reset the selected department if Admin is selected
                  if (showAdmins) {
                    selectedDepartment = null;
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

          // Dropdown for selecting department (only visible if Karyawan is selected)
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
                    print('Departemen yang dipilih: $selectedDepartment');
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

                // Filter employees based on selected role and department
                final filteredList = employees.where((employee) {
                  final roleMatch = employee['role'] == (showAdmins ? 'Admin' : 'Karyawan');
                  final departmentExists = employee.data().toString().contains('department');
                  final departmentMatch = selectedDepartment == null ||
                      (departmentExists && employee['department'] == selectedDepartment);

                  return roleMatch && departmentMatch;
                }).toList();

                print('Jumlah pengguna yang ditampilkan: ${filteredList.length}');

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
          String displayName = employee.data().toString().contains('displayName')
              ? employee['displayName']
              : 'No Display Name';
          String department = employee.data().toString().contains('department')
              ? employee['department']
              : 'No Department'; // Menggunakan department alih-alih role

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
              subtitle: Text(department), // Menampilkan department
              onTap: () => _navigateToEmployeeHistoryPage(employee.id, displayName),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String department) {
    switch (department) {
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
