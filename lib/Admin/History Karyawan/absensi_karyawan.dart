import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class AbsensiPage extends StatefulWidget {
  final String userId;
  final int selectedMonth;
  final int selectedYear;

  const AbsensiPage({
    Key? key,
    required this.userId,
    required this.selectedMonth,
    required this.selectedYear,
  }) : super(key: key);

  @override
  _AbsensiPageState createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabel Absensi', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        elevation: 4.0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .collection('clockin_records')
                      .where(
                      'clock_in_time',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(widget.selectedYear, widget.selectedMonth - 1, 22)))
                      .where(
                      'clock_in_time',
                      isLessThanOrEqualTo: Timestamp.fromDate(
                          DateTime(widget.selectedYear, widget.selectedMonth, 21)))
                      .orderBy('clock_in_time', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Belum ada data clock in/out'));
                    }

                    var records = snapshot.data!.docs;

                    return DataTable(
                      border: TableBorder.all(
                        color: Colors.teal.shade700,
                        width: 1.0,
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Hari',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Clock In',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Clock Out',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Late Duration',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Late Reason',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Approved',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                      rows: records.asMap().entries.map((entry) {
                        int index = entry.key;
                        var record = entry.value;

                        var data = record.data() as Map<String, dynamic>;

                        var clockInTime = data['clock_in_time'] != null
                            ? (data['clock_in_time'] as Timestamp).toDate()
                            : null;
                        var clockOutTime = data['clock_out_time'] != null
                            ? (data['clock_out_time'] as Timestamp).toDate()
                            : null;
                        var lateDuration = data['late_duration'] ?? 'N/A';
                        var lateReason = data['late_reason'] ?? 'N/A';
                        var approved = data['approved'] as bool?;

                        Color rowColor = index.isEven ? Colors.teal.shade50 : Colors.white;

                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                            return rowColor;
                          }),
                          cells: [
                            DataCell(Text(clockInTime != null ? _formattedDay(clockInTime) : 'N/A')),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(clockInTime != null ? _formattedDate(clockInTime) : 'N/A'),
                                  Text(clockInTime != null ? _formattedTime(clockInTime) : ''),
                                ],
                              ),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(clockOutTime != null ? _formattedDate(clockOutTime) : 'N/A'),
                                  Text(clockOutTime != null ? _formattedTime(clockOutTime) : ''),
                                ],
                              ),
                            ),
                            DataCell(Text(lateDuration)),
                            DataCell(Text(lateReason)),
                            DataCell(
                              approved == null
                                  ? Icon(Icons.pending, color: Colors.orange)
                                  : approved
                                  ? Icon(Icons.check_circle, color: Colors.green)
                                  : Icon(Icons.cancel, color: Colors.red),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate(DateTime dateTime) {
    return DateFormat('dd-MM-yyyy').format(dateTime);
  }

  String _formattedTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formattedDay(DateTime dateTime) {
    return DateFormat('EEEE').format(dateTime);
  }

  Future<void> _exportToCSV() async {
    try {
      if (await _requestPermission()) {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('clockin_records')
            .where(
            'clock_in_time',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(widget.selectedYear, widget.selectedMonth - 1, 22)))
            .where(
            'clock_in_time',
            isLessThanOrEqualTo: Timestamp.fromDate(
                DateTime(widget.selectedYear, widget.selectedMonth, 21)))
            .orderBy('clock_in_time', descending: false)
            .get();

        List<List<dynamic>> rows = [];

        rows.add([
          // Kolom Nama dihapus dari sini
          "Hari",
          "Clock In Date",
          "Clock In Time",
          "Clock Out Date",
          "Clock Out Time",
          "Late Duration",
          "Late Reason",
          "Approved"
        ]);

        for (var record in snapshot.docs) {
          var data = record.data() as Map<String, dynamic>;
          var clockInTime = data['clock_in_time'] != null
              ? (data['clock_in_time'] as Timestamp).toDate()
              : null;
          var clockOutTime = data['clock_out_time'] != null
              ? (data['clock_out_time'] as Timestamp).toDate()
              : null;
          var lateDuration = data['late_duration'] ?? 'N/A';
          var lateReason = data['late_reason'] ?? 'N/A';
          var approved = data['approved'] as bool?;

          List<dynamic> row = [
            // Data Nama dihapus dari sini
            _padRight(clockInTime != null ? _formattedDay(clockInTime) : 'N/A', 10),
            _padRight(clockInTime != null ? _formattedDate(clockInTime) : 'N/A', 15),
            _padRight(clockInTime != null ? _formattedTime(clockInTime) : 'N/A', 10),
            _padRight(clockOutTime != null ? _formattedDate(clockOutTime) : 'N/A', 15),
            _padRight(clockOutTime != null ? _formattedTime(clockOutTime) : 'N/A', 10),
            _padRight(lateDuration, 10),
            _padRight(lateReason, 20),
            _padRight(approved == null ? 'Pending' : approved ? 'Approved' : 'Rejected', 10),
          ];
          rows.add(row);
        }

        String csv = const ListToCsvConverter().convert(rows);
        final directory = await _getDownloadDirectory();

        String currentMonth = DateFormat('MMMM_yyyy').format(DateTime(widget.selectedYear, widget.selectedMonth));
        final path = "${directory.path}/absensi_$currentMonth.csv";

        final File file = File(path);
        await file.writeAsString(csv);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data berhasil diunduh ke $path')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Izin akses penyimpanan ditolak.'),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: _openAppSettings,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  String _padRight(String text, int width) {
    return text.padRight(width);
  }

  Future<bool> _requestPermission() async {
    var status = await Permission.storage.status;
    print('Storage permission status: $status');

    if (!status.isGranted) {
      status = await Permission.storage.request();
      print('Storage permission after request: $status');
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      print('Permission is permanently denied.');
      return false;
    }

    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    return false;
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  void _openAppSettings() {
    openAppSettings();
  }
}
