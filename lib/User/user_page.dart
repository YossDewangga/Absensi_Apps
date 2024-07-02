import 'package:absensi_apps/Break/start_&_end_break.dart';
import 'package:absensi_apps/Cuti/leave_page.dart';
import 'package:absensi_apps/Visit%20In%20&%20Out/visit.dart';
import 'package:absensi_apps/Overtime/overtime.dart'; // Import Overtime Page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../Clock In & Clock Out/clock_in_out.dart';
import 'profile_page.dart';

class UserPage extends StatefulWidget {
  UserPage({Key? key}) : super(key: key);

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  void _navigateToClockPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClockPage()),
    );
  }

  void _navigateToOvertimePage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OvertimePage()),
    );
  }

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {};

  void _addEvent(String event) {
    final selectedDate = _selectedDay ?? _focusedDay;
    if (_events[selectedDate] != null) {
      _events[selectedDate]!.add(event);
    } else {
      _events[selectedDate] = [event];
    }
    setState(() {});
  }

  void _removeEvent(String event) {
    final selectedDate = _selectedDay ?? _focusedDay;
    _events[selectedDate]?.remove(event);
    if (_events[selectedDate]?.isEmpty ?? false) {
      _events.remove(selectedDate);
    }
    setState(() {});
  }

  List<String> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, MMMM d, y').format(date);
  }

  Future<void> _displayAddEventDialog(BuildContext context) async {
    final TextEditingController _textFieldController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Event'),
          content: TextField(
            controller: _textFieldController,
            decoration: InputDecoration(hintText: "Event"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('ADD'),
              onPressed: () {
                if (_textFieldController.text.isNotEmpty) {
                  _addEvent(_textFieldController.text);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final user = FirebaseAuth.instance.currentUser;

    String greeting = '';
    if (now.hour < 12) {
      greeting = 'Good Morning,';
    } else if (now.hour < 17) {
      greeting = 'Good Afternoon,';
    } else {
      greeting = 'Good Evening,';
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
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
                padding: EdgeInsets.only(top: 40, left: 15, right: 15, bottom: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        wordSpacing: 2,
                        color: Colors.black,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.normal,
                            letterSpacing: 1,
                            wordSpacing: 2,
                            color: Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.person, size: 30, color: Colors.black),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ProfilePage()),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _navigateToClockPage(context);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 30,
                                color: Colors.black,
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Absensi',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _navigateToOvertimePage(context);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book,
                                size: 30,
                                color: Colors.black,
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Overtime',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => BreakStartEndPage()),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.free_breakfast,
                                size: 30,
                                color: Colors.black,
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Break',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => VisitInAndOutPage()),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.work,
                                size: 30,
                                color: Colors.black,
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Visit',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => LeaveApplicationPage()),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.airplane_ticket,
                                size: 30,
                                color: Colors.black,
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Cuti',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 330,
                      ),
                      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TableCalendar(
                            rowHeight: 30, // Adjusted row height
                            daysOfWeekHeight: 20, // Adjusted days of the week height
                            firstDay: DateTime.utc(2020, 10, 16),
                            lastDay: DateTime.utc(2030, 3, 14),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) {
                              return isSameDay(_selectedDay, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              if (_calendarFormat != format) {
                                setState(() {
                                  _calendarFormat = format;
                                });
                              }
                            },
                            onPageChanged: (focusedDay) {
                              _focusedDay = focusedDay;
                            },
                            eventLoader: _getEventsForDay,
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                color: Colors.black,
                                fontSize: 14, // Adjusted header text size
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Divider(
                            color: Colors.grey,
                            thickness: 1,
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDay != null
                                    ? _formatDate(_selectedDay!)
                                    : _formatDate(_focusedDay),
                                style: TextStyle(
                                  fontSize: 13, // Adjusted text size
                                  fontWeight: FontWeight.normal,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          Divider(
                            color: Colors.grey,
                            thickness: 1,
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                'Event Log',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 13, // Adjusted text size
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 0.0),
                          Container(
                            height: 150,  // Adjust the height as necessary
                            child: _getEventsForDay(_selectedDay ?? _focusedDay).isEmpty
                                ? Center(child: Text('No Event', style: TextStyle(color: Colors.grey, fontSize: 12))) // Adjusted text size
                                : ListView.builder(
                              itemCount: _getEventsForDay(_selectedDay ?? _focusedDay).length,
                              itemBuilder: (context, index) {
                                String event = _getEventsForDay(_selectedDay ?? _focusedDay)[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,  // Remove internal padding
                                  title: Text(event, style: TextStyle(fontSize: 12)), // Adjusted text size
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, size: 20), // Adjusted icon size
                                    onPressed: () {
                                      _removeEvent(event);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => _displayAddEventDialog(context),
                                child: Text(
                                  '+ Add Event',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
