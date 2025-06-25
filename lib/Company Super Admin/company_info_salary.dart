import 'package:absensi_apps/Company%20Super%20Admin/slip_gaji_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'edit_salary_page.dart';

class CompanyInfoSalary extends StatefulWidget {
  final String userId;
  final String displayName;

  const CompanyInfoSalary({super.key, required this.userId, required this.displayName});

  @override
  State<CompanyInfoSalary> createState() => _CompanyInfoSalaryState();
}

class _CompanyInfoSalaryState extends State<CompanyInfoSalary> {
  bool _isLoading = true;
  Map<String, dynamic>? salaryData;
  int lateDays = 0;
  int workingDays = 0;
  int presentDays = 0;
  int absentDays = 0;
  int leaveDays = 0;
  int publicHolidaysInPeriod = 0;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  List<DateTime>? dynamicPublicHolidays;

  @override
  void initState() {
    super.initState();
    _fetchCompanyHolidays();
    _loadSalaryDataForPeriod(selectedMonth, selectedYear);
  }

  Future<void> _fetchCompanyHolidays() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final adminDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          String? companyName = adminData['Company Name'] as String?;
          if (companyName != null && companyName.isNotEmpty) {
            final companyDoc = await FirebaseFirestore.instance
                .collection('companies')
                .doc(companyName)
                .get();
            final data = companyDoc.data();
            if (data != null && data.containsKey('public_holidays')) {
              final holidays = (data['public_holidays'] as List<dynamic>)
                  .map((item) => (item['date'] as Timestamp).toDate())
                  .toList();
              setState(() {
                dynamicPublicHolidays = holidays.cast<DateTime>();
              });
            }
          }
        }
      } catch (e) {
        print('Error fetching holidays: $e');
      }
    }
  }

  Future<void> _loadSalaryDataForPeriod(int month, int year) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('salary')
          .doc('current')
          .get();
      final salary = doc.data();

      final totalLateDays = await getTotalLateDays(widget.userId, month, year);
      final totalPresentDays = await getTotalPresentDays(widget.userId, month, year);
      final totalLeaveDays = await getTotalLeaveDays(widget.userId, month, year);
      final startDate = DateTime(year, month - 1, 22);
      final endDate = DateTime(year, month, 21);
      final totalWorkingDays = countWorkingDays(startDate, endDate);

      final publicHolidaysInPeriod = (dynamicPublicHolidays ?? [])
          .where((holiday) =>
              holiday.isAfter(startDate.subtract(Duration(days: 1))) &&
              holiday.isBefore(endDate.add(Duration(days: 1))))
          .length;

      final totalAbsentDays =
          totalWorkingDays - totalPresentDays - totalLeaveDays - publicHolidaysInPeriod;
      final adjustedAbsentDays = totalAbsentDays > 0 ? totalAbsentDays : 0;

      print('Debug - Leave Days: $totalLeaveDays');
      setState(() {
        salaryData = salary;
        lateDays = totalLateDays;
        workingDays = totalWorkingDays;
        presentDays = totalPresentDays;
        leaveDays = totalLeaveDays;
        absentDays = adjustedAbsentDays;
        this.publicHolidaysInPeriod = publicHolidaysInPeriod;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading salary data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data gaji: $e')),
      );
    }
  }

  Future<int> getTotalLateDays(String userId, int selectedMonth, int selectedYear) async {
    final startDate = DateTime(selectedYear, selectedMonth - 1, 22);
    final endDate = DateTime(selectedYear, selectedMonth, 21, 23, 59, 59);

    final records = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('clockin_records')
        .where('clock_in_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('clock_in_time', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    int totalLateDays = 0;
    for (var doc in records.docs) {
      final lateDurationStr = doc['late_duration'] ?? "00:00:00";
      if (lateDurationStr != "00:00:00") {
        totalLateDays++;
      }
    }
    return totalLateDays;
  }

  Future<int> getTotalPresentDays(String userId, int selectedMonth, int selectedYear) async {
    final startDate = DateTime(selectedYear, selectedMonth - 1, 22);
    final endDate = DateTime(selectedYear, selectedMonth, 21, 23, 59, 59);

    final records = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('clockin_records')
        .where('clock_in_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('clock_in_time', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final presentDates = <String>{};
    for (var doc in records.docs) {
      final clockInTimestamp = doc['clock_in_time'] as Timestamp?;
      final clockInDate = clockInTimestamp?.toDate();
      if (clockInDate != null &&
          clockInDate.weekday >= DateTime.monday &&
          clockInDate.weekday <= DateTime.friday &&
          (dynamicPublicHolidays == null ||
              !dynamicPublicHolidays!.contains(DateTime(
                  clockInDate.year, clockInDate.month, clockInDate.day)))) {
        presentDates.add('${clockInDate.year}-${clockInDate.month}-${clockInDate.day}');
      }
    }
    return presentDates.length;
  }

  Future<int> getTotalLeaveDays(String userId, int selectedMonth, int selectedYear) async {
    final startDate = DateTime(selectedYear, selectedMonth - 1, 22, 0, 0, 0, 0, 0)
        .toUtc()
        .subtract(Duration(hours: 7));
    final endDate = DateTime(selectedYear, selectedMonth, 21, 23, 59, 59, 0, 0)
        .toUtc()
        .subtract(Duration(hours: 7));

    final leaveRecords = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('leave_applications')
        .where('start_date', isLessThanOrEqualTo: endDate)
        .where('end_date', isGreaterThanOrEqualTo: startDate)
        .where('status', isEqualTo: 'Approved')
        .get();

    final leaveDates = <String>{};
    for (var doc in leaveRecords.docs) {
      final startTimestamp = doc['start_date'] as Timestamp?;
      final endTimestamp = doc['end_date'] as Timestamp?;
      final startDate = startTimestamp?.toDate().toUtc().subtract(Duration(hours: 7));
      final endDate = endTimestamp?.toDate().toUtc().subtract(Duration(hours: 7));
      if (startDate != null && endDate != null) {
        DateTime current = startDate;
        while (!current.isAfter(endDate.add(Duration(days: 1)))) {
          if (current.weekday >= DateTime.monday &&
              current.weekday <= DateTime.friday &&
              (dynamicPublicHolidays == null ||
                  !dynamicPublicHolidays!.contains(DateTime(
                      current.year, current.month, current.day)))) {
            leaveDates.add('${current.year}-${current.month}-${current.day}');
          }
          current = current.add(Duration(days: 1));
        }
      }
    }
    return leaveDates.length;
  }

  int countWorkingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = start;
    while (!current.isAfter(end)) {
      if (current.weekday >= DateTime.monday &&
          current.weekday <= DateTime.friday &&
          (dynamicPublicHolidays == null ||
              !dynamicPublicHolidays!.contains(DateTime(
                  current.year, current.month, current.day)))) {
        count++;
      }
      current = current.add(Duration(days: 1));
    }
    return count;
  }

  Widget monthYearPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal.shade700),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: selectedMonth,
            icon: Icon(Icons.calendar_today, color: Colors.teal.shade700),
            underline: const SizedBox(),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.teal, fontSize: 16),
            items: List.generate(12, (index) {
              return DropdownMenuItem(
                value: index + 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(DateFormat.MMMM('id').format(DateTime(0, index + 1))),
                ),
              );
            }),
            onChanged: (int? newMonth) {
              if (newMonth != null) {
                setState(() {
                  selectedMonth = newMonth;
                  _isLoading = true;
                });
                _loadSalaryDataForPeriod(selectedMonth, selectedYear);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal.shade700),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: selectedYear,
            icon: Icon(Icons.calendar_today, color: Colors.teal.shade700),
            underline: const SizedBox(),
            dropdownColor: Colors.white,
            style: const TextStyle(color: Colors.teal, fontSize: 16),
            items: List.generate(10, (index) {
              int year = DateTime.now().year - 5 + index;
              return DropdownMenuItem(
                value: year,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(year.toString()),
                ),
              );
            }),
            onChanged: (int? newYear) {
              if (newYear != null) {
                setState(() {
                  selectedYear = newYear;
                  _isLoading = true;
                });
                _loadSalaryDataForPeriod(selectedMonth, selectedYear);
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gajiPokok = (salaryData?['gaji_pokok'] is num)
        ? salaryData!['gaji_pokok'].toInt()
        : 0;
    final gajiHarian = (salaryData?['gaji_harian'] is num)
        ? salaryData!['gaji_harian'].toInt()
        : 0;
    final potonganPerHari = (salaryData?['potongan_telat_per_hari'] is num)
        ? salaryData!['potongan_telat_per_hari'].toInt()
        : 0;
    final potonganGajiPokokPerHari = (salaryData?['potongan_tidak_masuk'] is num)
        ? salaryData!['potongan_tidak_masuk'].toInt()
        : 0;
    final potonganCutiPerHari = (salaryData?['potongan_cuti'] is num)
        ? salaryData!['potongan_cuti'].toInt()
        : 0;

    final totalGajiHarian = (presentDays > 0) ? gajiHarian * presentDays : 0;
    final potonganAbsent = (absentDays > 0) ? absentDays * potonganGajiPokokPerHari : 0;
    final potonganCuti = (leaveDays > 0) ? leaveDays * potonganCutiPerHari : 0;
    final totalPotonganTelat = lateDays * potonganPerHari;
    final totalGaji = ((totalGajiHarian - (potonganAbsent + potonganCuti)) + gajiPokok) - totalPotonganTelat;

    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: Text(
          'Laporan Gaji: ${widget.displayName}',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.teal.shade900,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edit Salary',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditSalaryPage(
                    userId: widget.userId,
                    displayName: widget.displayName,
                  ),
                ),
              );
              if (result == true) {
                setState(() {
                  _isLoading = true;
                });
                _loadSalaryDataForPeriod(selectedMonth, selectedYear);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Card(
                elevation: 6,
                margin: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 50, color: Colors.teal.shade700),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.teal.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      monthYearPicker(),
                      const SizedBox(height: 20),
                      _buildSalarySection(
                          'Gaji Pokok', gajiPokok, Icons.monetization_on),
                      _buildSalarySection('Tunjangan Harian', totalGajiHarian,
                          Icons.calendar_today, presentDays: presentDays),
                      _buildSalarySection('Potongan Tidak Masuk', potonganAbsent,
                          Icons.do_not_disturb_on, absentDays: absentDays),
                      _buildSalarySection('Potongan Terlambat', totalPotonganTelat,
                          Icons.timer_off, lateDays: lateDays),
                      _buildSalarySection('Potongan Cuti', potonganCuti,
                          Icons.event_busy, leaveDays: leaveDays),
                      const Divider(
                          height: 30, thickness: 2, color: Colors.grey),
                      _buildSalarySection(
                          'Total Gaji', totalGaji, Icons.savings, highlight: true),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _SalaryDetailsScreen(
                                displayName: widget.displayName,
                                gajiPokok: gajiPokok,
                                gajiHarian: gajiHarian,
                                potonganGajiPokokPerHari: potonganGajiPokokPerHari,
                                potonganCutiPerHari: potonganCutiPerHari,
                                potonganPerHari: potonganPerHari,
                                totalGajiHarian: totalGajiHarian,
                                potonganAbsent: potonganAbsent,
                                potonganCuti: potonganCuti,
                                totalPotonganTelat: totalPotonganTelat,
                                totalGaji: totalGaji,
                                presentDays: presentDays,
                                absentDays: absentDays,
                                leaveDays: leaveDays,
                                lateDays: lateDays,
                                selectedMonth: selectedMonth,
                                selectedYear: selectedYear,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Rincian',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSalarySection(String label, num value, IconData icon,
      {bool highlight = false, int? lateDays, int? absentDays, int? presentDays, int? leaveDays}) {
    final formatter = NumberFormat.decimalPattern('id');
    final formattedValue = 'Rp ${formatter.format(value)}' +
        (absentDays != null && absentDays > 0
            ? ' ($absentDays hari)'
            : lateDays != null && lateDays > 0
                ? ' ($lateDays hari)'
                : presentDays != null && presentDays > 0
                    ? ' ($presentDays hari)'
                    : leaveDays != null && leaveDays > 0
                        ? ' ($leaveDays hari)'
                        : '');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon,
            color: highlight ? Colors.orange : Colors.teal.shade700, size: 28),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            fontSize: highlight ? 18 : 16,
            color: highlight ? Colors.orange : Colors.black87,
          ),
        ),
        trailing: Text(
          formattedValue,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            fontSize: highlight ? 18 : 16,
            color: highlight ? Colors.orange : Colors.teal.shade900,
          ),
        ),
      ),
    );
  }
}

class _SalaryDetailsScreen extends StatelessWidget {
  final String displayName;
  final num gajiPokok;
  final num gajiHarian;
  final num potonganGajiPokokPerHari;
  final num potonganCutiPerHari;
  final num potonganPerHari;
  final num totalGajiHarian;
  final num potonganAbsent;
  final num potonganCuti;
  final num totalPotonganTelat;
  final num totalGaji;
  final int presentDays;
  final int absentDays;
  final int leaveDays;
  final int lateDays;
  final int selectedMonth;
  final int selectedYear;
  final String userId;

  const _SalaryDetailsScreen({
    required this.displayName,
    required this.gajiPokok,
    required this.gajiHarian,
    required this.potonganGajiPokokPerHari,
    required this.potonganCutiPerHari,
    required this.potonganPerHari,
    required this.totalGajiHarian,
    required this.potonganAbsent,
    required this.potonganCuti,
    required this.totalPotonganTelat,
    required this.totalGaji,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
    required this.lateDays,
    required this.selectedMonth,
    required this.selectedYear,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('id');
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: Text(
          'Rincian Gaji: $displayName',
          style: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.teal.shade900,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card(
          elevation: 6,
          margin: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Rincian Gaji untuk ${DateFormat.MMMM('id').format(DateTime(0, selectedMonth))} $selectedYear',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.teal.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Table(
                  border: TableBorder.all(color: Colors.teal.shade300, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(3),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.teal.shade100),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Komponen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Perhitungan & Jumlah', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Gaji Pokok'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Rp ${formatter.format(gajiPokok)}'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Gaji Harian'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Rp ${formatter.format(gajiHarian)} x $presentDays hari = Rp ${formatter.format(totalGajiHarian)}'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Potongan Tidak Masuk'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Rp ${formatter.format(potonganGajiPokokPerHari)} x $absentDays hari =  Rp ${formatter.format(potonganAbsent)}'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Potongan Cuti'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Rp ${formatter.format(potonganCutiPerHari)} x $leaveDays hari =  Rp ${formatter.format(potonganCuti)}'),
                        ),
                      ],
                    ),
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Potongan Terlambat'),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Rp ${formatter.format(potonganPerHari)} x $lateDays hari =  Rp ${formatter.format(totalPotonganTelat)}'),
                        ),
                      ],
                    ),
                    TableRow(
                      decoration: BoxDecoration(color: Colors.teal.shade100),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Total Gaji', style: TextStyle(fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 111, 37))),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Rp ${formatter.format(totalGaji)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 0, 111, 37)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SlipGajiPage(
                          nama: displayName,
                          divisi: 'Divisi Tidak Diketahui',
                          periode: '${DateFormat.MMMM('id').format(DateTime(0, selectedMonth))} $selectedYear',
                          gajiPokok: gajiPokok.toInt(),
                          gajiHarian: totalGajiHarian.toInt(),
                          potonganAbsent: potonganAbsent.toInt(),
                          potonganCuti: potonganCuti.toInt(),
                          totalPotonganTelat: totalPotonganTelat.toInt(),
                          totalGaji: totalGaji.toInt(),
                          userId: userId,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Slip Gaji',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}