import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'history_clock_page.dart';

class ClockPage extends StatefulWidget {
  const ClockPage({Key? key}) : super(key: key);

  @override
  _ClockPageState createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> {
  String _clockStatus = 'Clock Out';
  List<Map<String, String>> _logbookEntries = [];
  DateTime? _clockInTime;
  Position? _currentPosition;
  bool _isClockInDisabled = false;
  String _clockInTimeStr = '';
  String _clockOutTimeStr = '';
  String _workingHoursStr = '';
  String? _currentRecordId;
  TimeOfDay? _designatedStartTime;
  Duration _lateDuration = Duration.zero;
  String? _lateReason;
  File? _image;

  String? _userName;
  String? _userId;

  final double _officeLat = -6.12333;
  final double _officeLong = 106.79869;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;

  final ImagePicker _picker = ImagePicker();

  final GlobalKey _totalHoursKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _getDesignatedStartTime();
    _getUserInfo();
  }

  void _getDesignatedStartTime() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('settings')
        .doc('designatedStartTime')
        .get();

    if (snapshot.exists) {
      Timestamp timestamp = snapshot['time'];
      DateTime dateTime = timestamp.toDate();
      setState(() {
        _designatedStartTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      });
    }
  }

  void _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _showAlertDialog("Aplikasi membutuhkan izin lokasi untuk berfungsi.");
      return;
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _getCurrentLocation();
    }
  }

  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Could not get location: $e");
    }
  }

  Future<void> _getUserInfo() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print("User found in FirebaseAuth: ${user.uid}");
        DocumentSnapshot userSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userSnapshot.exists) {
          print("User found in Firestore: ${userSnapshot.data()}");
          setState(() {
            _userName = userSnapshot['displayName'];
            _userId = user.uid;
          });
        } else {
          print("Pengguna tidak ditemukan di database.");
        }
      } else {
        print("Pengguna belum login.");
      }
    } catch (e) {
      print("Terjadi kesalahan saat mengambil informasi pengguna: $e");
    }
  }

  bool _canClockIn() {
    if (_designatedStartTime == null) {
      return false;
    }

    final now = TimeOfDay.now();
    final startDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _designatedStartTime!.hour,
      _designatedStartTime!.minute,
    );

    final allowedClockInTime = startDateTime.subtract(Duration(minutes: 30));

    final nowDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      now.hour,
      now.minute,
    );

    return nowDateTime.isAfter(allowedClockInTime);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _clockIn();
    } else {
      _showAlertDialog("Anda harus mengambil foto untuk Clock In.");
    }
  }

  Future<void> _pickImageForClockOut() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _showLogbookDialog();
    } else {
      _showAlertDialog("Anda harus mengambil foto untuk Clock Out.");
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageReference = _storage.ref().child("clockin_images/$fileName");
      UploadTask uploadTask = storageReference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      throw e;
    }
  }

  Future<void> _clockIn() async {
    if (_designatedStartTime == null) {
      _showAlertDialog("Designated start time not set.");
      return;
    }

    if (_userName == null || _userId == null) {
      await _getUserInfo();

      if (_userName == null || _userId == null) {
        _showAlertDialog("User information not available.");
        return;
      }
    }

    final now = TimeOfDay.now();
    final startDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _designatedStartTime!.hour,
      _designatedStartTime!.minute,
    );

    final nowDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      now.hour,
      now.minute,
    );

    if (!_canClockIn() && nowDateTime.isBefore(startDateTime)) {
      _showAlertDialog("Clock in is allowed only 30 minutes before the designated start time.");
      return;
    }

    if (_clockStatus == 'Clock Out') {
      if (_currentPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
            _officeLat, _officeLong, _currentPosition!.latitude, _currentPosition!.longitude);
        if (distanceInMeters <= 100) {
          if (nowDateTime.isAfter(startDateTime)) {
            _showLateReasonDialog();
          } else {
            _processClockIn();
          }
        } else {
          _showAlertDialog("Anda berada diluar jangkauan lokasi kantor.");
        }
      } else {
        _getCurrentLocation();
      }
    } else {
      _showAlertDialog("Anda harus melakukan Clock Out terlebih dahulu.");
    }
  }

  Future<void> _processClockIn() async {
    final now = TimeOfDay.now();
    final startDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _designatedStartTime!.hour,
      _designatedStartTime!.minute,
    );

    final nowDateTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      now.hour,
      now.minute,
    );

    setState(() {
      _clockStatus = 'Clock In';
      _clockInTime = DateTime.now();
      _clockInTimeStr = _formattedDateTime(_clockInTime!);
      _isClockInDisabled = true;

      if (nowDateTime.isAfter(startDateTime)) {
        _lateDuration = nowDateTime.difference(startDateTime);
      }
    });

    String imageUrl = await _uploadImage(_image!);

    DocumentReference userDocRef = _firestore.collection('users').doc(_userId);
    DocumentReference docRef = await userDocRef.collection('clockin_records').add({
      'user_name': _userName,
      'user_id': _userId,
      'clockin_location': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
      'timestamp': Timestamp.now(),
      'clock_in_time': _clockInTime,
      'is_late': nowDateTime.isAfter(startDateTime),
      'late_duration': _formattedDuration(_lateDuration),
      'late_reason': _lateReason,
      'image_url': imageUrl,
    });
    setState(() {
      _currentRecordId = docRef.id;
      print("Clock In ID: $_currentRecordId"); // Logging for debugging
    });
  }

  Future<void> _performClockOut() async {
    final clockOutDateTime = DateTime.now();

    setState(() {
      _clockStatus = 'Clock Out';
      Duration workingHours = clockOutDateTime.difference(_clockInTime!);
      _clockOutTimeStr = _formattedDateTime(clockOutDateTime);
      _workingHoursStr = _formattedDuration(workingHours);
      _isClockInDisabled = false;
    });

    if (_currentRecordId != null) {
      print("Clock Out using ID: $_currentRecordId"); // Logging for debugging
      String imageUrl = await _uploadImage(_image!);

      DocumentReference userDocRef = _firestore.collection('users').doc(_userId);
      await userDocRef.collection('clockin_records').doc(_currentRecordId).update({
        'clockout_location': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'timestamp': Timestamp.now(),
        'clock_out_time': clockOutDateTime,
        'logbook_entries': _logbookEntries,
        'total_working_hours': _workingHoursStr,
        'approved': false,
        'clock_out_image_url': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success submit'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showAlertDialog("No current record ID found for updating clock out.");
    }
  }

  void _clockOut() {
    if (_clockStatus == 'Clock In') {
      if (_currentPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
            _officeLat, _officeLong, _currentPosition!.latitude, _currentPosition!.longitude);
        if (distanceInMeters <= 100) {
          _pickImageForClockOut();
        } else {
          _showAlertDialog("Anda berada diluar jangkauan lokasi kantor.");
        }
      } else {
        _getCurrentLocation();
      }
    } else {
      _showAlertDialog("Anda harus melakukan Clock In terlebih dahulu.");
    }
  }

  void _showLogbookDialog() {
    TextEditingController timeStartController = TextEditingController();
    TextEditingController timeEndController = TextEditingController();
    TextEditingController activityController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Logbook"),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Waktu Mulai',
                        controller: timeStartController,
                        isEndTime: false,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Waktu Selesai',
                        controller: timeEndController,
                        isEndTime: true,
                        validateAgainst: timeStartController,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: activityController,
                  decoration: InputDecoration(
                    labelText: 'Aktivitas',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Entri Saat Ini:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  height: 200, // Berikan tinggi tetap untuk daftar entri logbook
                  child: SingleChildScrollView(
                    child: Table(
                      border: TableBorder.all(color: Colors.black),
                      columnWidths: const <int, TableColumnWidth>{
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          children: [
                            TableCell(
                              child: Container(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Waktu',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Aktivitas',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            TableCell(
                              child: Container(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Edit',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        ..._logbookEntries.asMap().entries.map((entry) {
                          int index = entry.key;
                          return TableRow(
                            children: [
                              TableCell(
                                child: Container(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(entry.value['time_range'] ?? ''),
                                ),
                              ),
                              TableCell(
                                child: Container(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(entry.value['activity'] ?? ''),
                                ),
                              ),
                              TableCell(
                                child: Container(
                                  padding: EdgeInsets.all(8.0),
                                  child: IconButton(
                                    icon: Icon(Icons.edit),
                                    onPressed: () {
                                      _editLogbookEntry(index);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (timeStartController.text.isNotEmpty &&
                            timeEndController.text.isNotEmpty &&
                            activityController.text.isNotEmpty) {
                          setState(() {
                            _logbookEntries.add({
                              'time_range': '${timeStartController.text} - ${timeEndController.text}',
                              'activity': activityController.text,
                            });
                          });
                          timeStartController.clear();
                          timeEndController.clear();
                          activityController.clear();
                          _showLogbookDialog();
                        } else {
                          _showAlertDialog("Silakan isi semua waktu dan aktivitas.");
                        }
                      },
                      child: Text('Tambah'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_logbookEntries.isNotEmpty) {
                          Navigator.of(context).pop();
                          _performClockOut();
                        } else {
                          _showAlertDialog("Silakan tambahkan setidaknya satu entri logbook.");
                        }
                      },
                      child: Text('Selesai'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TextEditingController controller,
    bool isEndTime = false,
    TextEditingController? validateAgainst,
  }) {
    return GestureDetector(
      onTap: () {
        _showTimePickerDialog(context, label, controller, isEndTime, validateAgainst);
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  void _showTimePickerDialog(BuildContext context, String label,
      TextEditingController controller, bool isEndTime,
      [TextEditingController? validateAgainst]) {
    int initialHour = 0;
    int initialMinute = 0;

    if (controller.text.isNotEmpty) {
      final timeParts = controller.text.split(':');
      if (timeParts.length == 2) {
        initialHour = int.parse(timeParts[0]);
        initialMinute = int.parse(timeParts[1]);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(label),
          content: Container(
            height: 150.0,
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: initialHour),
                    itemExtent: 32.0,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        initialHour = index;
                      });
                    },
                    children: List<Widget>.generate(24, (int index) {
                      return Center(child: Text(index.toString().padLeft(2, '0')));
                    }),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: initialMinute),
                    itemExtent: 32.0,
                    onSelectedItemChanged: (int index) {
                      setState(() {
                        initialMinute = index;
                      });
                    },
                    children: List<Widget>.generate(60, (int index) {
                      return Center(child: Text(index.toString().padLeft(2, '0')));
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Simpan'),
              onPressed: () {
                setState(() {
                  final formattedTime = '${initialHour.toString().padLeft(2, '0')}:${initialMinute.toString().padLeft(2, '0')}';
                  if (isEndTime) {
                    if (validateAgainst != null && validateAgainst.text == formattedTime) {
                      _showAlertDialog("Waktu selesai tidak boleh sama dengan waktu mulai.");
                    } else {
                      controller.text = formattedTime;
                    }
                  } else {
                    controller.text = formattedTime;
                  }
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _editLogbookEntry(int index) {
    TextEditingController timeStartController = TextEditingController(
      text: _logbookEntries[index]['time_range']?.split(' - ')[0],
    );
    TextEditingController timeEndController = TextEditingController(
      text: _logbookEntries[index]['time_range']?.split(' - ')[1],
    );
    TextEditingController activityController = TextEditingController(
      text: _logbookEntries[index]['activity'],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Edit Logbook Entry"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimePickerField(
                label: 'Waktu Mulai',
                controller: timeStartController,
              ),
              SizedBox(height: 10),
              _buildTimePickerField(
                label: 'Waktu Selesai',
                controller: timeEndController,
                isEndTime: true,
                validateAgainst: timeStartController,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: activityController,
                decoration: InputDecoration(
                  labelText: 'Aktivitas',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Batal"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Simpan"),
              onPressed: () {
                setState(() {
                  if (timeStartController.text == timeEndController.text) {
                    _showAlertDialog("Waktu mulai dan selesai tidak boleh sama.");
                  } else {
                    _logbookEntries[index] = {
                      'time_range': '${timeStartController.text} - ${timeEndController.text}',
                      'activity': activityController.text,
                    };
                    Navigator.of(context).pop();
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showLateReasonDialog() {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Keterangan Terlambat"),
          content: TextFormField(
            controller: reasonController,
            decoration: InputDecoration(
              labelText: 'Alasan Keterlambatan',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text("Batal"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Simpan"),
              onPressed: () {
                setState(() {
                  _lateReason = reasonController.text;
                  Navigator.of(context).pop();
                  _processClockIn();
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Peringatan"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text("OK"),
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
    return "${_getFormattedDay(dateTime)}, ${dateTime.day} ${_getFormattedMonth(dateTime)} ${dateTime.year} ${_getFormattedTime(dateTime)}";
  }

  String _getFormattedDay(DateTime dateTime) {
    switch (dateTime.weekday) {
      case DateTime.monday:
        return "Senin";
      case DateTime.tuesday:
        return "Selasa";
      case DateTime.wednesday:
        return "Rabu";
      case DateTime.thursday:
        return "Kamis";
      case DateTime.friday:
        return "Jumat";
      case DateTime.saturday:
        return "Sabtu";
      case DateTime.sunday:
        return "Minggu";
      default:
        return "";
    }
  }

  String _getFormattedMonth(DateTime dateTime) {
    switch (dateTime.month) {
      case DateTime.january:
        return "Januari";
      case DateTime.february:
        return "Februari";
      case DateTime.march:
        return "Maret";
      case DateTime.april:
        return "April";
      case DateTime.may:
        return "Mei";
      case DateTime.june:
        return "Juni";
      case DateTime.july:
        return "Juli";
      case DateTime.august:
        return "Agustus";
      case DateTime.september:
        return "September";
      case DateTime.october:
        return "Oktober";
      case DateTime.november:
        return "November";
      case DateTime.december:
        return "Desember";
      default:
        return "";
    }
  }

  String _getFormattedTime(DateTime dateTime) {
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
  }

  String _formattedDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildLogBox(String title, String content, double width, double height, Alignment alignment, double textSize, double contentTextSize) {
    return Container(
      key: title == 'Total Working Hours' ? _totalHoursKey : null,
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
      ),
      alignment: alignment,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(fontSize: textSize, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Divider(thickness: 1),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: contentTextSize),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClockHistoryPage(userId: _userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Absensi'),
        centerTitle: true,
        actions: [],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 20),
              Text(
                'Status: $_clockStatus',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: _isClockInDisabled ? null : _pickImage,
                    child: Text('Clock In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      textStyle: TextStyle(fontSize: 16),
                      foregroundColor: Colors.black,
                      minimumSize: Size(150, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _clockStatus == 'Clock Out' ? null : _clockOut,
                    child: Text('Clock Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      textStyle: TextStyle(fontSize: 16),
                      foregroundColor: Colors.black,
                      minimumSize: Size(150, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              if (_lateDuration > Duration.zero)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    'Late Duration: ${_formattedDuration(_lateDuration)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              Divider(thickness: 2),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildLogBox('Clock In', _clockInTimeStr, double.infinity, 120, Alignment.center, 16, 17),
                        ),
                        SizedBox(width: 15),
                        Expanded(
                          child: _buildLogBox('Clock Out', _clockOutTimeStr, double.infinity, 120, Alignment.center, 16, 17),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 100, vertical: 0),
                      child: _buildLogBox('Total Jam Kerja', _workingHoursStr, double.infinity, 80, Alignment.center, 16, 17),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 0),
                      child: _buildLogBox('Logbook Entry', _logbookEntries.map((entry) => '${entry['time_range']}: ${entry['activity']}').join('\n'), double.infinity, 120, Alignment.center, 16, 17),
                    ),
                    Divider(thickness: 1),
                    ListTile(
                      title: Text(
                        'Lihat Riwayat Clock In/Out',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.blue),
                      onTap: _navigateToHistoryPage,
                    ),
                    Divider(thickness: 1),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
