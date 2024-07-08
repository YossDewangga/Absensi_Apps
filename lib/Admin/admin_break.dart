import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminStartBreakTime = DateTime.tryParse(prefs.getString('adminStartBreakTime') ?? '');
      _adminEndBreakTime = DateTime.tryParse(prefs.getString('adminEndBreakTime') ?? '');
    });
  }

  Future<void> _saveAdminBreakTimes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adminStartBreakTime', _adminStartBreakTime?.toIso8601String() ?? '');
    await prefs.setString('adminEndBreakTime', _adminEndBreakTime?.toIso8601String() ?? '');
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
        _saveAdminBreakTimes();
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
              AppBar(
                title: Column(
                  children: [
                    const Text('Break History', style: TextStyle(color: Colors.black)),
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
                      return const Center(child: Text('No break logs found for the selected date.', style: TextStyle(color: Colors.black)));
                    }

                    return ListView.builder(
                      itemCount: breakLogs.length,
                      itemBuilder: (context, index) {
                        var log = breakLogs[index];
                        var data = log.data() as Map<String, dynamic>;
                        var userName = data['user_name'] ?? 'Unknown';
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
                                _buildTable('Break Log', userName, startBreak, endBreak, breakDuration),
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

  Table _buildTable(String title, String userName, DateTime? startBreak, DateTime? endBreak, String breakDuration) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow('User Name:', userName),
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
                  title: Text('Set Start Break Time'),
                  trailing: Icon(Icons.access_time),
                  onTap: () {
                    _pickTime(context, true);
                  },
                ),
                ListTile(
                  title: Text('Set End Break Time'),
                  trailing: Icon(Icons.access_time),
                  onTap: () {
                    _pickTime(context, false);
                  },
                ),
                if (_adminStartBreakTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Start Break Time: ${_formattedDateTime(_adminStartBreakTime!)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (_adminEndBreakTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'End Break Time: ${_formattedDateTime(_adminEndBreakTime!)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
