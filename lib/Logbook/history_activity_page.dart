import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class HistoryLogbookPage extends StatefulWidget {
  const HistoryLogbookPage({Key? key}) : super(key: key);

  @override
  _HistoryLogbookPageState createState() => _HistoryLogbookPageState();
}

class _HistoryLogbookPageState extends State<HistoryLogbookPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Logbook'),
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
                    return const ListTile(
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
                    calendarStyle: const CalendarStyle(
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
            child: FutureBuilder<User?>(
              future: FirebaseAuth.instance.authStateChanges().first,
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError) {
                  return Center(child: Text('Error: ${userSnapshot.error}'));
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  return const Center(child: Text('Tidak ada pengguna yang login'));
                }

                final User user = userSnapshot.data!;
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('daily_logbook')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Belum ada entri logbook untuk tanggal ini.'));
                    }

                    var records = snapshot.data!.docs;

                    records = records.where((record) {
                      var data = record.data() as Map<String, dynamic>;
                      var entryDate = (data['last_updated'] as Timestamp).toDate();
                      return entryDate.year == _selectedDate.year &&
                          entryDate.month == _selectedDate.month &&
                          entryDate.day == _selectedDate.day;
                    }).toList();

                    if (records.isEmpty) {
                      return const Center(child: Text('Tidak ada catatan untuk tanggal yang dipilih.', style: TextStyle(color: Colors.black)));
                    }

                    return ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        var record = records[index];
                        var data = record.data() as Map<String, dynamic>;
                        var logbookEntries = data['logbook_entries'] as List<dynamic>;

                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.all(8.0),
                          child: Table(
                            border: TableBorder.all(color: Colors.grey.shade300),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                ),
                                children: [
                                  _buildTableCell("Mulai", isHeader: true),
                                  _buildTableCell("Selesai", isHeader: true),
                                  _buildTableCell("Aktivitas", isHeader: true),
                                ],
                              ),
                              ...logbookEntries.map<TableRow>((entry) {
                                return TableRow(
                                  children: [
                                    _buildTableCell(
                                      _formattedDateTime((entry['start_time'] as Timestamp).toDate()),
                                    ),
                                    _buildTableCell(
                                      _formattedDateTime((entry['end_time'] as Timestamp).toDate()),
                                    ),
                                    _buildTableCell(entry['activity'] ?? 'No activity'),
                                  ],
                                );
                              }).toList(),
                            ],
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
        ),
      ),
    );
  }

  String _formattedDateTime(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }
}
