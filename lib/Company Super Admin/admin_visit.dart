import 'package:firebase_auth/firebase_auth.dart';
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
  DateTime _selectedDate = DateTime.now(); // Mulai dengan tanggal saat ini (18 Juni 2025, 12:22 PM WIB)
  bool _isCalendarExpanded = false;
  String? _editableVisitId;
  String? _adminCompanyName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getAdminDetails().then((_) {
      print('Admin details loaded. _adminCompanyName: $_adminCompanyName');
      setState(() {
        _isLoading = false;
      });
    }).catchError((e) {
      print('Error in initState: $e');
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _getAdminDetails() async {
    try {
      String? adminUid = FirebaseAuth.instance.currentUser?.uid;
      print('Current User UID: $adminUid');
      if (adminUid == null) {
        print('No authenticated user found');
        setState(() {
          _adminCompanyName = 'tes';
          _isLoading = false;
        });
        return;
      }
      DocumentSnapshot adminSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .get();
      if (adminSnapshot.exists && adminSnapshot['Company Name'] != null) {
        setState(() {
          _adminCompanyName = adminSnapshot['Company Name'] as String;
          print('Admin UID: $adminUid, Company Name: $_adminCompanyName');
        });
      } else {
        print('Admin document does not exist or Company Name is null for UID: $adminUid. Data: ${adminSnapshot.data()}');
        setState(() {
          _adminCompanyName = 'tes';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching admin details: $e');
      setState(() {
        _adminCompanyName = 'tes';
        _isLoading = false;
      });
    }
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

  Future<void> _createIndexIfNeeded() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collectionGroup('visits')
          .where('Company Name', isEqualTo: _adminCompanyName ?? 'tes')
          .limit(1)
          .get();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Ekstrak URL indeks dari pesan error
        String errorMessage = e.message ?? '';
        RegExp regExp = RegExp(r'http[s]?://[^\s]+');
        Iterable<Match> matches = regExp.allMatches(errorMessage);
        if (matches.isNotEmpty) {
          String indexUrl = matches.first.group(0) ?? '';
          if (await canLaunch(indexUrl)) {
            await launch(indexUrl);
            print('Opened index creation URL: $indexUrl');
          } else {
            print('Could not launch index URL: $indexUrl');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building UI. _isLoading: $_isLoading, _adminCompanyName: $_adminCompanyName');
    if (_isLoading || _adminCompanyName == null) {
      _createIndexIfNeeded(); // Coba buat indeks jika diperlukan
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text('Visit Approval', style: TextStyle(color: Colors.white)),
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
                    stream: FirebaseFirestore.instance
                        .collectionGroup('visits')
                        .where('Company Name', isEqualTo: _adminCompanyName ?? 'tes')
                        .snapshots(),
                    builder: (context, snapshot) {
                      print('StreamBuilder snapshot: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}, data length: ${snapshot.data?.docs.length}');
                      if (!snapshot.hasData) {
                        _createIndexIfNeeded(); // Coba buat indeks jika data belum tersedia
                        return Center(child: CircularProgressIndicator());
                      }

                      var visits = snapshot.data!.docs.where((visit) {
                        var data = visit.data() as Map<String, dynamic>?;
                        if (data == null || data['visit_in_time'] == null) {
                          return false;
                        }
                        var visitTime = (data['visit_in_time'] as Timestamp).toDate();
                        return visitTime.year == _selectedDate.year &&
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
                                        destinationCompany,
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
        if (visitType == 'Visit In' && destinationCompany != null)
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

extension DateTimeExtensions on DateTime {
  bool isSameDay(DateTime other) {
    return this.year == other.year &&
        this.month == other.month &&
        this.day == other.day;
  }
}