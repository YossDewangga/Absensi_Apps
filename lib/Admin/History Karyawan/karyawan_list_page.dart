import 'package:absensi_apps/Admin/History%20Karyawan/history_karyawan_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:absensi_apps/Login_Register/register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KaryawanListPage extends StatefulWidget {
  const KaryawanListPage({super.key});

  @override
  _KaryawanListPageState createState() => _KaryawanListPageState();
}

class _KaryawanListPageState extends State<KaryawanListPage> {
  bool showAdmins = true;
  String? selectedDepartment;
  List<String> departments = [
    'Direktur', 'Purchasing', 'Finance', 'Account Manager',
    'Marketing', 'Mobile Apps Development', 'Technical Support'
  ];

  String? adminCompanyName;
  bool _isLoadingCompany = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminCompanyName();
  }

  // Function to fetch the Admin's company name
  Future<void> _fetchAdminCompanyName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      if (adminDoc.exists) {
        final adminData = adminDoc.data() as Map<String, dynamic>;

        // Debugging: Log the entire admin data to see what is coming from Firestore
        print('DEBUG: Admin Data Retrieved: $adminData');

        // Extract the 'Company Name' and trim it safely
        String? rawCompanyName = adminData['Company Name'];
        String companyName = (rawCompanyName is String) ? rawCompanyName.trim() : '';
        
        // Debugging: Log the raw company name
        print('DEBUG: Retrieved Company Name (raw): "${adminData['Company Name']}"');

        // Check if the company name is empty
        if (companyName.isEmpty) {
          print('DEBUG: Company Name is empty or missing for admin');
        }

        // Set the company name to state
        setState(() {
          adminCompanyName = companyName;
          _isLoadingCompany = false;
        });
      } else {
        print('DEBUG: Admin document does not exist in Firestore');
        setState(() {
          _isLoadingCompany = false;
        });
      }
    } else {
      setState(() {
        _isLoadingCompany = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCompany) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Karyawan List', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                    selectedDepartment = null; // Reset department when switching to Admin view
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

                // Check if adminCompanyName is available
                if (adminCompanyName == null || adminCompanyName!.isEmpty) {
                  print('DEBUG: Admin Company Name is missing or empty.');
                  return const Center(child: Text('Admin Company Name is missing.'));
                }

                print('DEBUG: Total employees fetched: ${employees.length}');
                for (var employee in employees) {
                  print('DEBUG: employee data: ${employee.data()}');
                }

                // Filter based on company name, then role, then department
                final filteredList = employees.where((employee) {
                  final data = employee.data() as Map<String, dynamic>;

                  // Cari key "Company Name" yang benar-benar ada (abaikan case dan spasi)
                  final companyKey = data.keys.firstWhere(
                    (k) => k.trim().toLowerCase() == 'company name',
                    orElse: () => '',
                  );
                  final employeeCompanyName = (companyKey.isNotEmpty && data[companyKey] is String)
                      ? data[companyKey].toString().trim()
                      : '';

                  print('DEBUG: employeeCompanyName: "$employeeCompanyName"');

                  final companyMatch = adminCompanyName != null &&
                      adminCompanyName!.isNotEmpty &&
                      employeeCompanyName.toLowerCase() == adminCompanyName!.toLowerCase();

                  print('DEBUG: companyMatch: $companyMatch');

                  final roleMatch = companyMatch && data['role'] == (showAdmins ? 'Admin' : 'Karyawan');
                  final departmentMatch = selectedDepartment == null ||
                      (data.containsKey('department') && data['department'] == selectedDepartment);

                  print('DEBUG: user ${data['displayName']} | role: ${data['role']} | company: $employeeCompanyName | match: $companyMatch');
                  return roleMatch && departmentMatch && companyMatch;
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
              : 'No Department';

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
              subtitle: Text(department),
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
