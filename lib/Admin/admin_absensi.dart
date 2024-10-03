import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';


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
  String? _editableRecordId;
  DateTime? _clockInDate;
  bool _showEditIcon = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await _loadDesignatedTimes();
    _evaluateEditIconVisibility();
  }

  Future<void> _loadDesignatedTimes() async {
    try {
      DocumentSnapshot settingsSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('absensi_times')
          .get();

      if (settingsSnapshot.exists) {
        var data = settingsSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('designatedStartTime')) {
          Timestamp startTimestamp = data['designatedStartTime'];
          DateTime startDateTime = startTimestamp.toDate();
          setState(() {
            _designatedStartTime = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
          });
        }

        if (data.containsKey('designatedEndTime')) {
          Timestamp endTimestamp = data['designatedEndTime'];
          DateTime endDateTime = endTimestamp.toDate();
          setState(() {
            _designatedEndTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
          });
        }

        if (data.containsKey('clockInDate')) {
          Timestamp clockInTimestamp = data['clockInDate'];
          DateTime clockInDate = clockInTimestamp.toDate();
          setState(() {
            _clockInDate = clockInDate;
          });
        }
      }
    } catch (e) {
      print('Error loading designated times: $e');
      _showAlertDialog('Error loading designated times: $e');
    }
  }

  void _evaluateEditIconVisibility() {
    if (_clockInDate != null) {
      DateTime now = DateTime.now();

      if (_clockInDate!.isBefore(DateTime(now.year, now.month, now.day))) {
        setState(() {
          _showEditIcon = true;
        });
      } else if (_clockInDate!.isSameDay(now)) {
        if (_designatedStartTime != null) {
          TimeOfDay nowTime = TimeOfDay.now();
          if (nowTime.hour > _designatedStartTime!.hour ||
              (nowTime.hour == _designatedStartTime!.hour && nowTime.minute >= _designatedStartTime!.minute)) {
            setState(() {
              _showEditIcon = true;
            });
          } else {
            setState(() {
              _showEditIcon = false;
            });
          }
        }
      } else {
        setState(() {
          _showEditIcon = false;
        });
      }
    }
  }

  void _saveClockInDate() async {
    DateTime now = DateTime.now();
    FirebaseFirestore.instance.collection('settings').doc('absensi_times').set({
      'clockInDate': Timestamp.fromDate(now),
    }, SetOptions(merge: true)).catchError((error) {
      print('Error saving clock-in date: $error');
      _showAlertDialog('Error saving clock-in date: $error');
    });

    setState(() {
      _clockInDate = now;
      _evaluateEditIconVisibility();
    });
  }

  Future<void> _selectTime(BuildContext context, String key) async {
    String timeType = key == 'designatedStartTime' ? 'start' : 'end';
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: key == 'designatedStartTime'
          ? (_designatedStartTime ?? TimeOfDay.now())
          : (_designatedEndTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (key == 'designatedStartTime') {
          _designatedStartTime = picked;
        } else {
          _designatedEndTime = picked;
        }
        _saveDesignatedTime(picked, key);
        _showAlertDialog('You selected the $timeType time: ${picked.format(context)}');
      });
    }
  }

  void _saveDesignatedTime(TimeOfDay time, String key) {
    DateTime now = DateTime.now();
    DateTime designatedTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    FirebaseFirestore.instance.collection('settings').doc('absensi_times').set({
      key: Timestamp.fromDate(designatedTime),
    }, SetOptions(merge: true)).catchError((error) {
      print('Error saving designated time: $error');
      _showAlertDialog('Error saving designated time: $error');
    });
  }

  void _approveRecord(String recordId, String userId, bool isApproved) async {
    try {
      DocumentReference recordRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('clockin_records')
          .doc(recordId);

      await recordRef.update({'approved': isApproved});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isApproved ? 'Record approved successfully' : 'Record rejected successfully')),
      );
      setState(() {
        _editableRecordId = null;
      });
    } catch (e) {
      print('Error approving record: $e');
      _showAlertDialog('Error approving record: $e');
    }
  }

  // Fungsi untuk menghitung early leave duration
  Duration _calculateEarlyLeaveDuration(DateTime clockOutTime, TimeOfDay designatedEndTime) {
    DateTime designatedEndDateTime = DateTime(
        clockOutTime.year, clockOutTime.month, clockOutTime.day, designatedEndTime.hour, designatedEndTime.minute);
    if (clockOutTime.isBefore(designatedEndDateTime)) {
      return designatedEndDateTime.difference(clockOutTime);
    } else {
      return Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Absensi Approval', style: TextStyle(color: Colors.white)),
            Container(
              margin: const EdgeInsets.only(top: 4.0),
              height: 4.0,
              width: 100.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        elevation: 4.0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_showEditIcon)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.white),
              onPressed: () {
                // Tindakan yang dilakukan saat tombol edit ditekan
              },
            ),
          IconButton(
            icon: FaIcon(color: Colors.white, FontAwesomeIcons.cog),
            onPressed: () {
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
                      title: Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
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
                        color: Colors.teal.shade700,
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
                  return Center(child: Text('No records found for the selected date.', style: TextStyle(color: Colors.teal.shade900)));
                }

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    var record = records[index];
                    var data = record.data() as Map<String, dynamic>;
                    var userName = data['user_name'] ?? 'Unknown';
                    var clockInTime = data['clock_in_time'] != null
                        ? (data['clock_in_time'] as Timestamp).toDate()
                        : null;
                    var clockOutTime = data['clock_out_time'] != null
                        ? (data['clock_out_time'] as Timestamp).toDate()
                        : null;

                    var isApproved = data['approved'] ?? false;

                    var now = TimeOfDay.now();

                    bool showEditButton = !isApproved && (now.hour > 8 || (now.hour == 8 && now.minute >= 0));

                    var workingHours = clockInTime != null && clockOutTime != null
                        ? clockOutTime.difference(clockInTime)
                        : null;
                    var logbookEntries = data['logbook_entries'] != null
                        ? List<Map<String, dynamic>>.from(data['logbook_entries'])
                        : <Map<String, dynamic>>[];
                    var clockInImageUrl = data['image_url'] ?? '';
                    var clockOutImageUrl = data['clock_out_image_url'] ?? '';

                    // Durasi Early Leave
                    var earlyLeaveDuration = clockOutTime != null && _designatedEndTime != null
                        ? _calculateEarlyLeaveDuration(clockOutTime, _designatedEndTime!)
                        : null;

                    var lateDuration = clockInTime != null && _designatedStartTime != null
                        ? _calculateLateDuration(clockInTime, _designatedStartTime!)
                        : null;
                    var lateReason = data['late_reason'] ?? 'N/A';
                    var userId = record.reference.parent.parent!.id;
                    var recordId = record.id;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      elevation: 3.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Container(
                        decoration: BoxDecoration(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Clock In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),
                              _buildTable('Time In', userName, clockInTime, clockInImageUrl, null, lateReason, null),
                              if (lateDuration != null)
                                _buildDurationTable('Late Duration', _formattedDuration(lateDuration)),
                              SizedBox(height: 10),
                              Center(
                                child: Text(
                                  'Clock Out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.teal.shade900,
                                  ),
                                ),
                              ),
                              SizedBox(height: 5),

                              // Early leave duration di atas gambar clock out
                              _buildTable('Time Out', null, clockOutTime, clockOutImageUrl, null),
                              if (earlyLeaveDuration != null && earlyLeaveDuration > Duration.zero)
                                _buildDurationTable('Early Leave Duration', _formattedDuration(earlyLeaveDuration)),
                              if (workingHours != null)
                                _buildDurationTable('Working Hours', _formattedDuration(workingHours)),
                              SizedBox(height: 20),
                              _buildApprovalTable(isApproved),
                              if (showEditButton)
                                _buildEditButton(recordId),
                              if (_editableRecordId == recordId)
                                _buildApprovalButtons(context, recordId, userId, isApproved),

                              if (logbookEntries.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Logbook Entries:',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                                    Table(
                                      border: TableBorder.all(color: Colors.teal.shade700),
                                      columnWidths: const {
                                        0: FixedColumnWidth(10),
                                        1: FlexColumnWidth(),
                                      },
                                      children: logbookEntries.map((entry) {
                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(entry['time_range'] ?? 'N/A', style: TextStyle(color: Colors.teal.shade900)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: Text(entry['activity'] ?? 'N/A', style: TextStyle(color: Colors.teal.shade900)),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                            ],
                          ),
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
    );
  }

  Table _buildTable(String timeType, String? userName, DateTime? time, String? imageUrl, GeoPoint? location, [String? lateReason, bool? isApproved]) {
    return Table(
      border: TableBorder.all(color: Colors.teal.shade700),
      columnWidths: const {
        0: FixedColumnWidth(200),
        1: FlexColumnWidth(1000),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        if (userName != null) _buildTableRow('User Name:', userName),
        _buildTableRow('$timeType:', time != null ? _formattedDateTime(time) : 'N/A'),
        if (imageUrl != null && imageUrl.isNotEmpty)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(50.0),
                child: Text(
                  'Image:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: GestureDetector(
                  onTap: () => _showFullImage(context, imageUrl),
                  child: Container(
                    width: 50,
                    height: 150,// Sesuaikan lebar gambar
                    child: AspectRatio(
                      aspectRatio: 2 / 3, // Rasio 2x3
                      child: Image.network(
                        imageUrl,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, color: Colors.red);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Image:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('No Image', style: TextStyle(color: Colors.teal.shade900)),
              ),
            ],
          ),
        if (lateReason != null && timeType == 'Time In')
          _buildTableRow('Late Reason:', lateReason),
      ],
    );
  }

  Table _buildDurationTable(String title, String content) {
    return Table(
      border: TableBorder.all(color: Colors.teal.shade700),
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

  Table _buildApprovalTable(bool isApproved) {
    return Table(
      border: TableBorder.all(color: Colors.teal.shade700),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow('Approved:', isApproved ? 'Approved' : 'Pending', isBold: true, isApproved: isApproved),
      ],
    );
  }

  TableRow _buildTableRow(String title, String content, {bool isLateDuration = false, bool isBold = false, bool? isApproved}) {
    return TableRow(
      children: [
        Container(
          padding: EdgeInsets.all(8.0),
          child: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
          ),
        ),
        Container(
          padding: EdgeInsets.all(8.0),
          child: Text(
            content,
            style: TextStyle(
              color: isLateDuration ? Colors.red : (isApproved == false ? Colors.red : (isApproved == true ? Colors.green : Colors.teal.shade900)),
              fontWeight: isBold ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
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
            color: Colors.teal.shade50,
          ),
        ],
      ),
    );
  }

  // Update this method to format date and time with leading zeros
  String _formattedDateTime(DateTime dateTime) {
    return DateFormat('dd-MM-yyyy HH:mm').format(dateTime); // Adding leading zeros with intl package
  }

  // Update this method to format date with leading zeros
  String _formattedDate(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date); // Adding leading zeros with intl package
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Set Start Time', style: TextStyle(color: Colors.teal.shade900)),
                  trailing: Icon(Icons.access_time, color: Colors.teal.shade700),
                  onTap: () {
                    _selectTime(context, 'designatedStartTime');
                  },
                ),
                ListTile(
                  title: Text('Set End Time', style: TextStyle(color: Colors.teal.shade900)),
                  trailing: Icon(Icons.access_time, color: Colors.teal.shade700),
                  onTap: () {
                    _selectTime(context, 'designatedEndTime');
                  },
                ),
                if (_designatedStartTime != null || _designatedEndTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 100.0,
                            child: Card(
                              color: Colors.teal.shade50,
                              elevation: 2.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start Time',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                                    ),
                                    SizedBox(height: 4.0),
                                    Text(
                                      _designatedStartTime != null ? _designatedStartTime!.format(context) : 'N/A',
                                      style: TextStyle(color: Colors.teal.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: SizedBox(
                            height: 100.0,
                            child: Card(
                              color: Colors.teal.shade50,
                              elevation: 2.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'End Time',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                                    ),
                                    SizedBox(height: 4.0),
                                    Text(
                                      _designatedEndTime != null ? _designatedEndTime!.format(context) : 'N/A',
                                      style: TextStyle(color: Colors.teal.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.red);
                },
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
          title: Text("Peringatan", style: TextStyle(color: Colors.teal.shade900)),
          content: Text(message, style: TextStyle(color: Colors.teal.shade900)),
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

  Widget _buildApprovalButtons(BuildContext context, String recordId, String userId, bool approvalStatus) {
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
                    _approveRecord(recordId, userId, true);
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
                    _approveRecord(recordId, userId, false);
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
            icon: Icon(Icons.edit, color: Colors.teal.shade900),
            onPressed: () {
              setState(() {
                _editableRecordId = recordId;
              });
            },
          ),
          Text('Edit', style: TextStyle(color: Colors.teal.shade900, fontSize: 12)),
        ],
      ),
    );
  }
}

extension DateTimeExtensions on DateTime {
  bool isSameDay(DateTime other) {
    return this.year == other.year &&
        this.month == other.month &&
        this.day == other.day;
  }
}
