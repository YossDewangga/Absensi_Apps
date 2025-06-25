import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'absensi_karyawan.dart';
import 'cuti_karyawan.dart';
import 'visit_karyawan.dart';

class EmployeeHistoryPage extends StatefulWidget {
  final String employeeId;
  final String displayName;

  const EmployeeHistoryPage({
    Key? key,
    required this.employeeId,
    required this.displayName,
  }) : super(key: key);

  @override
  _EmployeeHistoryPageState createState() => _EmployeeHistoryPageState();
}

class _EmployeeHistoryPageState extends State<EmployeeHistoryPage> {
  DateTime selectedDate = DateTime(DateTime.now().year, DateTime.now().month, 22);
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int workingDays = 0;
  int attendedWorkingDays = 0;
  int notApprovedCount = 0;

  @override
  void initState() {
    super.initState();
    _updateData();
  }

  void _updateData() async {
    print('DEBUG: Memulai _updateData untuk bulan: $selectedMonth, tahun: $selectedYear');
    DateTime date = DateTime(selectedYear, selectedMonth, 22);
    int tempWorkingDays = await _calculateWorkingDays(date);
    var (tempAttendedDays, tempNotApprovedCount) = await _calculateAttendedWorkingDays();
    setState(() {
      workingDays = tempWorkingDays;
      attendedWorkingDays = tempAttendedDays;
      notApprovedCount = tempNotApprovedCount;
      print('DEBUG: Update state - workingDays: $workingDays, attendedWorkingDays: $attendedWorkingDays, notApprovedCount: $notApprovedCount');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History for ${widget.displayName}',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        elevation: 2.0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Card(
            color: Colors.white,
            margin: const EdgeInsets.all(16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<int>(
                        value: selectedMonth,
                        icon: Icon(Icons.calendar_today, color: Colors.teal.shade700),
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(DateFormat.MMMM().format(DateTime(0, index + 1))),
                          );
                        }),
                        onChanged: (int? newMonth) {
                          if (newMonth != null) {
                            setState(() {
                              selectedMonth = newMonth;
                              print('DEBUG: Bulan berubah menjadi: $newMonth');
                              _updateData();
                            });
                          }
                        },
                      ),
                      SizedBox(width: 16),
                      DropdownButton<int>(
                        value: selectedYear,
                        icon: Icon(Icons.calendar_today, color: Colors.teal.shade700),
                        items: List.generate(10, (index) {
                          int year = DateTime.now().year - 5 + index;
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }),
                        onChanged: (int? newYear) {
                          if (newYear != null) {
                            setState(() {
                              selectedYear = newYear;
                              print('DEBUG: Tahun berubah menjadi: $newYear');
                              _updateData();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Working Days: $workingDays',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        Text(
                          'Attended Working Days: $attendedWorkingDays',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.teal.shade600),
                        ),
                        Text(
                          'Not approved yet: $notApprovedCount',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w300, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AbsensiPage(
                          userId: widget.employeeId,
                          selectedMonth: selectedMonth,
                          selectedYear: selectedYear,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    color: Colors.teal.shade50,
                    margin: const EdgeInsets.all(8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time, color: Colors.teal.shade700),
                              Text(
                                'Absensi',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => VisitPage(userId: widget.employeeId)),
                    );
                  },
                  child: Card(
                    color: Colors.teal.shade50,
                    margin: const EdgeInsets.all(8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 4.0,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, color: Colors.teal.shade700),
                              Text(
                                'Visit',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CutiPage(userId: widget.employeeId)),
              );
            },
            child: Card(
              color: Colors.teal.shade50,
              margin: const EdgeInsets.all(8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 16,
                  height: 80,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.beach_access, color: Colors.teal.shade700),
                        Text(
                          'Cuti',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _calculateWorkingDays(DateTime selectedDate) async {
    DateTime startDate = DateTime(selectedYear, selectedMonth - 1, 22);
    DateTime endDate = DateTime(selectedYear, selectedMonth, 21);

    List<DateTime> holidays = await _fetchHolidays();
    print('DEBUG: Tanggal merah: $holidays');

    int workingDays = 0;

    for (DateTime day = startDate;
        day.isBefore(endDate) || day.isAtSameMomentAs(endDate);
        day = day.add(Duration(days: 1))) {
      if (day.weekday != DateTime.saturday &&
          day.weekday != DateTime.sunday &&
          !holidays.any((holiday) => holiday.year == day.year && holiday.month == day.month && holiday.day == day.day)) {
        workingDays++;
      }
    }

    print('DEBUG: Jumlah hari kerja: $workingDays');
    return workingDays;
  }

  Future<List<DateTime>> _fetchHolidays() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('DEBUG: Tidak ada pengguna yang login');
      return [];
    }
    final adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    if (!adminDoc.exists) {
      print('DEBUG: Dokumen pengguna tidak ditemukan');
      return [];
    }
    final adminData = adminDoc.data() as Map<String, dynamic>;
    String? companyName = adminData['Company Name']?.toString().trim();
    if (companyName == null || companyName.isEmpty) {
      print('DEBUG: Nama perusahaan kosong');
      return [];
    }
    final companyDoc = await FirebaseFirestore.instance.collection('companies').doc(companyName).get();
    final data = companyDoc.data();
    if (data == null || !data.containsKey('public_holidays')) {
      print('DEBUG: Tidak ada tanggal merah untuk perusahaan: $companyName');
      return [];
    }
    return (data['public_holidays'] as List<dynamic>)
        .map((item) => (item['date'] as Timestamp).toDate())
        .toList();
  }

  Future<(int, int)> _calculateAttendedWorkingDays() async {
    DateTime startDate = DateTime(selectedYear, selectedMonth - 1, 22);
    DateTime endDate = DateTime(selectedYear, selectedMonth, 21);

    print('DEBUG: Mengambil data untuk userId: ${widget.employeeId}');
    print('DEBUG: Rentang tanggal: $startDate hingga $endDate');

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('clockin_records')
          .where('clock_in_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('clock_in_time', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('clock_in_time')
          .get();

      print('DEBUG: Jumlah dokumen ditemukan: ${snapshot.docs.length}');
      if (snapshot.docs.isEmpty) {
        print('DEBUG: Tidak ada dokumen ditemukan dalam rentang tanggal');
      }

      Set<String> uniqueDays = {};
      int notApprovedCount = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        print('DEBUG: Dokumen ID: ${doc.id}, Data: $data');

        var clockInTime = data['clock_in_time'] != null
            ? (data['clock_in_time'] as Timestamp).toDate()
            : null;
        var approved = data.containsKey('approved') ? data['approved'] : null;

        print('DEBUG: clock_in_time: $clockInTime, approved: $approved (tipe: ${approved.runtimeType})');

        if (clockInTime != null) {
          String formattedDate = DateFormat('yyyy-MM-dd').format(clockInTime);
          uniqueDays.add(formattedDate);
          print('DEBUG: Tanggal unik ditambahkan: $formattedDate');
        } else {
          print('DEBUG: Dokumen tanpa clock_in_time valid: $data');
        }

        if (approved == false) {
          notApprovedCount++;
          print('DEBUG: Dokumen dengan approved: false ditemukan, notApprovedCount: $notApprovedCount');
        } else {
          print('DEBUG: Dokumen ini tidak dihitung untuk notApprovedCount (approved: $approved)');
        }
      }

      print('DEBUG: Jumlah hari unik (attendedWorkingDays): ${uniqueDays.length}');
      print('DEBUG: Jumlah catatan dengan approved false (notApprovedCount): $notApprovedCount');
      return (uniqueDays.length, notApprovedCount);
    } catch (e) {
      print('DEBUG: Error saat mengambil data clockin_records: $e');
      return (0, 0);
    }
  }
}