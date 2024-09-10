import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

class ClockHistoryPage extends StatefulWidget {
  final String? userId;

  const ClockHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  _ClockHistoryPageState createState() => _ClockHistoryPageState();
}

class _ClockHistoryPageState extends State<ClockHistoryPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;

  @override
  void initState() {
    super.initState();
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

                    var clockInTime = data['clock_in_time'] != null
                        ? (data['clock_in_time'] as Timestamp).toDate()
                        : null;
                    var clockOutTime = data['clock_out_time'] != null
                        ? (data['clock_out_time'] as Timestamp).toDate()
                        : null;
                    var imageUrl = data['image_url'] ?? '';
                    var clockOutImageUrl = data['clock_out_image_url'] ?? '';
                    var approved = data['approved'] ?? false;
                    var lateDuration = data['late_duration'] ?? '-';
                    var lateReason = data['late_reason'] ?? '-';
                    var totalWorkingHours = data['working_hours'] ?? '-';

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
                            _buildTable(context, 'Clock In', clockInTime, imageUrl, lateDuration, lateReason),
                            Divider(thickness: 1),
                            _buildTable(context, 'Clock Out', clockOutTime, clockOutImageUrl, approved, totalWorkingHours),
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

  Widget _buildTable(BuildContext context, String title, DateTime? time, String? imageUrl, dynamic extraData, [String? lateReason]) {
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
            _buildTableRow('Time', time != null ? _formattedDateTime(time) : '-'),
            if (imageUrl != null && imageUrl.isNotEmpty)
              _buildTableRowImage(context, 'Image', imageUrl),
            if (title == 'Clock In') ...[
              _buildTableRow('Late Duration', extraData.toString()),
              _buildTableRow('Late Reason', lateReason ?? '-'),
            ],
            if (title == 'Clock Out') ...[
              _buildTableRow('Working Hours', lateReason ?? '-'),
              _buildTableRow('Status', extraData ? 'Approved' : 'Pending', extraData),
            ],
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String key, String value, [bool? approved]) {
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: approved != null
                  ? (approved ? Colors.green : Colors.red)
                  : null,
            ),
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
              : Text('-'),
        ),
      ],
    );
  }

  String _formattedDateTime(DateTime dateTime) {
    String day = dateTime.day.toString().padLeft(2, '0');
    String month = dateTime.month.toString().padLeft(2, '0');
    String year = dateTime.year.toString();
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String second = dateTime.second.toString().padLeft(2, '0');

    return "$day-$month-$year | $hour:$minute:$second";
  }
}
