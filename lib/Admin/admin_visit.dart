import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({Key? key}) : super(key: key);

  @override
  _AdminApprovalPageState createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isCalendarExpanded = false;
  String? _editableVisitId;

  @override
  void initState() {
    super.initState();
  }

  Future<String> _getUserDisplayName(String userId) async {
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var data = userSnapshot.data() as Map<String, dynamic>?;
    return data?['displayName'] ?? 'Unknown';
  }

  Future<void> _openMap(double latitude, double longitude) async {
    String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not open the map.';
    }
  }

  Future<void> _openLocation(String location) async {
    var parts = location.split(',');
    if (parts.length == 2) {
      var latitude = double.tryParse(parts[0]);
      var longitude = double.tryParse(parts[1]);
      if (latitude != null && longitude != null) {
        await _openMap(latitude, longitude);
      } else {
        throw 'Invalid coordinates.';
      }
    } else {
      throw 'Invalid location format.';
    }
  }

  void _updateApprovalStatus(BuildContext context, String visitId, String userId, bool isApproved) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('visits')
        .doc(visitId)
        .update({
      'approved': isApproved,
    }).then((_) {
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Visit Approval', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.teal.shade700,
          elevation: 4,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.teal.shade50],
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
                    stream: FirebaseFirestore.instance.collectionGroup('visits').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
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
                        return Center(
                          child: Text('No visits found for the selected date.', style: TextStyle(color: Colors.teal.shade900)),
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
                          var visitInLocation = data['visit_in_location'];
                          var visitInAddress = data['visit_in_address'] ?? 'Unknown';
                          var visitInImageUrl = data['visit_in_imageUrl'] ?? '';
                          var destinationCompany = data['destination_company'] ?? 'N/A';

                          var visitOutTimestamp = data['visit_out_time'] != null
                              ? (data['visit_out_time'] as Timestamp).toDate()
                              : null;
                          var visitOutLocation = data['visit_out_location'];
                          var visitOutAddress = data['visit_out_address'] ?? 'Unknown';
                          var visitOutImageUrl = data['visit_out_imageUrl'] ?? '';
                          var nextDestination = data['next_destination'] ?? 'N/A';

                          var approvalStatus = data['approved'] as bool? ?? false;

                          return FutureBuilder<String>(
                            future: _getUserDisplayName(userId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }

                              var displayName = snapshot.data ?? 'Unknown';

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
                                      _buildUserTable('Nama User', displayName),
                                      Divider(thickness: 1, color: Colors.teal.shade700),
                                      Text('Visit In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900)),
                                      _buildVisitLog(
                                        context,
                                        'Visit In',
                                        visitInTimestamp,
                                        visitInLocation,
                                        visitInAddress,
                                        visitInImageUrl,
                                        null,
                                        destinationCompany,  // Tampilkan destination_company di Visit In
                                      ),
                                      Divider(thickness: 1, color: Colors.teal.shade700),
                                      Text('Visit Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade900)),
                                      _buildVisitLog(
                                        context,
                                        'Visit Out',
                                        visitOutTimestamp,
                                        visitOutLocation,
                                        visitOutAddress,
                                        visitOutImageUrl,
                                        nextDestination,
                                      ),
                                      Divider(thickness: 1, color: Colors.teal.shade700),
                                      _buildApprovalRow(approvalStatus),
                                      if (_editableVisitId == visitId)
                                        _buildApprovalButtons(context, visitId, userId, approvalStatus)
                                      else if (visitOutTimestamp != null && !approvalStatus)
                                        _buildEditButton(visitId),
                                    ],
                                  ),
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
          ],
        ),
      ),
    );
  }

  Table _buildVisitLog(BuildContext context, String visitType, DateTime? timestamp, dynamic location, String address, String imageUrl, [String? nextDestination, String? destinationCompany]) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        if (visitType == 'Visit In' && destinationCompany != null) // Menampilkan destination_company di atas visit_in_time
          _buildTableRow('Destination :', destinationCompany),
        _buildTableRow('$visitType Time:', timestamp != null ? _formattedDateTime(timestamp) : 'N/A'),
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Location:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: location is GeoPoint
                  ? IconButton(
                icon: Icon(Icons.location_on, color: Colors.blue),
                onPressed: () {
                  _openMap(location.latitude, location.longitude);
                },
              )
                  : location is String && location.contains(',')
                  ? IconButton(
                icon: Icon(Icons.location_on, color: Colors.blue),
                onPressed: () {
                  _openLocation(location);
                },
              )
                  : Text(location?.toString() ?? 'N/A', style: TextStyle(color: Colors.teal.shade700)),
            ),
          ],
        ),
        _buildTableRow('Address:', address),
        if (visitType == 'Visit Out' && nextDestination != null)
          _buildTableRow('Next Destination:', nextDestination),
        if (imageUrl.isNotEmpty)
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

  Table _buildUserTable(String title, String userName) {
    return Table(
      border: TableBorder.all(color: Colors.teal.shade700),
      columnWidths: const {
        0: FixedColumnWidth(150),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _buildTableRow(title, userName),
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
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Text(content, style: TextStyle(color: Colors.teal.shade700)),
        ),
      ],
    );
  }

  Widget _buildApprovalRow(bool approvalStatus) {
    Color textColor = approvalStatus ? Colors.green : Colors.red;
    String text = approvalStatus ? 'Approved' : 'Pending';
    return Row(
      children: [
        Text(
          'Approval Status: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade900,
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

  Widget _buildApprovalButtons(BuildContext context, String visitId, String userId, bool approvalStatus) {
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
            icon: Icon(Icons.edit, color: Colors.teal.shade900),
            onPressed: () {
              setState(() {
                _editableVisitId = visitId;
              });
            },
          ),
          Text('Edit', style: TextStyle(color: Colors.teal.shade900, fontSize: 12)),
        ],
      ),
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

  String _formattedDateTime(DateTime dateTime) {
    return "${dateTime.day}-${dateTime.month}-${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
  }
}
