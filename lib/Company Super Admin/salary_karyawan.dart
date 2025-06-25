import 'package:absensi_apps/Company%20Super%20Admin/company_info_salary.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ListGajiKaryawanPage extends StatefulWidget {
  const ListGajiKaryawanPage({super.key});

  @override
  _ListGajiKaryawanPageState createState() => _ListGajiKaryawanPageState();
}

class _ListGajiKaryawanPageState extends State<ListGajiKaryawanPage> {
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
  String? adminCompanyName;
  bool _isLoadingCompany = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminCompanyName();
  }

  Future<void> _fetchAdminCompanyName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          print('DEBUG: Admin Data Retrieved: $adminData');
          String? rawCompanyName = adminData['Company Name'];
          String companyName = (rawCompanyName is String) ? rawCompanyName.trim() : '';
          print('DEBUG: Retrieved Company Name (raw): "$rawCompanyName"');
          if (companyName.isEmpty) {
            print('DEBUG: Company Name is empty or missing for admin');
          }
          setState(() {
            adminCompanyName = companyName.isNotEmpty ? companyName : null;
            _isLoadingCompany = false;
          });
        } else {
          print('DEBUG: Admin document does not exist in Firestore');
          setState(() {
            _isLoadingCompany = false;
          });
        }
      } catch (e) {
        print('DEBUG: Error fetching admin data: $e');
        setState(() {
          _isLoadingCompany = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data perusahaan: $e')),
        );
      }
    } else {
      print('DEBUG: No current user found');
      setState(() {
        _isLoadingCompany = false;
      });
    }
  }

  Future<void> _addPublicHoliday(DateTime date, String description) async {
    if (adminCompanyName == null || adminCompanyName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama perusahaan tidak ditemukan.')),
      );
      return;
    }

    try {
      final companyDocRef = FirebaseFirestore.instance.collection('companies').doc(adminCompanyName);
      await companyDocRef.set({
        'public_holidays': FieldValue.arrayUnion([
          {
            'date': Timestamp.fromDate(date),
            'description': description,
          }
        ]),
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil disimpan!')),
      );
    } catch (e) {
      print('DEBUG: Error adding public holiday: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCompany) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('List Gaji Karyawan', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.teal.shade900,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (adminCompanyName == null || adminCompanyName!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('List Gaji Karyawan', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.teal.shade900,
        ),
        body: const Center(child: Text('Nama perusahaan admin tidak ditemukan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'List Gaji Karyawan',
              style: TextStyle(color: Colors.white, fontSize: 25),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.white),
              tooltip: 'Tambah Tanggal Merah',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddHolidayPage(onSave: _addPublicHoliday),
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade900,
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
                    print('DEBUG: Departemen yang dipilih: $selectedDepartment');
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
                  print('DEBUG: Stream error: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print('DEBUG: No employee data found');
                  return const Center(child: Text('Tidak ada data karyawan.'));
                }

                final employees = snapshot.data!.docs;
                print('DEBUG: Total employees fetched: ${employees.length}');
                for (var employee in employees) {
                  print('DEBUG: Employee data: ${employee.data()}');
                }

                final filteredList = employees.where((employee) {
                  final data = employee.data() as Map<String, dynamic>;
                  final companyKey = data.keys.firstWhere(
                    (k) => k.trim().toLowerCase() == 'company name',
                    orElse: () => '',
                  );
                  final employeeCompanyName = (companyKey.isNotEmpty && data[companyKey] is String)
                      ? data[companyKey].toString().trim()
                      : '';
                  print('DEBUG: Employee Company Name: "$employeeCompanyName"');

                  final companyMatch = adminCompanyName != null &&
                      adminCompanyName!.isNotEmpty &&
                      employeeCompanyName.toLowerCase() == adminCompanyName!.toLowerCase();
                  final roleMatch = companyMatch && data['role'] == (showAdmins ? 'Admin' : 'Karyawan');
                  final departmentMatch = selectedDepartment == null ||
                      (data.containsKey('department') && data['department'] == selectedDepartment);

                  print(
                      'DEBUG: User ${data['displayName']} | Role: ${data['role']} | Company: $employeeCompanyName | Company Match: $companyMatch | Role Match: $roleMatch | Department Match: $departmentMatch');
                  return roleMatch && departmentMatch && companyMatch;
                }).toList();

                print('DEBUG: Jumlah pengguna yang ditampilkan: ${filteredList.length}');

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
          final data = employee.data() as Map<String, dynamic>;
          String displayName = data.containsKey('displayName') ? data['displayName'] : 'No Display Name';
          String department = data.containsKey('department') ? data['department'] : 'No Department';

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getAvatarColor(department),
                child: Text(
                  displayName.isNotEmpty ? displayName[0] : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(department),
              onTap: () => _navigateToCompanyInfoSalaryPage(employee.id, displayName),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String department) {
    switch (department) {
      case 'Direktur':
        return Colors.teal.shade700;
      case 'Purchasing':
        return Colors.blue.shade700;
      case 'Finance':
        return Colors.green.shade700;
      case 'Account Manager':
        return Colors.orange.shade700;
      case 'Marketing':
        return Colors.red.shade700;
      case 'Mobile Apps Development':
        return Colors.purple.shade700;
      case 'Technical Support':
        return Colors.cyan.shade700;
      default:
        return Colors.grey;
    }
  }

  void _navigateToCompanyInfoSalaryPage(String userId, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyInfoSalary(
          userId: userId,
          displayName: displayName,
        ),
      ),
    );
  }
}

// Reuse AddHolidayPage and HolidayDetailPage from original code
class AddHolidayPage extends StatefulWidget {
  final Function(DateTime, String) onSave;

  const AddHolidayPage({super.key, required this.onSave});

  @override
  _AddHolidayPageState createState() => _AddHolidayPageState();
}

class _AddHolidayPageState extends State<AddHolidayPage> {
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  int selectedDay = DateTime.now().day;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxDays = DateTime(selectedYear, selectedMonth + 1, 0).day;
    if (selectedDay > maxDays) {
      selectedDay = maxDays;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tambah Tanggal Merah',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.teal[800],
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Color.fromARGB(255, 17, 105, 85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F4F8), Color(0xFFDDE6F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildModernInputCard('Tahun', selectedYear, List.generate(10, (index) => DateTime.now().year - 5 + index)),
              const SizedBox(height: 20),
              _buildModernInputCard('Bulan', selectedMonth, List.generate(12, (index) => index + 1)),
              const SizedBox(height: 20),
              _buildModernInputCard('Hari', selectedDay, List.generate(maxDays, (index) => index + 1)),
              const SizedBox(height: 20),
              _buildModernDescriptionCard(),
              const SizedBox(height: 40),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModernButton(
                      text: 'Batal',
                      color: Colors.grey[300]!,
                      textColor: Colors.black87,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 20),
                    _buildModernButton(
                      text: 'Simpan',
                      color: Colors.teal[700]!,
                      textColor: Colors.white,
                      onPressed: () {
                        final selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);
                        final description = _descriptionController.text.trim();
                        if (description.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Keterangan tidak boleh kosong!')),
                          );
                          return;
                        }
                        widget.onSave(selectedDate, description);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HolidayDetailPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Rincian Tanggal Merah',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color.fromARGB(255, 8, 66, 61),
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernInputCard(String label, int value, List<int> items) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                ),
                child: DropdownButton<int>(
                  value: value,
                  hint: Text(label, style: const TextStyle(color: Colors.grey)),
                  items: items.map((int item) {
                    return DropdownMenuItem<int>(
                      value: item,
                      child: Text(
                        label == 'Bulan' ? DateFormat.MMMM('id').format(DateTime(0, item)) : item.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        if (label == 'Tahun') {
                          selectedYear = newValue;
                        } else if (label == 'Bulan') {
                          selectedMonth = newValue;
                        } else if (label == 'Hari') {
                          selectedDay = newValue;
                        }
                        final maxDays = DateTime(selectedYear, selectedMonth + 1, 0).day;
                        if (selectedDay > maxDays) {
                          selectedDay = maxDays;
                        }
                      });
                    }
                  },
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontFamily: 'Roboto'),
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF004D40)),
                  iconSize: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDescriptionCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keterangan Tanggal Merah',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[100],
                ),
                child: TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Masukkan keterangan',
                    hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Roboto'),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontFamily: 'Roboto'),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
        elevation: 6,
        shadowColor: Colors.grey.withOpacity(0.3),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
          color: textColor,
        ),
      ),
    );
  }
}

class HolidayDetailPage extends StatefulWidget {
  const HolidayDetailPage({super.key});

  @override
  _HolidayDetailPageState createState() => _HolidayDetailPageState();
}

class _HolidayDetailPageState extends State<HolidayDetailPage> {
  late Future<List<Map<String, dynamic>>> _holidays;

  @override
  void initState() {
    super.initState();
    _holidays = _fetchPublicHolidays();
  }

  Future<List<Map<String, dynamic>>> _fetchPublicHolidays() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          String? rawCompanyName = adminData['Company Name'];
          String companyName = (rawCompanyName is String) ? rawCompanyName.trim() : '';
          if (companyName.isEmpty) {
            print('DEBUG: Company name empty in HolidayDetailPage');
            return [];
          }

          final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyName).get();
          final data = companyDoc.data();
          if (data == null || !data.containsKey('public_holidays')) {
            print('DEBUG: No public holidays found for company: $companyName');
            return [];
          }

          final holidays = (data['public_holidays'] as List<dynamic>).map((item) {
            if (item is Map<String, dynamic> && item['date'] is Timestamp) {
              return {
                'date': (item['date'] as Timestamp).toDate(),
                'description': item['description'] as String? ?? 'No Description',
              };
            }
            return null;
          }).whereType<Map<String, dynamic>>().toList();

          print('DEBUG: Fetched holidays: $holidays');
          return holidays;
        }
      } catch (e) {
        print('DEBUG: Error fetching holidays: $e');
        return [];
      }
    }
    print('DEBUG: No current user found in HolidayDetailPage');
    return [];
  }

  Future<void> _removePublicHoliday(DateTime date) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          String? rawCompanyName = adminData['Company Name'];
          String companyName = (rawCompanyName is String) ? rawCompanyName.trim() : '';
          if (companyName.isEmpty) return;

          final companyDocRef = FirebaseFirestore.instance.collection('companies').doc(companyName);
          final holidays = await _fetchPublicHolidays();
          final holidayToRemove = holidays.firstWhere(
            (holiday) => holiday['date'] == date,
            orElse: () => {'date': date, 'description': 'No Description'},
          );

          await companyDocRef.update({
            'public_holidays': FieldValue.arrayRemove([
              {
                'date': Timestamp.fromDate(holidayToRemove['date']),
                'description': holidayToRemove['description'] as String,
              }
            ]),
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tanggal merah berhasil dihapus!')),
          );
          setState(() {
            _holidays = _fetchPublicHolidays();
          });
        }
      } catch (e) {
        print('DEBUG: Error removing holiday: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Rincian Tanggal Merah',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal[800],
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.tealAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F4F8), Color(0xFFDDE6F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _holidays,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 10, 78, 71)));
            }
            if (snapshot.hasError) {
              print('DEBUG: FutureBuilder error: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)));
            }
            final holidays = snapshot.data ?? [];
            if (holidays.isEmpty) {
              return Center(
                child: Text(
                  'Tidak ada tanggal merah yang ditambahkan.',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: holidays.length,
              itemBuilder: (context, index) {
                final item = holidays[index];
                final date = item['date'] as DateTime;
                final description = item['description'] as String;
                return Card(
                  elevation: 6,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: const Icon(Icons.calendar_today, color: Color(0xFF00695C), size: 28),
                    title: Text(
                      DateFormat('dd MMMM yyyy', 'id').format(date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    subtitle: description.isNotEmpty
                        ? Text(
                            description,
                            style: const TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Roboto'),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFBF360C), size: 24),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Konfirmasi'),
                            content: const Text('Yakin data ingin dihapus?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Tidak'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _removePublicHoliday(date);
                                },
                                child: const Text('Iya'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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