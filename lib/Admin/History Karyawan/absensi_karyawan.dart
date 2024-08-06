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
  String _nextDestination = 'Pulang'; // Set default value to 'Pulang'

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

      if (startSnapshot.exists && startSnapshot.data() != null) {
        Timestamp? timestamp = startSnapshot['time'];
        if (timestamp != null) {
          DateTime dateTime = timestamp.toDate();
          setState(() {
            _designatedStartTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
          });
        }
      }

      if (endSnapshot.exists && endSnapshot.data() != null) {
        Timestamp? timestamp = endSnapshot['time'];
        if (timestamp != null) {
          timestamp.toDate();
          setState(() {
          });
        }
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
        if (record.data().containsKey('clock_in_time') && record['clock_in_time'] != null) {
          var clockInTime = (record['clock_in_time'] as Timestamp).toDate();
          var workingHours = now.difference(clockInTime);

          Duration lateDuration = _calculateLateDuration(clockInTime, _designatedStartTime);

          await record.reference.update({
            'clock_out_time': now,
            'working_hours': workingHours.inMinutes, // Store working hours in minutes
            'late_duration': lateDuration.inMinutes,
            'next_destination': _nextDestination.isNotEmpty ? _nextDestination : 'Pulang', // Ensure next_destination is not empty
          });

          print('Clock out successful');
        }
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

  Duration _calculateLateDuration(DateTime clockInTime, TimeOfDay? designatedStartTime) {
    if (designatedStartTime == null) {
      return Duration.zero;
    }

    DateTime designatedStartDateTime = DateTime(
      clockInTime.year,
      clockInTime.month,
      clockInTime.day,
      designatedStartTime.hour,
      designatedStartTime.minute,
    );

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

  Future<void> _showNextDestinationDialog() async {
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Tujuan Selanjutnya'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Pulang'),
                value: 'Pulang',
                groupValue: _nextDestination,
                onChanged: (value) {
                  setState(() {
                    _nextDestination = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: Text('Lainnya'),
                value: 'Lainnya',
                groupValue: _nextDestination,
                onChanged: (value) {
                  setState(() {
                    _nextDestination = value!;
                  });
                },
              ),
              if (_nextDestination == 'Lainnya')
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _nextDestination = value;
                    });
                  },
                  decoration: InputDecoration(hintText: "Masukkan tujuan selanjutnya"),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_nextDestination.isEmpty) {
                  _nextDestination = 'Pulang';
                }
                Navigator.of(context).pop();
              },
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ID Pengguna: $userId',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                Text(
                                  'ID Record: $recordId',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Nama: $userName',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Clock In: ${clockInTime != null ? _formattedDateTime(clockInTime) : 'N/A'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Clock Out: ${clockOutTime != null ? _formattedDateTime(clockOutTime) : 'N/A'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Total Jam Kerja: $workingHours',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Durasi Keterlambatan: $lateDuration',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Alasan Keterlambatan: $lateReason',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Logbook Entries:',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            const SizedBox(height: 8.0),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: logbookEntries.length,
                              itemBuilder: (context, index) {
                                var entry = logbookEntries[index];
                                var timestamp = entry['timestamp'] != null
                                    ? (entry['timestamp'] as Timestamp).toDate()
                                    : null;
                                var content = entry['content'] ?? '';

                                return ListTile(
                                  title: Text('Timestamp: ${timestamp != null ? _formattedDateTime(timestamp) : 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                  subtitle: Text('Content: $content', style: const TextStyle(color: Colors.black)),
                                );
                              },
                            ),
                            const SizedBox(height: 8.0),
                            if (imageUrl.isNotEmpty) ...[
                              const Text(
                                'Clock In Image:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _showFullImage(context, imageUrl),
                                child: Image.network(
                                  imageUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8.0),
                            if (clockOutImageUrl.isNotEmpty) ...[
                              const Text(
                                'Clock Out Image:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () => _showFullImage(context, clockOutImageUrl),
                                child: Image.network(
                                  clockOutImageUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
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
}
