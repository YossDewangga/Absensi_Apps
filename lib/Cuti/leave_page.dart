import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'history_leave_page.dart';

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
  int _leaveQuota = 0;

  @override
  void initState() {
    super.initState();
    _loadFormTemplate();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        setState(() {
          _displayName = userDoc['displayName'];
          _leaveQuota = userDoc['leave_quota'];
        });
      } else {
        _showSnackBar('User not found in Firestore.');
      }
    } else {
      _showSnackBar('User not logged in.');
    }
  }

  Future<void> _loadFormTemplate() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('leave_forms').doc('form_template').get();
      if (doc.exists) {
        setState(() {
          _keteranganController.text = doc['Keterangan'] ?? '';
          _startDate = (doc['start_date'] as Timestamp).toDate();
          _endDate = (doc['end_date'] as Timestamp).toDate();
          _startDateString = DateFormat('yyyy-MM-dd').format(_startDate!);
          _endDateString = DateFormat('yyyy-MM-dd').format(_endDate!);
        });
      } else {
        print('Dokumen tidak ada');
      }
    } catch (e) {
      print('Gagal memuat template form: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = now.add(Duration(days: 7));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: now,
      lastDate: DateTime(2030),
      selectableDayPredicate: (DateTime date) {
        return date.isAfter(now.add(Duration(days: 6)));
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
      });
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (_startDate == null || _endDate == null || _keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Harap isi semua bidang')));
      return;
    }

    int leaveDays = _endDate!.difference(_startDate!).inDays + 1;
    if (_leaveQuota < leaveDays) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sisa cuti tidak mencukupi untuk pengajuan ini')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_userId == null) {
        throw 'User ID is null';
      }

      // Simpan data pengajuan cuti ke sub-koleksi leave_applications di dalam dokumen pengguna
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
      await userDocRef.collection('leave_applications').add({
        'displayName': _displayName,
        'userId': _userId,
        'Keterangan': _keteranganController.text,
        'start_date': _startDate,
        'end_date': _endDate,
        'status': 'Pending',
        'submitted_at': DateTime.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pengajuan cuti berhasil diajukan')));
      _keteranganController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _startDateString = 'Pilih Tanggal Mulai';
        _endDateString = 'Pilih Tanggal Selesai';
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
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengajuan Cuti'),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Formulir Pengajuan Cuti',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tanggal Mulai'),
                        SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tanggal Selesai'),
                        SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              SizedBox(height: 20),
              TextField(
                controller: _keteranganController,
                decoration: InputDecoration(
                  labelText: 'Keterangan',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              Text('Sisa Cuti: $_leaveQuota hari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              _isSubmitting
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submitLeaveApplication,
                child: Text('Kirim Pengajuan'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              Divider(thickness: 1),
              ListTile(
                title: Text(
                  'Lihat Log Cuti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LeaveHistoryPage(userId: _userId)),
                  );
                },
              ),
              Divider(thickness: 1),
            ],
          ),
        ),
      ),
    );
  }
}
