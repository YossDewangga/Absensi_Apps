import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminOvertimePage extends StatefulWidget {
  const AdminOvertimePage({Key? key}) : super(key: key);

  @override
  _AdminOvertimePageState createState() => _AdminOvertimePageState();
}

class _AdminOvertimePageState extends State<AdminOvertimePage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  String? _editableRecordId;

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
              AppBar(
                title: Column(
                  children: [
                    const Text('Overtime Management', style: TextStyle(color: Colors.black)),
                    Container(
                      margin: const EdgeInsets.only(top: 4.0),
                      height: 4.0,
                      width: 60.0,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ],
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.black),
                actions: [
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.cog, color: Colors.black),
                    onPressed: () {
                      _showSettingsDialog(context);
                    },
                  ),
                ],
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
                        ),
                      ),
                      isExpanded: _isCalendarExpanded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collectionGroup('overtime_records').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return ListView.builder(
                        itemCount: 10,
                        itemBuilder: (context, index) {
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
                        },
                      );
                    }

                    var records = snapshot.data!.docs;

                    records = records.where((record) {
                      var data = record.data() as Map<String, dynamic>;
                      var overtimeInTime = data['overtime_in_time'] != null
                          ? (data['overtime_in_time'] as Timestamp).toDate()
                          : null;
                      return overtimeInTime != null &&
                          overtimeInTime.year == _selectedDate.year &&
                          overtimeInTime.month == _selectedDate.month &&
                          overtimeInTime.day == _selectedDate.day;
                    }).toList();

                    if (records.isEmpty) {
                      return const Center(child: Text('No records found for the selected date.', style: TextStyle(color: Colors.black)));
                    }

                    return ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        var record = records[index];
                        var data = record.data() as Map<String, dynamic>;
                        var recordId = record.id;
                        var userId = record.reference.parent.parent!.id;

                        var userName = data['user_name'] ?? 'Unknown';
                        var overtimeInTime = data['overtime_in_time'] != null
                            ? (data['overtime_in_time'] as Timestamp).toDate()
                            : null;
                        var overtimeOutTime = data['overtime_out_time'] != null
                            ? (data['overtime_out_time'] as Timestamp).toDate()
                            : null;
                        var totalOvertime = overtimeInTime != null && overtimeOutTime != null
                            ? overtimeOutTime.difference(overtimeInTime)
                            : null;

                        var approvalStatus = data['approval_status'] ?? 'Disapproved';

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
                                _buildTable('Overtime In', userName, overtimeInTime, data['overtime_location'] as GeoPoint?),
                                Divider(thickness: 1),
                                _buildTable('Overtime Out', null, overtimeOutTime, data['overtime_out_location'] as GeoPoint?),
                                Divider(thickness: 1),
                                if (totalOvertime != null)
                                  _buildDurationTable('Total Overtime', _formattedDuration(totalOvertime)),
                                Divider(thickness: 1),
                                _buildApprovalRow(approvalStatus),
                                if (_editableRecordId == recordId)
                                  _buildApprovalButtons(context, userId, recordId, approvalStatus)
                                else
                                  _buildEditButton(recordId),
                              ],
                            ),
                          ),
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

  Table _buildTable(String timeType, String? userName, DateTime? time, GeoPoint? location) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        if (userName != null) _buildTableRow('User Name:', userName),
        _buildTableRow('$timeType:', time != null ? _formattedDateTime(time) : 'N/A'),
        _buildTableRow('Location:', location != null ? '${location.latitude}, ${location.longitude}' : 'N/A'),
      ],
    );
  }

  Table _buildDurationTable(String title, String content) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow(title, content),
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
    Color textColor = approvalStatus == 'Approved' ? Colors.green : Colors.red;
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

  Widget _buildApprovalButtons(BuildContext context, String userId, String recordId, String currentStatus) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    _updateApprovalStatus(context, userId, recordId, 'Approved');
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
                    _updateApprovalStatus(context, userId, recordId, 'Disapproved');
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

  void _updateApprovalStatus(BuildContext context, String userId, String recordId, String newStatus) {
    FirebaseFirestore.instance.collection('users').doc(userId)
        .collection('overtime_records').doc(recordId).update({
      'approval_status': newStatus,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'Approved' ? 'Overtime Approved' : 'Overtime Disapproved')),
      );
      setState(() {
        _editableRecordId = null;
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $error')),
      );
    });
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

  String _formattedDateTime(DateTime dateTime) {
    return "${dateTime.day}-${dateTime.month}-${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
  }

  String _formattedDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
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
