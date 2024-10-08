import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminBreakPage extends StatefulWidget {
  const AdminBreakPage({Key? key}) : super(key: key);

  @override
  _AdminBreakPageState createState() => _AdminBreakPageState();
}

class _AdminBreakPageState extends State<AdminBreakPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  DateTime? _adminStartBreakTime;
  DateTime? _adminEndBreakTime;

  @override
  void initState() {
    super.initState();
    _loadAdminBreakTimes();
  }

  Future<void> _loadAdminBreakTimes() async {
    DocumentSnapshot settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('break_times').get();
    if (settingsDoc.exists) {
      setState(() {
        _adminStartBreakTime = (settingsDoc['adminStartBreakTime'] as Timestamp).toDate();
        _adminEndBreakTime = (settingsDoc['adminEndBreakTime'] as Timestamp).toDate();
      });
    }
  }

  Future<void> _saveAdminBreakTimesToFirestore() async {
    await FirebaseFirestore.instance.collection('settings').doc('break_times').set({
      'adminStartBreakTime': _adminStartBreakTime,
      'adminEndBreakTime': _adminEndBreakTime,
    });
    _loadAdminBreakTimes();
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final TimeOfDay? timeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _adminStartBreakTime ?? DateTime.now() : _adminEndBreakTime ?? DateTime.now()),
    );

    if (timeOfDay != null) {
      setState(() {
        final now = DateTime.now();
        if (isStart) {
          _adminStartBreakTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
        } else {
          _adminEndBreakTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
        }
        _saveAdminBreakTimesToFirestore();
      });
    }
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
                  color: Colors.teal.shade700,
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
                      Text('Break History', style: TextStyle(color: Colors.white)),
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
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      icon: FaIcon(FontAwesomeIcons.cog, color: Colors.white),
                      onPressed: () {
                        _showSettingsDialog(context);
                      },
                    ),
                  ],
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
                  stream: FirebaseFirestore.instance.collectionGroup('break_logs').snapshots(),
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

                    var breakLogs = snapshot.data!.docs;

                    breakLogs = breakLogs.where((log) {
                      var data = log.data() as Map<String, dynamic>;
                      var startBreak = data['start_break'] != null
                          ? (data['start_break'] as Timestamp).toDate()
                          : null;
                      return startBreak != null &&
                          startBreak.year == _selectedDate.year &&
                          startBreak.month == _selectedDate.month &&
                          startBreak.day == _selectedDate.day;
                    }).toList();

                    if (breakLogs.isEmpty) {
                      return Center(child: Text('No break logs found for the selected date.', style: TextStyle(color: Colors.teal.shade900)));
                    }

                    return ListView.builder(
                      itemCount: breakLogs.length,
                      itemBuilder: (context, index) {
                        var log = breakLogs[index];
                        var data = log.data() as Map<String, dynamic>;
                        var userName = data['user_name'] ?? 'Unknown';
                        var displayName = data['display_name'] ?? 'Unknown';
                        var startBreak = data['start_break'] != null
                            ? (data['start_break'] as Timestamp).toDate()
                            : null;
                        var endBreak = data['end_break'] != null
                            ? (data['end_break'] as Timestamp).toDate()
                            : null;
                        var breakDuration = data['break_duration'] ?? 'Unknown duration';

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
                                _buildTable('Break Log', userName, displayName, startBreak, endBreak, breakDuration),
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

  Table _buildTable(String title, String userName, String displayName, DateTime? startBreak, DateTime? endBreak, String breakDuration) {
    return Table(
      border: TableBorder.all(color: Colors.teal.shade700),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow('User Name:', displayName),
        _buildTableRow('Start Break:', startBreak != null ? _formattedDateTime(startBreak) : 'N/A'),
        _buildTableRow('End Break:', endBreak != null ? _formattedDateTime(endBreak) : 'N/A'),
        _buildTableRow('Break Duration:', breakDuration),
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
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
          ),
        ),
        Container(
          padding: EdgeInsets.all(8.0),
          child: Text(content, style: TextStyle(color: Colors.teal.shade900)),
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

  String _formattedDateTime(DateTime dateTime) {
    return "${dateTime.day}-${dateTime.month}-${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
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
                  title: Text('Set Start Break Time', style: TextStyle(color: Colors.teal.shade900)),
                  trailing: Icon(Icons.access_time, color: Colors.teal.shade700),
                  onTap: () {
                    _pickTime(context, true);
                  },
                ),
                ListTile(
                  title: Text('Set End Break Time', style: TextStyle(color: Colors.teal.shade900)),
                  trailing: Icon(Icons.access_time, color: Colors.teal.shade700),
                  onTap: () {
                    _pickTime(context, false);
                  },
                ),
                if (_adminStartBreakTime != null || _adminEndBreakTime != null)
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
                                      'Start Break Time',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                                    ),
                                    SizedBox(height: 4.0),
                                    Text(
                                      _adminStartBreakTime != null ? _formattedDateTime(_adminStartBreakTime!) : 'N/A',
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
                                      'End Break Time',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                                    ),
                                    SizedBox(height: 4.0),
                                    Text(
                                      _adminEndBreakTime != null ? _formattedDateTime(_adminEndBreakTime!) : 'N/A',
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
}
