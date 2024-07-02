import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminAbsensiPage extends StatefulWidget {
  const AdminAbsensiPage({Key? key}) : super(key: key);

  @override
  _AdminAbsensiPageState createState() => _AdminAbsensiPageState();
}

class _AdminAbsensiPageState extends State<AdminAbsensiPage> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _designatedStartTime;
  TimeOfDay? _designatedEndTime;
  bool _isCalendarExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadDesignatedTimes();
  }

  void _loadDesignatedTimes() async {
    try {
      DocumentSnapshot startSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('designatedStartTime')
          .get();

      DocumentSnapshot endSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('designatedEndTime')
          .get();

      if (startSnapshot.exists) {
        Timestamp timestamp = startSnapshot['time'];
        DateTime dateTime = timestamp.toDate();
        setState(() {
          _designatedStartTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
        });
      }

      if (endSnapshot.exists) {
        Timestamp timestamp = endSnapshot['time'];
        DateTime dateTime = timestamp.toDate();
        setState(() {
          _designatedEndTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
        });
      }
    } catch (e) {
      print('Error loading designated times: $e');
      _showAlertDialog('Error loading designated times: $e');
    }
  }

  void _saveDesignatedTime(TimeOfDay time, String docId) {
    DateTime now = DateTime.now();
    DateTime designatedTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    FirebaseFirestore.instance.collection('settings').doc(docId).set({
      'time': Timestamp.fromDate(designatedTime),
    }).catchError((error) {
      print('Error saving designated time: $error');
      _showAlertDialog('Error saving designated time: $error');
    });
  }

  Future<void> _selectTime(BuildContext context, String docId) async {
    String timeType = docId == 'designatedStartTime' ? 'start' : 'end';
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: docId == 'designatedStartTime'
          ? (_designatedStartTime ?? TimeOfDay.now())
          : (_designatedEndTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (docId == 'designatedStartTime') {
          _designatedStartTime = picked;
        } else {
          _designatedEndTime = picked;
        }
        _saveDesignatedTime(picked, docId);
        _showAlertDialog('You selected the $timeType time: ${picked.format(context)}');
      });
    }
  }

  void _updateApprovalStatus(String userId, String recordId, String newStatus) {
    FirebaseFirestore.instance.collection('users').doc(userId)
        .collection('clockin_records').doc(recordId).update({
      'approval_status': newStatus,
    }).catchError((error) {
      print('Error updating approval status: $error');
      _showAlertDialog('Error updating approval status: $error');
    });
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
              AppBar(
                title: Column(
                  children: [
                    const Text('Absensi Approval', style: TextStyle(color: Colors.black)),
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
                  stream: FirebaseFirestore.instance.collectionGroup('clockin_records').snapshots(),
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
                      var clockInTime = data['clock_in_time'] != null
                          ? (data['clock_in_time'] as Timestamp).toDate()
                          : null;
                      return clockInTime != null &&
                          clockInTime.year == _selectedDate.year &&
                          clockInTime.month == _selectedDate.month &&
                          clockInTime.day == _selectedDate.day;
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
                        var userId = record.reference.parent.parent!.id; // Mengambil userId dari parent

                        var userName = data['user_name'] ?? 'Unknown';
                        var clockInTime = data['clock_in_time'] != null
                            ? (data['clock_in_time'] as Timestamp).toDate()
                            : null;
                        var clockOutTime = data['clock_out_time'] != null
                            ? (data['clock_out_time'] as Timestamp).toDate()
                            : null;
                        var workingHours = clockInTime != null && clockOutTime != null
                            ? clockOutTime.difference(clockInTime)
                            : null;
                        var logbookEntries = data['logbook_entries'] != null
                            ? List<Map<String, dynamic>>.from(data['logbook_entries'])
                            : <Map<String, dynamic>>[];
                        var imageUrl = data['image_url'] ?? '';
                        var lateDuration = clockInTime != null && _designatedStartTime != null
                            ? _calculateLateDuration(clockInTime, _designatedStartTime!)
                            : null;

                        var approvalStatus = data['approval_status'] ?? 'Disapproved';
                        var showEditIcon = approvalStatus == 'Disapproved';

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
                                _buildTable('Time In', userName, clockInTime, imageUrl, data['clockin_location'] as GeoPoint?),
                                Divider(thickness: 1),
                                _buildTable('Time Out', null, clockOutTime, null, data['clockout_location'] as GeoPoint?),
                                Divider(thickness: 1),
                                if (workingHours != null)
                                  _buildDurationTable('Working Hours', _formattedDuration(workingHours)),
                                if (lateDuration != null)
                                  _buildDurationTable('Late Duration', _formattedDuration(lateDuration)),
                                if (logbookEntries.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Logbook Entries:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Table(
                                        border: TableBorder.all(color: Colors.grey),
                                        columnWidths: const {
                                          0: FixedColumnWidth(100),
                                          1: FlexColumnWidth(),
                                        },
                                        children: logbookEntries.map((entry) {
                                          return TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(entry['time_range'] ?? 'N/A'),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(entry['activity'] ?? 'N/A'),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                Divider(thickness: 1),
                                _buildApprovalRow(approvalStatus, userId, recordId, showEditIcon),
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

  Table _buildTable(String timeType, String? userName, DateTime? time, String? imageUrl, GeoPoint? location) {
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
        if (imageUrl != null && timeType == 'Time In')
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Image:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () => _showFullImage(context, imageUrl),
                  child: Image.network(
                    imageUrl,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
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
        _buildTableRow(title, content, isLateDuration: title == 'Late Duration'),
      ],
    );
  }

  TableRow _buildTableRow(String title, String content, {bool isLateDuration = false}) {
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
          child: Text(
            content,
            style: isLateDuration
                ? TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                : TextStyle(),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(String approvalStatus, String userId, String recordId, bool showEditIcon) {
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
        if (showEditIcon)
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              _showApprovalDialog(context, userId, recordId, approvalStatus);
            },
          ),
      ],
    );
  }

  void _showApprovalDialog(BuildContext context, String userId, String recordId, String currentStatus) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Approval Status'),
          content: Text('Do you want to change the approval status?'),
          actions: [
            TextButton(
              onPressed: () {
                String newStatus = currentStatus == 'Approved' ? 'Disapproved' : 'Approved';
                _updateApprovalStatus(userId, recordId, newStatus);
                Navigator.of(context).pop();
              },
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('No'),
            ),
          ],
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

  String _formattedDate(DateTime date) {
    return "${date.day}-${date.month}-${date.year}";
  }

  String _formattedDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Duration _calculateLateDuration(DateTime clockInTime, TimeOfDay designatedStartTime) {
    DateTime designatedStartDateTime = DateTime(clockInTime.year, clockInTime.month, clockInTime.day, designatedStartTime.hour, designatedStartTime.minute);
    if (clockInTime.isAfter(designatedStartDateTime)) {
      return clockInTime.difference(designatedStartDateTime);
    } else {
      return Duration.zero;
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
                  title: Text('Set Start Time'),
                  subtitle: _designatedStartTime != null
                      ? Text('Current: ${_designatedStartTime!.format(context)}')
                      : null,
                  trailing: Icon(Icons.access_time),
                  onTap: () {
                    Navigator.pop(context);
                    _selectTime(context, 'designatedStartTime');
                  },
                ),
                ListTile(
                  title: Text('Set End Time'),
                  subtitle: _designatedEndTime != null
                      ? Text('Current: ${_designatedEndTime!.format(context)}')
                      : null,
                  trailing: Icon(Icons.access_time),
                  onTap: () {
                    Navigator.pop(context);
                    _selectTime(context, 'designatedEndTime');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(0),
          backgroundColor: Colors.black,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
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
