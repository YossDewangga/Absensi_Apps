import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class AdminLeavePage extends StatefulWidget {
  @override
  _AdminLeavePageState createState() => _AdminLeavePageState();
}

class _AdminLeavePageState extends State<AdminLeavePage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  String? _editableRecordId;
  Map<DateTime, List> _leaveEvents = {};

  @override
  void initState() {
    super.initState();
    _loadLeaveApplications();
    _checkAndResetLeaveQuota();
  }

  Future<void> _checkAndResetLeaveQuota() async {
    DateTime now = DateTime.now();
    if (now.month == 1 && now.day == 1) { // Misal reset setiap awal tahun
      try {
        QuerySnapshot userDocs = await FirebaseFirestore.instance.collection('users').get();
        for (var doc in userDocs.docs) {
          await doc.reference.update({
            'leave_quota': 12, // Reset ke 12 hari
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave quota has been reset for all users.')),
        );
      } catch (e) {
        print('Failed to reset leave quota: $e'); // Log for debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset leave quota: $e')),
        );
      }
    }
  }

  Future<void> _loadLeaveApplications() async {
    try {
      QuerySnapshot leaveDocs = await FirebaseFirestore.instance.collectionGroup('leave_applications').get();
      Map<DateTime, List> events = {};
      for (var doc in leaveDocs.docs) {
        var data = doc.data() as Map<String, dynamic>;
        DateTime submittedAt = (data['submitted_at'] as Timestamp).toDate();
        DateTime eventDate = DateTime(submittedAt.year, submittedAt.month, submittedAt.day);
        if (!events.containsKey(eventDate)) {
          events[eventDate] = [];
        }
        events[eventDate]!.add('Pengajuan Cuti');
      }
      setState(() {
        _leaveEvents = events;
      });
    } catch (e) {
      print('Failed to load leave applications: $e'); // Log for debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load leave applications: $e')),
      );
    }
  }

  List _getEventsForDay(DateTime day) {
    return _leaveEvents[day] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                ],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade700, // Mengatur warna latar belakang AppBar
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 4.0,
                    ),
                  ],
                ),
                child: AppBar(
                  title: Column(
                    children: [
                      Text('Pengajuan Cuti', style: TextStyle(color: Colors.white)),
                      Container(
                        margin: const EdgeInsets.only(top: 4.0),
                        height: 4.0,
                        width: 60.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ],
                  ),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0, // Hilangkan bayangan default AppBar
                  iconTheme: IconThemeData(color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ExpansionPanelList(
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      _isCalendarExpanded = !_isCalendarExpanded;
                    });
                  },
                  children: [
                    ExpansionPanel(
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          title: Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                      body: TableCalendar(
                        focusedDay: _selectedDate,
                        firstDay: DateTime(2000),
                        lastDay: DateTime(2100),
                        calendarFormat: CalendarFormat.month,
                        eventLoader: _getEventsForDay,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDate, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate = selectedDay;
                          });
                        },
                        calendarStyle: CalendarStyle(
                          selectedDecoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 1,
                          markerDecoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      isExpanded: _isCalendarExpanded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collectionGroup('leave_applications').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    var records = snapshot.data!.docs.where((record) {
                      var data = record.data() as Map<String, dynamic>;
                      DateTime submittedAt = (data['submitted_at'] as Timestamp).toDate();
                      return isSameDay(submittedAt, _selectedDate);
                    }).toList();

                    if (records.isEmpty) {
                      return Center(child: Text('Tidak ada pengajuan cuti.', style: TextStyle(color: Colors.black)));
                    }

                    return ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        var record = records[index];
                        var data = record.data() as Map<String, dynamic>;
                        var recordId = record.id;
                        var userId = record.reference.parent.parent!.id;

                        var keterangan = data['Keterangan'] ?? 'Tidak ada keterangan';
                        var startDate = data['start_date'] != null
                            ? (data['start_date'] as Timestamp).toDate()
                            : null;
                        var endDate = data['end_date'] != null
                            ? (data['end_date'] as Timestamp).toDate()
                            : null;
                        var status = data['status'] ?? 'Pending';
                        var submittedAt = data['submitted_at'] != null
                            ? (data['submitted_at'] as Timestamp).toDate()
                            : null;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return Card(
                                margin: const EdgeInsets.all(8.0),
                                elevation: 3.0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildPlaceholder(),
                                      _buildPlaceholder(),
                                      _buildPlaceholder(),
                                    ],
                                  ),
                                ),
                              );
                            }

                            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            var displayName = userData['displayName'] ?? 'Unknown';
                            var leaveQuota = userData['leave_quota'] ?? 12;

                            return Card(
                              margin: const EdgeInsets.all(8.0),
                              elevation: 3.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTable('Pengajuan Cuti', displayName, startDate, endDate, keterangan, leaveQuota),
                                    Divider(thickness: 1),
                                    Text(
                                      'Diajukan pada: ${submittedAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(submittedAt) : 'N/A'}',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Divider(thickness: 1),
                                    _buildApprovalRow(status),
                                    if (_editableRecordId == recordId)
                                      _buildApprovalButtons(context, userId, recordId, status, startDate, endDate, leaveQuota)
                                    else
                                      _buildEditButton(recordId),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Table _buildTable(String title, String displayName, DateTime? startDate, DateTime? endDate, String keterangan, int leaveQuota) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow('User Name:', displayName),
        _buildTableRow('Keterangan:', keterangan),
        _buildTableRow('Tanggal Mulai:', startDate != null ? DateFormat('yyyy-MM-dd').format(startDate) : 'N/A'),
        _buildTableRow('Tanggal Selesai:', endDate != null ? DateFormat('yyyy-MM-dd').format(endDate) : 'N/A'),
        _buildTableRow('Sisa Cuti:', leaveQuota.toString()),
      ],
    );
  }

  TableRow _buildTableRow(String title, String content) {
    return TableRow(
      children: [
        Container(
          padding: EdgeInsets.all(8.0),
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: EdgeInsets.all(8.0),
          child: Text(content),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(String approvalStatus) {
    Color textColor = approvalStatus == 'Approved' ? Colors.green : approvalStatus == 'Rejected' ? Colors.red : Colors.black;
    return Row(
      children: [
        Text(
          'Approval Status: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          approvalStatus,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalButtons(BuildContext context, String userId, String recordId, String currentStatus, DateTime? startDate, DateTime? endDate, int leaveQuota) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () async {
                    int leaveDays = endDate!.difference(startDate!).inDays + 1;
                    if (leaveQuota >= leaveDays) {
                      await _updateApprovalStatus(userId, recordId, 'Approved', startDate, endDate, leaveQuota);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Leave quota insufficient for approval.')),
                      );
                    }
                  },
                ),
                Text('Approve', style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red),
                  onPressed: () {
                    _updateApprovalStatus(userId, recordId, 'Rejected', startDate, endDate, leaveQuota);
                  },
                ),
                Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditButton(String recordId) {
    return Center(
      child: Column(
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              setState(() {
                _editableRecordId = recordId;
              });
            },
          ),
          Text('Edit', style: TextStyle(color: Colors.black, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _updateApprovalStatus(String userId, String recordId, String newStatus, DateTime? startDate, DateTime? endDate, int leaveQuota) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId)
          .collection('leave_applications').doc(recordId).update({
        'status': newStatus,
      });

      if (newStatus == 'Approved' && startDate != null && endDate != null) {
        int leaveDays = endDate.difference(startDate).inDays + 1;
        await _updateUserLeaveQuota(userId, leaveQuota - leaveDays);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'Approved' ? 'Leave Approved' : 'Leave Rejected')),
      );

      setState(() {
        _editableRecordId = null;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $error')),
      );
    }
  }

  Future<void> _updateUserLeaveQuota(String userId, int newQuota) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'leave_quota': newQuota,
      });
    } catch (error) {
      print('Failed to update leave quota: $error');
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Setting 1'),
                  trailing: Icon(Icons.settings),
                  onTap: () {
                    // Add your setting functionality here
                  },
                ),
                ListTile(
                  title: Text('Setting 2'),
                  trailing: Icon(Icons.settings),
                  onTap: () {
                    // Add your setting functionality here
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 20,
            color: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Peringatan"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
