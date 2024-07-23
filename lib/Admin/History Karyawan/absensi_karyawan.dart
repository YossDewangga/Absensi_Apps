import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

class AbsensiPage extends StatefulWidget {
  final String userId;

  const AbsensiPage({Key? key, required this.userId}) : super(key: key);

  @override
  _AbsensiPageState createState() => _AbsensiPageState();
}

class _AbsensiPageState extends State<AbsensiPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  TimeOfDay? _designatedStartTime;
  TimeOfDay? _designatedEndTime;

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
    }
  }

  void _clockOut() async {
    try {
      var now = DateTime.now();
      var userId = widget.userId;
      var recordSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('clockin_records')
          .where('clock_in_time', isLessThanOrEqualTo: now)
          .orderBy('clock_in_time', descending: true)
          .limit(1)
          .get();

      if (recordSnapshot.docs.isNotEmpty) {
        var record = recordSnapshot.docs.first;
        var clockInTime = (record['clock_in_time'] as Timestamp).toDate();
        var workingHours = now.difference(clockInTime);

        Duration lateDuration = _calculateLateDuration(clockInTime, _designatedStartTime!);

        await record.reference.update({
          'clock_out_time': now,
          'working_hours': workingHours.inMinutes, // Store working hours in minutes
          'late_duration': lateDuration.inMinutes,
        });

        print('Clock out successful');
      }
    } catch (e) {
      print('Error during clock out: $e');
    }
  }

  String _formattedDateTime(DateTime dateTime) {
    return "${dateTime.day}-${dateTime.month}-${dateTime.year} ${dateTime.hour}:${dateTime.minute}:${dateTime.second}";
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

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Riwayat Clock In/Out'),
        ),
        body: Center(child: Text('User ID tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Clock In/Out'),
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
                      title: Text('Pilih Tanggal', style: TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                  body: TableCalendar(
                    focusedDay: _selectedDate,
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const { CalendarFormat.month: 'Month' },
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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('clockin_records')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Belum ada data clock in/out'));
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
                    var userId = record.reference.parent.parent!.id;

                    var userName = data['user_name'] ?? 'Unknown';
                    var clockInTime = data['clock_in_time'] != null
                        ? (data['clock_in_time'] as Timestamp).toDate()
                        : null;
                    var clockOutTime = data['clock_out_time'] != null
                        ? (data['clock_out_time'] as Timestamp).toDate()
                        : null;
                    var workingHours = data['total_working_hours'] != null
                        ? data['total_working_hours']
                        : 'N/A';
                    var lateDuration = data['late_duration'] != null
                        ? data['late_duration']
                        : 'N/A';
                    var logbookEntries = data['logbook_entries'] != null
                        ? List<Map<String, dynamic>>.from(data['logbook_entries'])
                        : <Map<String, dynamic>>[];
                    var imageUrl = data['image_url'] ?? '';
                    var clockOutImageUrl = data['clock_out_image_url'] ?? '';
                    var lateReason = data['late_reason'] ?? 'N/A';

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
                            _buildTable(context, 'Clock In', clockInTime, imageUrl, lateReason, lateDuration),
                            Divider(thickness: 1),
                            _buildTable(context, 'Clock Out', clockOutTime, clockOutImageUrl, null, null, logbookEntries),
                            if (workingHours != 'N/A')
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: _buildWorkingHoursRow('Total Working Hours', workingHours),
                              ),
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
    );
  }

  Widget _buildTable(BuildContext context, String title, DateTime? time, String? imageUrl, [String? lateReason, String? lateDuration, List<Map<String, dynamic>>? logbookEntries]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
          },
          children: [
            _buildTableRow('Time', time != null ? _formattedDateTime(time) : 'N/A'),
            if (title == 'Clock In' && imageUrl != null)
              _buildTableRowImage(context, 'Image', imageUrl),
            if (title == 'Clock Out' && imageUrl != null)
              _buildTableRowImage(context, 'Image', imageUrl),
            if (title == 'Clock In' && lateReason != null)
              _buildTableRow('Late Reason', lateReason),
            if (title == 'Clock In' && lateDuration != null)
              _buildTableRow('Late Duration', lateDuration, isHighlight: true),
            if (title == 'Clock Out' && logbookEntries != null)
              ..._buildLogbookEntriesTable(logbookEntries),
          ],
        ),
      ],
    );
  }

  List<TableRow> _buildLogbookEntriesTable(List<Map<String, dynamic>> logbookEntries) {
    List<TableRow> rows = [
      TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Jam',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Aktivitas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ];

    rows.addAll(logbookEntries.map((entry) {
      return TableRow(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(entry['time_range'] ?? 'N/A'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(entry['activity'] ?? 'N/A'),
            ),
          ),
        ],
      );
    }).toList());

    return rows;
  }

  TableRow _buildTableRow(String key, String value, {bool isHighlight = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            key,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            value,
            style: isHighlight
                ? TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
                : TextStyle(),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRowImage(BuildContext context, String key, String? imageUrl) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            key,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _showFullImage(context, imageUrl);
            },
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Image.network(
                  imageUrl,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    } else {
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    }
                  },
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
              : Text('No Image'),
        ),
      ],
    );
  }

  Widget _buildWorkingHoursRow(String key, String value) {
    return Row(
      children: [
        Text(
          '$key: ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
