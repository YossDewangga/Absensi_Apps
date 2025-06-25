import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

class SlipGajiPage extends StatefulWidget {
  final String nama;
  final String divisi;
  final String periode;
  final int gajiPokok;
  final int gajiHarian;
  final int potonganAbsent;
  final int potonganCuti;
  final int totalPotonganTelat;
  final int totalGaji;
  final String userId;

  const SlipGajiPage({
    super.key,
    required this.nama,
    required this.divisi,
    required this.periode,
    this.gajiPokok = 0,
    this.gajiHarian = 0,
    this.potonganAbsent = 0,
    this.potonganCuti = 0,
    this.totalPotonganTelat = 0,
    this.totalGaji = 0,
    required this.userId,
  });

  @override
  State<SlipGajiPage> createState() => _SlipGajiPageState();
}

class _SlipGajiPageState extends State<SlipGajiPage> {
  String _jabatan = 'Loading...';
  String _companyName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _fetchJabatanFromFirestore();
    _fetchCompanyNameFromFirestore();
  }

  Future<void> _fetchJabatanFromFirestore() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _jabatan = userData['department'] ?? 'Jabatan Tidak Diketahui';
          print('DEBUG: Jabatan diambil: $_jabatan');
        });
      } else {
        setState(() {
          _jabatan = 'Jabatan Tidak Diketahui';
        });
        print('DEBUG: Dokumen pengguna tidak ditemukan untuk jabatan');
      }
    } catch (e) {
      setState(() {
        _jabatan = 'Jabatan Tidak Diketahui';
      });
      print('DEBUG: Error mengambil jabatan: $e');
    }
  }

  Future<void> _fetchCompanyNameFromFirestore() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        String? companyName = userData['Company Name'] as String?;
        setState(() {
          _companyName = companyName ?? 'Nama Perusahaan Tidak Diketahui';
          print('DEBUG: Nama perusahaan diambil: $_companyName');
        });
      } else {
        setState(() {
          _companyName = 'Nama Perusahaan Tidak Diketahui';
        });
        print('DEBUG: Dokumen pengguna tidak ditemukan untuk nama perusahaan');
      }
    } catch (e) {
      setState(() {
        _companyName = 'Nama Perusahaan Tidak Diketahui';
      });
      print('DEBUG: Error mengambil nama perusahaan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern('id');
    final int totalPendapatan = widget.gajiPokok + widget.gajiHarian;
    final int totalPengurang = widget.potonganAbsent + widget.potonganCuti + widget.totalPotonganTelat;
    final int gajiBersih = totalPendapatan - totalPengurang;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slip Gaji', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[900],
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
          ),
        ],
      ),
      body: Container(
        color: Colors.teal[50],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SLIP GAJI',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[900],
                            letterSpacing: 2,
                          ),
                        ),
                        const Divider(
                          color: Colors.grey,
                          thickness: 2,
                          height: 20,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _companyName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Periode: ${widget.periode.isNotEmpty ? widget.periode : 'Periode Tidak Tersedia'}', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          Text('Nama Karyawan: ${widget.nama}', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          Text('Jabatan: $_jabatan', style: TextStyle(fontSize: 16, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PENDAPATAN',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                      verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                      top: BorderSide(color: Colors.grey[300]!, width: 1),
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(4),
                      1: FlexColumnWidth(2),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Gaji Pokok', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(widget.gajiPokok)}', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Tunjangan Harian', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(widget.gajiHarian)}', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey[200]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Total Penghasilan Bruto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(totalPendapatan)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'POTONGAN',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[900]),
                  ),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                      verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                      top: BorderSide(color: Colors.grey[300]!, width: 1),
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(4),
                      1: FlexColumnWidth(2),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Potongan Tidak Masuk', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(widget.potonganAbsent)}', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Potongan Cuti', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(widget.potonganCuti)}', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Potongan Terlambat', style: TextStyle(fontSize: 16, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(widget.totalPotonganTelat)}', style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey[200]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Total Pengurangan Bruto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text('Rp ${formatter.format(totalPengurang)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Table(
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                      verticalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                      top: BorderSide(color: Colors.grey[300]!, width: 1),
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(4),
                      1: FlexColumnWidth(2),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.teal[100]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text('TOTAL DITERIMA KARYAWAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal[900])),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text('Rp ${formatter.format(gajiBersih)}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.teal[900])),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Dicetak pada: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())} WIB',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      if (await _requestPermission()) {
        final formatter = NumberFormat.decimalPattern('id');
        final int totalPendapatan = widget.gajiPokok + widget.gajiHarian;
        final int totalPengurang = widget.potonganAbsent + widget.potonganCuti + widget.totalPotonganTelat;
        final int gajiBersih = totalPendapatan - totalPengurang;

        List<List<dynamic>> rows = [];

        rows.add(["SLIP GAJI"]);
        rows.add(["Nama Perusahaan", _companyName]);
        rows.add([]);
        rows.add(["Periode", widget.periode.isNotEmpty ? widget.periode : 'Periode Tidak Tersedia']);
        rows.add(["Nama Karyawan", widget.nama]);
        rows.add(["Jabatan", _jabatan]);
        rows.add([]);
        rows.add(["PENDAPATAN"]);
        rows.add(["Item", "Jumlah"]);
        rows.add(["Gaji Pokok", "Rp ${formatter.format(widget.gajiPokok)}"]);
        rows.add(["Tunjangan Harian", "Rp ${formatter.format(widget.gajiHarian)}"]);
        rows.add(["Total Penghasilan Bruto", "Rp ${formatter.format(totalPendapatan)}"]);
        rows.add([]);
        rows.add(["POTONGAN"]);
        rows.add(["Item", "Jumlah"]);
        rows.add(["Potongan Tidak Masuk", "Rp ${formatter.format(widget.potonganAbsent)}"]);
        rows.add(["Potongan Cuti", "Rp ${formatter.format(widget.potonganCuti)}"]);
        rows.add(["Potongan Terlambat", "Rp ${formatter.format(widget.totalPotonganTelat)}"]);
        rows.add(["Total Pengurangan Bruto", "Rp ${formatter.format(totalPengurang)}"]);
        rows.add([]);
        rows.add(["TOTAL DITERIMA KARYAWAN", "Rp ${formatter.format(gajiBersih)}"]);
        rows.add([]);
        rows.add(["Dicetak pada", DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now()) + " WIB"]);

        String csv = const ListToCsvConverter().convert(rows);
        final directory = await _getDownloadDirectory();

        String sanitizedNama = widget.nama.replaceAll(RegExp(r'[^\w\s]'), '_');
        String sanitizedPeriode = widget.periode.replaceAll(RegExp(r'[^\w\s]'), '_');
        final path = "${directory.path}/slip_gaji_${sanitizedNama}_${sanitizedPeriode}.csv";

        final File file = File(path);
        await file.writeAsString(csv);

        print('DEBUG: CSV disimpan di: $path');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Slip gaji berhasil diunduh ke $path')),
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