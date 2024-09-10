import 'package:absensi_apps/Cuti/history_leave_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  double _leaveQuota = 0; // Menggunakan double untuk kuota cuti
  bool _isHalfDay = false; // Untuk pilihan cuti setengah hari
  double _calculatedLeaveDays = 0; // Untuk menyimpan jumlah hari cuti yang dihitung

  @override
  void initState() {
    super.initState();
    _getUserInfo();
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
      _calculatedLeaveDays = _endDate!.difference(_startDate!).inDays + 1;
      if (_isHalfDay) {
        _calculatedLeaveDays -= 0.5; // Mengurangi setengah hari dari total hari jika cuti setengah hari
      }
    } else {
      _calculatedLeaveDays = 0;
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (_startDate == null || _endDate == null || _keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua bidang')));
      return;
    }

    double leaveDays = _calculatedLeaveDays;

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
        'Keterangan': _keteranganController.text,
        'start_date': _startDate,
        'end_date': _endDate,
        'is_half_day': _isHalfDay, // Simpan informasi apakah cuti setengah hari
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
        _isHalfDay = false; // Reset cuti setengah hari
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 10),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 10),
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
              CheckboxListTile(
                title: const Text("Cuti Setengah Hari"),
                value: _isHalfDay,
                activeColor: Colors.teal.shade700, // Warna teal ketika dipilih
                onChanged: (bool? value) {
                  setState(() {
                    _isHalfDay = value ?? false;
                    _calculateLeaveDays(); // Hitung ulang jumlah hari jika opsi cuti setengah hari berubah
                  });
                },
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
              Text('Sisa Cuti: $_leaveQuota hari',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitLeaveApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700, // Warna tombol
                  minimumSize: const Size(double.infinity, 50),
                ),
                  child: const Text(
                  'Kirim Pengajuan',
                  style: TextStyle(color: Colors.white), // Teks putih
                ),
              ),
              const Divider(thickness: 1),
              ListTile(
                title: Text(
                  'Lihat Log Cuti',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700),
                ),
                trailing: Icon(Icons.arrow_forward,
                    size: 24, color: Colors.teal.shade700),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            HistoryLeavePage(userId: _userId)),
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
