import 'package:absensi_apps/Logbook/history_activity_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LogbookPage extends StatefulWidget {
  @override
  _LogbookPageState createState() => _LogbookPageState();
}

class _LogbookPageState extends State<LogbookPage> {
  final TextEditingController _activityController = TextEditingController();
  final List<Map<String, dynamic>> _logbookEntries = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadLogbookEntries();
  }

  @override
  void dispose() {
    _saveLogbookEntries();
    super.dispose();
  }

  Future<void> _getUserInfo() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userId = user.uid;
        });
      } else {
        print("User belum login.");
      }
    } catch (e) {
      print("Terjadi kesalahan saat mengambil informasi pengguna: $e");
    }
  }

  Future<void> _loadLogbookEntries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? logbookEntriesString = prefs.getString('logbook_entries');
    if (logbookEntriesString != null) {
      List<dynamic> logbookEntriesList = jsonDecode(logbookEntriesString);
      setState(() {
        _logbookEntries.addAll(logbookEntriesList.map((entry) => Map<String, dynamic>.from(entry)).toList());
      });
    }
  }

  Future<void> _saveLogbookEntries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String logbookEntriesString = jsonEncode(_logbookEntries);
    await prefs.setString('logbook_entries', logbookEntriesString);
  }

  void _addLogbookEntry() {
    if (_startTime != null && _endTime != null && _activityController.text.isNotEmpty) {
      setState(() {
        _logbookEntries.add({
          'activity': _activityController.text,
          'start_time': _startTime!.format(context),
          'end_time': _endTime!.format(context),
        });
        _activityController.clear();
        _startTime = null;
        _endTime = null;
      });
      _saveLogbookEntries();
    } else {
      _showWarningDialog("Harap isi semua kolom sebelum menambahkan entri.");
    }
  }

  Future<void> _submitLogbook() async {
    if (_logbookEntries.isEmpty || _userId == null) return;
    for (var entry in _logbookEntries) {
      if (entry['start_time'] == null || entry['end_time'] == null || entry['activity'].isEmpty) {
        _showWarningDialog("Harap pastikan semua entri memiliki waktu mulai, selesai, dan aktivitas.");
        return;
      }
    }

    CollectionReference logbookCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('daily_logbook');

    List<Map<String, dynamic>> formattedEntries = _logbookEntries.map((entry) {
      return {
        'activity': entry['activity'],
        'start_time': DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          int.parse(entry['start_time'].split(":")[0]),
          int.parse(entry['start_time'].split(":")[1]),
        ),
        'end_time': DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          int.parse(entry['end_time'].split(":")[0]),
          int.parse(entry['end_time'].split(":")[1]),
        ),
      };
    }).toList();

    await logbookCollection.add({
      'logbook_entries': formattedEntries,
      'last_updated': FieldValue.serverTimestamp(),
    });

    setState(() {
      _logbookEntries.clear();
    });
    _saveLogbookEntries();
    _showSuccessDialog("Logbook submitted successfully.");
  }

  Widget _buildTimePicker(String label, TimeOfDay? selectedTime, Function(TimeOfDay) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
        SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final TimeOfDay? time = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
            );
            if (time != null) {
              onChanged(time);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal.shade700, width: 1.0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              selectedTime?.format(context) ?? '--:--',
              style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
            ),
          ),
        ),
      ],
    );
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 10),
              Text("Peringatan"),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text("OK", style: TextStyle(color: Colors.teal.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text(
                  "Sukses"
              ),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text(
                  "OK",
                  style: TextStyle(
                      color: Colors.teal.shade700
                  )),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            "Logbook Harian",
            style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade900
        )),
        SizedBox(height: 10),
        Text(
            "Catat aktivitas harian Anda dengan detail",
            style: TextStyle(
                color: Colors.teal.shade900
            )),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _addLogbookEntry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
            child: Text(
              "Tambahkan Entri",
              style: TextStyle(color: Colors.white), // Teks menjadi putih
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _submitLogbook,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
            ),
            child: Text(
              "Submit Logbook",
              style: TextStyle(color: Colors.white), // Teks menjadi putih
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogbookEntries() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.shade700, width: 1.0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.teal.shade700),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
            ),
            children: [
              _buildTableCell("Mulai", isHeader: true),
              _buildTableCell("Selesai", isHeader: true),
              _buildTableCell("Aktivitas", isHeader: true),
            ],
          ),
          ..._logbookEntries.map((entry) {
            return TableRow(
              children: [
                _buildTableCell(entry['start_time'] ?? '--:--'),
                _buildTableCell(entry['end_time'] ?? '--:--'),
                _buildTableCell(entry['activity'] ?? 'No activity'),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
          color: isHeader ? Colors.teal.shade900 : Colors.teal.shade700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Logbook Harian"),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildTimePicker("Mulai", _startTime, (time) {
                      setState(() {
                        _startTime = time;
                      });
                    }),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePicker("Selesai", _endTime, (time) {
                      setState(() {
                        _endTime = time;
                      });
                    }),
                  ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: _activityController,
                decoration: InputDecoration(
                  labelText: "Aktivitas",
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.teal.shade900),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade900),
                  ),
                ),
                style: TextStyle(color: Colors.teal.shade900),
              ),
              SizedBox(height: 20),
              _buildButtons(),
              SizedBox(height: 20),
              Text("Daftar Entri:", style: TextStyle(color: Colors.teal.shade700)),
              SizedBox(height: 10),
              _buildLogbookEntries(),
              Divider(thickness: 1),
              ListTile(
                title: Text(
                  'Lihat Log Aktivitas',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700
                  ),
                ),
                trailing: Icon(
                    Icons.arrow_forward,
                    size: 24,
                    color: Colors.teal.shade700
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HistoryLogbookPage()),
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
