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
        title: Text('History for ${widget.displayName}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<int>(
                        value: selectedMonth,
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
                        Text('Working Days: $workingDays'),
                        Text('Attended Working Days: $attendedWorkingDays'),
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
                      MaterialPageRoute(builder: (context) => AbsensiPage(userId: widget.employeeId)),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Text('Absensi'),
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
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Text('Overtime'),
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
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Text('Break'),
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
                    margin: const EdgeInsets.all(8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 80,
                        child: Center(
                          child: Text('Visit'),
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
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width / 2 - 16,
                  height: 80,
                  child: Center(
                    child: Text('Cuti'),
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
    DateTime startDate = DateTime(selectedDate.year, selectedDate.month, 22);
    DateTime endDate;
    if (selectedDate.month == 12) {
      endDate = DateTime(selectedDate.year + 1, 1, 21);
    } else {
      endDate = DateTime(selectedDate.year, selectedDate.month + 1, 21);
    }

    // Define holidays
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
    DateTime startDate = DateTime(selectedYear, selectedMonth, 22);
    DateTime endDate;
    if (selectedMonth == 12) {
      endDate = DateTime(selectedYear + 1, 1, 21);
    } else {
      endDate = DateTime(selectedYear, selectedMonth + 1, 21);
    }

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('clockin_records')
        .where('user_id', isEqualTo: widget.employeeId)
        .where('clock_in_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('clock_in_time', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    print("Fetched ${snapshot.docs.length} records");

    for (var doc in snapshot.docs) {
      print(doc.data());
    }

    return snapshot.docs.length;
  }
}
