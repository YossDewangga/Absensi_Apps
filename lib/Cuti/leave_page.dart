import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:absensi_apps/Cuti/history_leave_page.dart';

import '../Super Admin/super_admin_page.dart'; // Dipertahankan untuk fitur "Lihat Log Cuti"


class LeaveApplicationPage extends StatefulWidget {
  @override
  _LeaveApplicationPageState createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  final TextEditingController _keteranganController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _startDateString = 'Pilih Tanggal Mulai';
  String _endDateString = 'Pilih Tanggal Selesai';
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _userId;
  String? _displayName;
  String? _companyName; // Tambahkan variabel untuk Company Name
  double _leaveQuota = 0; // Menggunakan double untuk kuota cuti
  double _calculatedLeaveDays = 0; // Untuk menyimpan jumlah hari cuti yang dihitung
  Map<String, dynamic>? _userData;
  List<dynamic> _userAccess = [];
  bool _isLoadingUserAccess = true;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _fetchUserAccess(); // Ambil akses user
  }

  Future<void> _getUserInfo() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userId = user.uid;
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();
        if (userDoc.exists) {
          Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
          if (userData != null && !userData.containsKey('leave_quota')) {
            // Inisialisasi leave_quota jika tidak ada
            await userDoc.reference.update({'leave_quota': 12});
          }

          setState(() {
            _displayName = userData?['displayName'];
            _leaveQuota = (userData?['leave_quota'] ?? 12).toDouble(); // Default 12 jika tidak disetel
          });
          await _getUserCompanyName(); // Panggil metode terpisah untuk Company Name
        } else {
          _showSnackBar('User tidak ditemukan di Firestore.');
        }
      } else {
        _showSnackBar('User belum login.');
      }
    } catch (e) {
      _showSnackBar('Gagal memuat info pengguna: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserCompanyName() async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('users').doc(_userId).get();
      if (userSnapshot.exists) {
        setState(() {
          _companyName = userSnapshot['Company Name'] ?? ''; // Menggunakan 'Company Name' dengan spasi
          print('Company Name from User: $_companyName');
        });
        if (_companyName == null || _companyName!.isEmpty) {
          print("Nama perusahaan tidak valid");
          _showSnackBar("Nama perusahaan tidak valid. Silakan hubungi admin.");
        }
      } else {
        print('Dokumen pengguna tidak ditemukan');
        _showSnackBar('Dokumen pengguna tidak ditemukan');
      }
    } catch (e) {
      print('Error saat mengambil Company Name: $e');
      _showSnackBar('Gagal mengambil nama perusahaan: $e');
    }
  }

  Future<void> _fetchUserAccess() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userSnapshot.exists) {
          setState(() {
            _userData = userSnapshot.data() as Map<String, dynamic>?;
            _userAccess = _userData?['access'] ?? [];
            _isLoadingUserAccess = false;
          });
        } else {
          setState(() {
            _isLoadingUserAccess = false;
          });
        }
      } else {
        setState(() {
          _isLoadingUserAccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUserAccess = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now.add(const Duration(days: 7));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: now,
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime date) {
        return date.isAfter(now.add(const Duration(days: 6)));
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateString = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _endDate = picked;
          _endDateString = DateFormat('yyyy-MM-dd').format(picked);
        }
        _calculateLeaveDays(); // Hitung jumlah hari cuti setiap kali tanggal dipilih
      });
    }
  }

  void _calculateLeaveDays() {
    if (_startDate != null && _endDate != null) {
      _calculatedLeaveDays = _endDate!.difference(_startDate!).inDays + 1; // Hitung hari penuh
    } else {
      _calculatedLeaveDays = 0;
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (_startDate == null || _endDate == null || _keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua bidang')));
      return;
    }

    if (_companyName == null || _companyName!.isEmpty) {
      await _getUserCompanyName();
      if (_companyName == null || _companyName!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama perusahaan tidak valid. Silakan hubungi admin.')));
        return;
      }
    }

    double leaveDays = _calculatedLeaveDays;

    // Validasi: Pastikan tanggal selesai tidak sebelum tanggal mulai
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal selesai harus setelah tanggal mulai')));
      return;
    }

    // Cek apakah sisa cuti mencukupi
    if (_leaveQuota < leaveDays) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sisa cuti tidak mencukupi untuk pengajuan ini')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_userId == null) {
        throw 'User ID tidak ditemukan';
      }

      // Simpan data pengajuan cuti ke sub-koleksi leave_applications di dalam dokumen pengguna
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
      await userDocRef.collection('leave_applications').add({
        'displayName': _displayName,
        'userId': _userId,
        'Company Name': _companyName, // Tambahkan Company Name
        'Keterangan': _keteranganController.text,
        'start_date': _startDate,
        'end_date': _endDate,
        'status': 'Pending', // Status awal adalah Pending
        'submitted_at': DateTime.now(),
        'leave_days': leaveDays, // Simpan jumlah hari cuti
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan cuti berhasil diajukan')));
      _keteranganController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _startDateString = 'Pilih Tanggal Mulai';
        _endDateString = 'Pilih Tanggal Selesai';
        _calculatedLeaveDays = 0; // Reset perhitungan hari cuti
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengajukan cuti: $e')));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pengajuan Cuti'),
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_userAccess.contains('cuti')) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pengajuan Cuti'),
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
        ),
        body: const NoAccessWidget(featureName: 'Cuti'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Cuti'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Formulir Pengajuan Cuti',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal Mulai'),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _selectDate(context, true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(_startDateString),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal Selesai'),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _selectDate(context, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(_endDateString),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_calculatedLeaveDays > 0)
                      Center(
                        child: Text(
                          'Jumlah Hari Cuti: $_calculatedLeaveDays hari',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _keteranganController,
                      decoration: const InputDecoration(
                        labelText: 'Keterangan',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sisa Cuti: $_leaveQuota hari',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitLeaveApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text(
                              'Kirim Pengajuan',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                    const Divider(thickness: 1),
                    ListTile(
                      title: Text(
                        'Lihat Log Cuti',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward,
                        size: 24,
                        color: Colors.teal.shade700,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryLeavePage(userId: _userId),
                          ),
                        );
                      },
                    ),
                    const Divider(thickness: 1),
                  ],
                ),
              ),
            ),
    );
  }
}