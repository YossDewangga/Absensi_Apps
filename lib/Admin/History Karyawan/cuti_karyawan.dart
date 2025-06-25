import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class CutiPage extends StatefulWidget {
  final String? userId;

  const CutiPage({Key? key, required this.userId}) : super(key: key);

  @override
  _CutiPageState createState() => _CutiPageState();
}

class _CutiPageState extends State<CutiPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Cuti', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.teal.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: Text('User ID tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Cuti', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        elevation: 4.0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
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
                      .collection('leave_applications')
                      .orderBy('submitted_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      print('DEBUG: Error mengambil data cuti: ${snapshot.error}');
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      print('DEBUG: Tidak ada data cuti ditemukan untuk userId: ${widget.userId}');
                      return const Center(child: Text('Belum ada data cuti'));
                    }

                    var records = snapshot.data!.docs;
                    print('DEBUG: Jumlah dokumen cuti ditemukan: ${records.length}');

                    return DataTable(
                      border: TableBorder.all(
                        color: Colors.teal.shade700,
                        width: 1.0,
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Nama',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Tanggal Mulai',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Tanggal Selesai',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Keterangan',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                      rows: records.asMap().entries.map((entry) {
                        int index = entry.key;
                        var record = entry.value;
                        var data = record.data() as Map<String, dynamic>;

                        var displayName = data['displayName'] ?? 'N/A';
                        var startDate = data['start_date'] != null
                            ? (data['start_date'] as Timestamp).toDate()
                            : null;
                        var endDate = data['end_date'] != null
                            ? (data['end_date'] as Timestamp).toDate()
                            : null;
                        var keterangan = data['Keterangan'] ?? 'N/A';
                        var status = data['status'] ?? 'Pending';

                        Color rowColor = index.isEven ? Colors.teal.shade50 : Colors.white;

                        print('DEBUG: Dokumen cuti: ID=${record.id}, displayName=$displayName, startDate=$startDate, endDate=$endDate, keterangan=$keterangan, status=$status');

                        return DataRow(
                          color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                            return rowColor;
                          }),
                          cells: [
                            DataCell(Text(displayName)),
                            DataCell(Text(startDate != null ? _formattedDate(startDate) : 'N/A')),
                            DataCell(Text(endDate != null ? _formattedDate(endDate) : 'N/A')),
                            DataCell(Text(keterangan)),
                            DataCell(
                              status.toLowerCase() == 'pending'
                                  ? const Icon(Icons.pending, color: Colors.orange)
                                  : status.toLowerCase() == 'approved'
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.cancel, color: Colors.red),
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

  Future<void> _exportToCSV() async {
    try {
      if (await _requestPermission()) {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('leave_applications')
            .orderBy('submitted_at', descending: true)
            .get();

        List<List<dynamic>> rows = [];

        rows.add([
          "Nama",
          "Tanggal Mulai",
          "Tanggal Selesai",
          "Keterangan",
          "Status",
        ]);

        for (var record in snapshot.docs) {
          var data = record.data() as Map<String, dynamic>;
          var displayName = data['displayName'] ?? 'N/A';
          var startDate = data['start_date'] != null
              ? (data['start_date'] as Timestamp).toDate()
              : null;
          var endDate = data['end_date'] != null
              ? (data['end_date'] as Timestamp).toDate()
              : null;
          var keterangan = data['Keterangan'] ?? 'N/A';
          var status = data['status'] ?? 'Pending';

          List<dynamic> row = [
            _padRight(displayName, 20),
            _padRight(startDate != null ? _formattedDate(startDate) : 'N/A', 15),
            _padRight(endDate != null ? _formattedDate(endDate) : 'N/A', 15),
            _padRight(keterangan, 30),
            _padRight(status, 10),
          ];
          rows.add(row);
        }

        String csv = const ListToCsvConverter().convert(rows);
        final directory = await _getDownloadDirectory();

        String currentTime = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final path = "${directory.path}/cuti_${widget.userId}_$currentTime.csv";

        final File file = File(path);
        await file.writeAsString(csv);

        print('DEBUG: CSV disimpan di: $path');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data cuti berhasil diunduh ke $path')),
        );
      } else {
        print('DEBUG: Izin penyimpanan ditolak');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Izin akses penyimpanan ditolak.'),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: _openAppSettings,
            ),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error saat ekspor CSV: $e');
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
    print('DEBUG: Status izin penyimpanan: $status');

    if (!status.isGranted) {
      status = await Permission.storage.request();
      print('DEBUG: Status izin penyimpanan setelah permintaan: $status');
    }

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      print('DEBUG: Izin penyimpanan ditolak secara permanen');
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