import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminVisitPage extends StatefulWidget {
  const AdminVisitPage({Key? key}) : super(key: key);

  @override
  _AdminVisitPageState createState() => _AdminVisitPageState();
}

class _AdminVisitPageState extends State<AdminVisitPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  String? _editableVisitId;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visit Approval', style: TextStyle(color: Colors.black)),
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
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white],
                ),
              ),
            ),
            Column(
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collectionGroup('visits').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var visits = snapshot.data!.docs;

                      visits = visits.where((visit) {
                        var data = visit.data() as Map<String, dynamic>?;
                        if (data == null || data['visit_in_time'] == null) {
                          return false;
                        }
                        var visitTime = data['visit_in_time'] != null
                            ? (data['visit_in_time'] as Timestamp).toDate()
                            : null;
                        return visitTime != null &&
                            visitTime.year == _selectedDate.year &&
                            visitTime.month == _selectedDate.month &&
                            visitTime.day == _selectedDate.day;
                      }).toList();

                      if (visits.isEmpty) {
                        return const Center(
                          child: Text('No visits found for the selected date.', style: TextStyle(color: Colors.black)),
                        );
                      }

                      return ListView.builder(
                        itemCount: visits.length,
                        itemBuilder: (context, index) {
                          var visit = visits[index];
                          var data = visit.data() as Map<String, dynamic>;
                          var visitId = visit.id;
                          var userId = visit.reference.parent.parent!.id;

                          var visitInTimestamp = data['visit_in_time'] != null
                              ? (data['visit_in_time'] as Timestamp).toDate()
                              : null;
                          var visitInLocation = data['visit_in_location'] ?? 'Unknown';
                          var visitInAddress = data['visit_in_address'] ?? 'Unknown';
                          var visitInImageUrl = data['visit_in_imageUrl'] ?? '';

                          var visitOutTimestamp = data['visit_out_time'] != null
                              ? (data['visit_out_time'] as Timestamp).toDate()
                              : null;
                          var visitOutLocation = data['visit_out_location'] ?? 'Unknown';
                          var visitOutAddress = data['visit_out_address'] ?? 'Unknown';
                          var visitOutImageUrl = data['visit_out_imageUrl'] ?? '';
                          var nextDestination = data['next_destination'] ?? 'N/A';

                          var approvalStatus = data['visit_out_isApproved'] as bool? ?? null;

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
                                  Text('Visit In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  _buildVisitLog(
                                    context,
                                    'Visit In',
                                    visitInTimestamp,
                                    visitInLocation,
                                    visitInAddress,
                                    visitInImageUrl,
                                  ),
                                  const Divider(thickness: 1),
                                  Text('Visit Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  _buildVisitLog(
                                    context,
                                    'Visit Out',
                                    visitOutTimestamp,
                                    visitOutLocation,
                                    visitOutAddress,
                                    visitOutImageUrl,
                                    nextDestination,
                                  ),
                                  const Divider(thickness: 1),
                                  _buildApprovalRow(approvalStatus),
                                  if (_editableVisitId == visitId)
                                    _buildApprovalButtons(context, visitId, userId, approvalStatus)
                                  else
                                    _buildEditButton(visitId),
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
      ),
    );
  }

  Table _buildVisitLog(BuildContext context, String visitType, DateTime? timestamp, String location, String address, String imageUrl, [String? nextDestination]) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow('$visitType Time:', timestamp != null ? _formattedDateTime(timestamp) : 'N/A'),
        _buildTableRow('Location:', location),
        _buildTableRow('Address:', address),
        if (visitType == 'Visit Out' && nextDestination != null)
          _buildTableRow('Next Destination:', nextDestination),
        if (imageUrl.isNotEmpty)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Text(
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

  TableRow _buildTableRow(String title, String content) {
    return TableRow(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(content),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(bool? approvalStatus) {
    Color textColor = approvalStatus == true ? Colors.green : approvalStatus == false ? Colors.red : Colors.black;
    String text = approvalStatus == true ? 'Approved' : approvalStatus == false ? 'Rejected' : 'Pending';
    return Row(
      children: [
        Text(
          'Approval Status: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalButtons(BuildContext context, String visitId, String userId, bool? approvalStatus) {
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
                    _updateApprovalStatus(context, visitId, userId, true);
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
                    _updateApprovalStatus(context, visitId, userId, false);
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

  Widget _buildEditButton(String visitId) {
    return Center(
      child: Column(
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              setState(() {
                _editableVisitId = visitId;
              });
            },
          ),
          Text('Edit', style: TextStyle(color: Colors.black, fontSize: 12)),
        ],
      ),
    );
  }

  void _updateApprovalStatus(BuildContext context, String visitId, String userId, bool isApproved) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('visits')
        .doc(visitId)
        .update({'visit_out_isApproved': isApproved}).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isApproved ? 'Visit Approved' : 'Visit Rejected')),
      );
      setState(() {
        _editableVisitId = null;
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $error')),
      );
    });
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Settings'),
                  trailing: const Icon(Icons.settings),
                  onTap: () {
                    Navigator.pop(context);
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
          insetPadding: const EdgeInsets.all(0),
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
          title: const Text("Peringatan"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _formattedDateTime(DateTime dateTime) {
    return "${dateTime.day}-${dateTime.month}-${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
  }
}
