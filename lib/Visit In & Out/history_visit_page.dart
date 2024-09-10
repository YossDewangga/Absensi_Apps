import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

class VisitHistoryPage extends StatefulWidget {
  final String? userId;

  const VisitHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  _VisitHistoryPageState createState() => _VisitHistoryPageState();
}

class _VisitHistoryPageState extends State<VisitHistoryPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Riwayat Kunjungan'),
        ),
        body: Center(child: Text('User ID tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Kunjungan'),
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
                  .collection('visits')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Belum ada data kunjungan'));
                }

                var records = snapshot.data!.docs;

                records = records.where((record) {
                  var data = record.data() as Map<String, dynamic>;
                  var visitInTime = data['visit_in_time'] != null
                      ? (data['visit_in_time'] as Timestamp).toDate()
                      : null;
                  var visitOutTime = data['visit_out_time'] != null
                      ? (data['visit_out_time'] as Timestamp).toDate()
                      : null;
                  return (visitInTime != null &&
                      visitInTime.year == _selectedDate.year &&
                      visitInTime.month == _selectedDate.month &&
                      visitInTime.day == _selectedDate.day) ||
                      (visitOutTime != null &&
                          visitOutTime.year == _selectedDate.year &&
                          visitOutTime.month == _selectedDate.month &&
                          visitOutTime.day == _selectedDate.day);
                }).toList();

                if (records.isEmpty) {
                  return const Center(child: Text('No records found for the selected date.', style: TextStyle(color: Colors.black)));
                }

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    var record = records[index];
                    var data = record.data() as Map<String, dynamic>;
                    var approvalStatus = data['approved'] as bool?;
                    var statusText = 'Pending';
                    var statusColor = Colors.red;

                    if (approvalStatus != null && approvalStatus) {
                      statusText = 'Approved';
                      statusColor = Colors.green;
                    }

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
                            if (data['visit_in_time'] != null)
                              _buildTable(
                                context,
                                'Visit In',
                                _formatTimestamp(data['visit_in_time']),
                                data['visit_in_location'] as String?,
                                data['visit_in_address'] as String?,
                                data['visit_in_imageUrl'] as String?,
                              ),
                            if (data['visit_out_time'] != null)
                              _buildTable(
                                context,
                                'Visit Out',
                                _formatTimestamp(data['visit_out_time']),
                                data['visit_out_location'] as String?,
                                data['visit_out_address'] as String?,
                                data['visit_out_imageUrl'] as String?,
                                data['next_destination'] as String?,
                                statusText,
                                statusColor,
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

  Widget _buildTable(BuildContext context, String title, String? time, String? location, String? address, String? imageUrl, [String? nextDestination, String? statusText, Color? statusColor]) {
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
            _buildTableRow('Time', time ?? 'N/A'),
            _buildLocationRow(context, 'Location', location ?? 'N/A'),
            _buildTableRow('Address', address ?? 'N/A'),
            if (title == 'Visit Out' && nextDestination != null)
              _buildTableRow('Next Destination', nextDestination),
            _buildTableRowImage(context, 'Image', imageUrl),
            if (title == 'Visit Out' && statusText != null && statusColor != null)
              _buildTableRow('Status', statusText, statusColor: statusColor),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String key, String value, {Color? statusColor}) {
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
              color: statusColor ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildLocationRow(BuildContext context, String key, String location) {
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
          child: GestureDetector(
            onTap: () {
              _openLocationInMaps(location);
            },
            child: Icon(Icons.location_on, color: Colors.blue),
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

  void _openLocationInMaps(String location) async {
    var coordinates = location.split(',').map((coord) => coord.trim()).toList();
    var latitude = coordinates[0];
    var longitude = coordinates[1];
    var googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not open the map.';
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null || timestamp is! Timestamp) return 'N/A';
    var dateTime = (timestamp as Timestamp).toDate();

    String day = dateTime.day.toString().padLeft(2, '0');
    String month = dateTime.month.toString().padLeft(2, '0');
    String year = dateTime.year.toString();
    String hour = dateTime.hour.toString().padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String second = dateTime.second.toString().padLeft(2, '0');

    return "$day-$month-$year $hour:$minute:$second";
  }
}
