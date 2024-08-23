import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'absensi_karyawan.dart';
import 'break_karyawan.dart';
import 'cuti_karyawan.dart';
import 'overtime_karyawan.dart';
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

  @override
  void initState() {
    super.initState();
    _updateData();
  }

  void _updateData() async {
    DateTime date = DateTime(selectedYear, selectedMonth, 22);
    setState(() {
      workingDays = _calculateWorkingDays(date);
    });
    attendedWorkingDays = await _calculateAttendedWorkingDays();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History for ${widget.displayName}',
          style: TextStyle(color: Colors.white), // Teks AppBar berwarna putih
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        elevation: 2.0,
        iconTheme: IconThemeData(color: Colors.white), // Ikon AppBar berwarna putih
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
                      MaterialPageRoute(builder: (context) => OvertimePage()),
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
                              Icon(Icons.schedule, color: Colors.teal.shade700),
                              Text(
                                'Overtime',
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
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BreakPage()),
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
                              Icon(Icons.free_breakfast, color: Colors.teal.shade700),
                              Text(
                                'Break',
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

  int _calculateWorkingDays(DateTime selectedDate) {
    DateTime startDate = DateTime(selectedYear, selectedMonth - 1, 22);
    DateTime endDate = DateTime(selectedYear, selectedMonth, 21);

    List<DateTime> holidays = [
      DateTime(selectedDate.year, 1, 1), // New Year's Day
      DateTime(selectedDate.year, 5, 1), // Labor Day
      DateTime(selectedDate.year, 8, 17), // Indonesian Independence Day
      // Tambahkan tanggal merah lainnya di sini
    ];

    int workingDays = 0;

    for (DateTime day = startDate;
    day.isBefore(endDate) || day.isAtSameMomentAs(endDate);
    day = day.add(Duration(days: 1))) {
      if (day.weekday != DateTime.saturday &&
          day.weekday != DateTime.sunday &&
          !holidays.contains(day)) {
        workingDays++;
      }
    }

    return workingDays;
  }

  Future<int> _calculateAttendedWorkingDays() async {
    DateTime startDate = DateTime(selectedYear, selectedMonth - 1, 22);
    DateTime endDate = DateTime(selectedYear, selectedMonth, 21);

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
        .collection('clockin_records')
        .where('clock_in_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('clock_in_time', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where('approved', isEqualTo: true)
        .orderBy('clock_in_time')
        .get();

    Set<String> uniqueDays = Set();

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      var clockInTime = data['clock_in_time'] != null
          ? (data['clock_in_time'] as Timestamp).toDate()
          : null;

      if (clockInTime != null) {
        String formattedDate = DateFormat('yyyy-MM-dd').format(clockInTime);
        uniqueDays.add(formattedDate);
      }
    }

    return uniqueDays.length;
  }
}
