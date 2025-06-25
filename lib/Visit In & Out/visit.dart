import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Super Admin/super_admin_page.dart';
import 'history_visit_page.dart';

class VisitInAndOutPage extends StatefulWidget {
  const VisitInAndOutPage({Key? key}) : super(key: key);

  @override
  _VisitInAndOutPageState createState() => _VisitInAndOutPageState();
}

class _VisitInAndOutPageState extends State<VisitInAndOutPage> {
  DateTime? _visitOutTime;
  String _visitOutDateTime = 'Unknown';
  bool _visitInCompleted = false;
  bool _visitOutCompleted = false;
  File? _visitInImage;
  File? _visitOutImage;
  String _visitInLocation = 'Unknown';
  String _visitInAddress = 'Unknown';
  String _visitOutLocation = 'Unknown';
  String _visitOutAddress = 'Unknown';
  String _visitInDocumentId = '';
  String _clockInDocumentId = '';
  Position? _visitInPosition;
  String? _userId;
  DateTime? _visitInTime;
  String _visitInDateTime = 'Unknown';
  String _nextDestination = '';
  String _visitStatus = 'Not Visited';
  String? _displayName;
  String? _companyName; // Menyimpan Company Name dari profil pengguna
  String _selectedOption = 'Pulang';
  bool _isOtherOptionSelected = false;
  TimeOfDay? _designatedStartTime;
  TimeOfDay? _designatedEndTime;
  Duration _lateDuration = Duration.zero;
  Duration _earlyLeaveDuration = Duration.zero;
  final double _officeLat = -6.12333;
  final double _officeLong = 106.79869;
  final double _radius = 100;
  bool isLoading = false;
  bool _isOutsideDesignatedArea = false;
  Map<String, dynamic>? _userData;
  List<dynamic> _userAccess = [];
  bool _isLoadingUserAccess = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _checkPermission();
    _getUserInfo();
    _getDesignatedTimes();
    _fetchUserAccess();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        // Izin diberikan
      } else {
        _showSnackBar('Izin lokasi diperlukan untuk mengakses GPS.');
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _getDesignatedTimes() async {
    try {
      DocumentSnapshot startSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('absensi_times')
          .get();

      if (startSnapshot.exists) {
        Timestamp startTimestamp = startSnapshot['designatedStartTime'];
        DateTime startDateTime = startTimestamp.toDate();
        Timestamp endTimestamp = startSnapshot['designatedEndTime'];
        DateTime endDateTime = endTimestamp.toDate();

        setState(() {
          _designatedStartTime = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
          _designatedEndTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
        });
      } else {
        print("Designated times document does not exist");
      }
    } catch (e) {
      print('Error loading designated times: $e');
      _showAlertDialog('Error loading designated times: $e');
    }
  }

  Future<void> _getUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
        _displayName = user.displayName;
      });
      await _getUserCompanyName(); // Ambil Company Name dari Firestore
      await _loadVisitStatus();
    } else {
      _showSnackBar('Pengguna belum masuk.');
    }
  }

  Future<void> _getUserCompanyName() async {
    try {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      if (userSnapshot.exists) {
        setState(() {
          _companyName = userSnapshot['Company Name'] ?? ''; // Menggunakan 'Company Name' dengan spasi
          print('Company Name from User: $_companyName');
        });
      } else {
        print('Dokumen pengguna tidak ditemukan');
        _showAlertDialog('Dokumen pengguna tidak ditemukan');
      }
    } catch (e) {
      print('Error saat mengambil Company Name: $e');
      _showAlertDialog('Gagal mengambil nama perusahaan: $e');
    }
  }

  Future<void> _loadVisitStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitStatus = prefs.getString('visit_status') ?? 'Not Visited';
      _visitInCompleted = prefs.getBool('visit_in_completed') ?? false;
      _visitOutCompleted = prefs.getBool('visit_out_completed') ?? false;
      _visitInDocumentId = prefs.getString('visit_in_document_id') ?? '';
      _clockInDocumentId = prefs.getString('clock_in_document_id') ?? '';
      _visitInDateTime = prefs.getString('visit_in_date_time') ?? 'Unknown';
      _visitOutDateTime = prefs.getString('visit_out_date_time') ?? 'Unknown';
      _visitInLocation = prefs.getString('visit_in_location') ?? 'Unknown';
      _visitInAddress = prefs.getString('visit_in_address') ?? 'Unknown';
      _visitOutLocation = prefs.getString('visit_out_location') ?? 'Unknown';
      _visitOutAddress = prefs.getString('visit_out_address') ?? 'Unknown';
      _nextDestination = prefs.getString('next_destination') ?? '';
      if (_visitStatus == 'Visit In' && _visitInCompleted) {
        _loadVisitInDetails();
      }
    });
  }

  Future<void> _loadVisitInDetails() async {
    if (_userId != null && _visitStatus == 'Visit In') {
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
      DocumentSnapshot visitSnapshot = await userDocRef.collection('visits').doc(_visitInDocumentId).get();
      if (visitSnapshot.exists) {
        setState(() {
          _visitInLocation = visitSnapshot['visit_in_location'];
          _visitInAddress = visitSnapshot['visit_in_address'];
          _visitInTime = (visitSnapshot['visit_in_time'] as Timestamp).toDate();
          _updateVisitInDateTime();
          List<String> locationParts = _visitInLocation.split(',');
          _visitInPosition = Position(
            latitude: double.parse(locationParts[0]),
            longitude: double.parse(locationParts[1]),
            timestamp: DateTime.now(),
            altitude: 0.0,
            accuracy: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });
      }
    }
  }

  Future<void> _visitIn() async {
    await _takePicture(true);
  }

  Future<void> _visitOut() async {
    await _takePicture(false);

    if (_selectedOption == 'Pulang' && _designatedEndTime != null) {
      final DateTime nowDateTime = DateTime.now();
      final DateTime endDateTime = DateTime(
        nowDateTime.year,
        nowDateTime.month,
        nowDateTime.day,
        _designatedEndTime!.hour,
        _designatedEndTime!.minute,
      );

      if (nowDateTime.isBefore(endDateTime)) {
        setState(() {
          _earlyLeaveDuration = endDateTime.difference(nowDateTime);
        });
      }
    }
  }

  Future<String> _saveVisitInToFirestore(String downloadUrl) async {
    if (_companyName == null || _companyName!.isEmpty) {
      await _getUserCompanyName(); // Pastikan Company Name diambil jika belum ada
    }
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    DocumentReference visitDocRef = await userDocRef.collection('visits').add({
      'visit_in_time': _visitInTime,
      'visit_in_location': _visitInLocation,
      'visit_in_address': _visitInAddress,
      'visit_in_imageUrl': downloadUrl,
      'visit_status': 'Visit In',
      'displayName': _displayName,
      'Company Name': _companyName ?? 'Unknown', // Menggunakan 'Company Name' dengan spasi
      'destination_company': _nextDestination, // Dari dialog
      'approved': false,
    });
    print('Company Name saved: ${_companyName ?? 'Unknown'}');
    print('Destination Company: $_nextDestination');
    return visitDocRef.id;
  }

  Future<void> _saveVisitOutToFirestore(String downloadUrl, bool isApproved) async {
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    DocumentReference visitDocRef = userDocRef.collection('visits').doc(_visitInDocumentId);

    try {
      DocumentSnapshot visitSnapshot = await visitDocRef.get();
      if (visitSnapshot.exists) {
        await visitDocRef.update({
          'visit_out_time': _visitOutTime,
          'visit_out_location': _visitOutLocation,
          'visit_out_address': _visitOutAddress,
          'visit_out_imageUrl': downloadUrl,
          'next_destination': _nextDestination,
          'visit_status': 'Visit Out',
          'approved': isApproved,
        });
        print('Data updated successfully');
      } else {
        print('Visit document not found');
        _showAlertDialog('Visit document not found');
      }
    } catch (e) {
      print('Error updating document: $e');
      _showAlertDialog('Error updating document');
    }
  }

  bool _isTimeWithinRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  Future<void> _showNextDestinationDialog() async {
    TimeOfDay now = TimeOfDay.now();
    TimeOfDay startTime1 = TimeOfDay(hour: 00, minute: 00);
    TimeOfDay endTime1 = TimeOfDay(hour: 15, minute: 59);
    TimeOfDay startTime2 = TimeOfDay(hour: 16, minute: 00);
    TimeOfDay endTime2 = TimeOfDay(hour: 23, minute: 59);

    if (_isTimeWithinRange(now, startTime1, endTime1)) {
      return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: Colors.white,
                  child: StatefulBuilder(
                    builder: (context, setStateDialog) => SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.teal.shade400, Colors.teal.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.navigation_rounded, color: Colors.white, size: 60),
                                SizedBox(height: 12),
                                Text(
                                  'Tujuan Selanjutnya',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                            child: Column(
                              children: [
                                Text(
                                  'Masukkan tujuan selanjutnya setelah Visit Out.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 17, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 22),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                                    child: TextField(
                                      onChanged: (value) {
                                        setStateDialog(() {
                                          _nextDestination = value;
                                        });
                                      },
                                      style: TextStyle(fontSize: 16),
                                      decoration: InputDecoration(
                                        hintText: "Masukkan tujuan selanjutnya",
                                        hintStyle: TextStyle(color: Colors.teal.shade700),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: Colors.teal.shade200),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      elevation: 3,
                                    ),
                                    onPressed: () async {
                                      if (_nextDestination.isEmpty) {
                                        _showAlertDialog('Tujuan Selanjutnya harus diisi.');
                                      } else {
                                        Navigator.of(context).pop();
                                        await _submitNextDestination();
                                        String downloadUrl = await _uploadImageToStorage(_visitOutImage!, 'visit_out_images');
                                        await _saveVisitOutToFirestore(downloadUrl, true);
                                        _showSuccessDialog('Visit Out sukses.');
                                      }
                                    },
                                    child: Text(
                                      'Submit',
                                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else if (_isTimeWithinRange(now, startTime2, endTime2)) {
      return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: Colors.white,
                  child: StatefulBuilder(
                    builder: (context, setStateDialog) => SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.teal.shade400, Colors.teal.shade900],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.navigation_rounded, color: Colors.white, size: 60),
                                SizedBox(height: 12),
                                Text(
                                  'Tujuan Selanjutnya',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                            child: Column(
                              children: [
                                Text(
                                  'Silakan pilih atau masukkan tujuan selanjutnya setelah Visit Out.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 17, color: Colors.teal.shade900, fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 22),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      RadioListTile<String>(
                                        title: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Text('Pulang', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                        value: 'Pulang',
                                        groupValue: _selectedOption,
                                        onChanged: (value) {
                                          setStateDialog(() {
                                            _selectedOption = value!;
                                            _isOtherOptionSelected = false;
                                            _nextDestination = 'Pulang';
                                          });
                                        },
                                        activeColor: Colors.teal.shade700,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      Divider(height: 0, color: Colors.teal.shade100),
                                      RadioListTile<String>(
                                        title: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Text('Lainnya', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                        value: 'Lainnya',
                                        groupValue: _selectedOption,
                                        onChanged: (value) {
                                          setStateDialog(() {
                                            _selectedOption = value!;
                                            _isOtherOptionSelected = true;
                                            _nextDestination = '';
                                          });
                                        },
                                        activeColor: Colors.teal.shade700,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      if (_isOtherOptionSelected)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                                          child: TextField(
                                            onChanged: (value) {
                                              _nextDestination = value;
                                            },
                                            style: TextStyle(fontSize: 16),
                                            decoration: InputDecoration(
                                              hintText: "Masukkan tujuan selanjutnya",
                                              hintStyle: TextStyle(color: Colors.teal.shade700),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: BorderSide(color: Colors.teal.shade200),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      elevation: 3,
                                    ),
                                    onPressed: () async {
                                      if (_selectedOption == 'Lainnya' && _nextDestination.isEmpty) {
                                        _showAlertDialog('Tujuan Selanjutnya harus diisi.');
                                      } else {
                                        Navigator.of(context).pop();
                                        await _submitNextDestination();
                                        if (_selectedOption == 'Pulang') {
                                          await _autoClockOut();
                                          _showSuccessDialog('Visit Out dan Clock Out sukses.');
                                        } else {
                                          _showSuccessDialog('Visit Out sukses.');
                                        }
                                      }
                                    },
                                    child: Text(
                                      'Submit',
                                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      _showAlertDialog('Waktu tidak valid untuk memasukkan tujuan selanjutnya.');
    }
  }

  Future<void> _submitNextDestination() async {
    await Future.delayed(Duration(seconds: 2));
  }

  Future<void> _autoClockIn(DateTime visitInTime, Position visitInPosition, String visitInImageUrl) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (_designatedStartTime != null) {
        final startDateTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          _designatedStartTime!.hour,
          _designatedStartTime!.minute,
        );

        final nowDateTime = visitInTime;

        if (nowDateTime.isAfter(startDateTime)) {
          setState(() {
            _lateDuration = nowDateTime.difference(startDateTime);
          });
        }

        QuerySnapshot clockInSnapshot = await userDocRef.collection('clockin_records')
            .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(nowDateTime))
            .where('clock_status', isEqualTo: 'Clock In')
            .get();

        if (clockInSnapshot.docs.isEmpty) {
          DocumentReference clockInDocRef = userDocRef.collection('clockin_records').doc();
          await clockInDocRef.set({
            'user_name': user.displayName,
            'user_id': user.uid,
            'Company Name': _companyName ?? 'Unknown',
            'clockin_location': GeoPoint(visitInPosition.latitude, visitInPosition.longitude),
            'timestamp': Timestamp.now(),
            'clock_in_time': visitInTime,
            'is_late': nowDateTime.isAfter(startDateTime),
            'late_duration': _formattedDuration(_lateDuration),
            'image_url': visitInImageUrl,
            'clock_status': 'Clock In',
            'approved': false,
            'date': DateFormat('yyyy-MM-dd').format(nowDateTime),
          }, SetOptions(merge: true));

          setState(() {
            _clockInDocumentId = clockInDocRef.id;
          });

          await _saveVisitStatus();
          print("Clock in otomatis berhasil berdasarkan visit in.");
        } else {
          print("Clock in sudah dilakukan hari ini.");
        }
      } else {
        print("Designated start time is not set.");
      }
    }
  }

  Future<void> _autoClockOut() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User tidak terautentikasi');
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final clockInQuery = await userDocRef.collection('clockin_records')
        .where('date', isEqualTo: today)
        .where('clock_status', isEqualTo: 'Clock In')
        .get();

    if (clockInQuery.docs.isEmpty) {
      throw Exception('Tidak ditemukan catatan Clock In hari ini');
    }

    final clockInDoc = clockInQuery.docs.first;
    final clockInTime = (clockInDoc.data()['clock_in_time'] as Timestamp).toDate();

    double outLat = double.parse(_visitOutLocation.split(',')[0].trim());
    double outLong = double.parse(_visitOutLocation.split(',')[1].trim());
    double distanceInMeters = Geolocator.distanceBetween(_officeLat, _officeLong, outLat, outLong);
    bool isClockOutApproved = distanceInMeters <= _radius;

    if (!isClockOutApproved) {
      _showAlertDialog('Anda berada di luar radius yang diizinkan untuk Clock Out.');
      return;
    }

    final workingHours = _visitOutTime!.difference(clockInTime);
    final workingHoursStr = _formattedDuration(workingHours);

    Duration earlyLeaveDuration = Duration.zero;
    if (_designatedEndTime != null) {
      final endDateTime = DateTime(
        _visitOutTime!.year,
        _visitOutTime!.month,
        _visitOutTime!.day,
        _designatedEndTime!.hour,
        _designatedEndTime!.minute,
      );

      if (_visitOutTime!.isBefore(endDateTime)) {
        earlyLeaveDuration = endDateTime.difference(_visitOutTime!);
      }
    }

    await clockInDoc.reference.update({
      'clockout_location': GeoPoint(outLat, outLong),
      'clock_out_time': _visitOutTime,
      'clock_status': 'Clock Out',
      'clock_out_image_url': await _uploadImageToStorage(_visitOutImage!, 'clock_out_images'),
      'working_hours': workingHoursStr,
      if (earlyLeaveDuration > Duration.zero)
        'early_leave_duration': _formattedDuration(earlyLeaveDuration),
      'approved': true,
    });
  }

  Future<void> _takePicture(bool isVisitIn) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final File imageFile = File(image.path);
      final img.Image? originalImage = img.decodeImage(imageFile.readAsBytesSync());
      final img.Image resizedImage = img.copyResize(originalImage!, width: 600);
      final String tempPath = '${imageFile.parent.path}/temp_image.jpg';
      final File resizedFile = File(tempPath)..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));
      setState(() {
        if (isVisitIn) {
          _visitInImage = resizedFile;
        } else {
          _visitOutImage = resizedFile;
        }
      });
      if (isVisitIn) {
        _startVisitInProcess();
      } else {
        _startVisitOutProcess();
      }
    }
  }

  Future<void> _getCurrentPosition(bool isVisitIn) async {
    try {
      print("Mencoba mendapatkan lokasi...");
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak secara permanen. Silakan aktifkan di pengaturan.');
      }
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        throw Exception('GPS tidak aktif. Silakan aktifkan GPS Anda.');
      }
      print("Mengambil posisi saat ini...");
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      );
      print("Posisi didapat: ${position.latitude}, ${position.longitude}");
      print("Mengambil detail alamat...");
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark placemark = placemarks.first;
      print("Detail alamat didapat");
      String fullAddress = '${placemark.name ?? ''}, '
          '${placemark.street ?? ''}, '
          '${placemark.subLocality ?? ''}, '
          '${placemark.locality ?? ''}, '
          '${placemark.administrativeArea ?? ''}';
      print("Menyimpan data lokasi untuk ${isVisitIn ? 'Visit In' : 'Visit Out'}");
      if (isVisitIn) {
        setState(() {
          _visitInPosition = position;
          _visitInLocation = '${position.latitude}, ${position.longitude}';
          _visitInAddress = fullAddress;
        });
        print("Data Visit In tersimpan: $_visitInLocation");
      } else {
        setState(() {
          _visitOutLocation = '${position.latitude}, ${position.longitude}';
          _visitOutAddress = fullAddress;
        });
        print("Data Visit Out tersimpan: $_visitOutLocation");
      }
    } catch (e) {
      print('Error saat mendapatkan lokasi: $e');
      String errorMessage = e.toString().contains('Exception:') ? e.toString().replaceAll('Exception: ', '') : 'Gagal mendapatkan lokasi: $e';
      _showAlertDialog(errorMessage);
      throw e;
    }
  }

  void _updateVisitInDateTime() {
    final DateFormat formatter = DateFormat.yMMMMd('id_ID').addPattern(" HH:mm");
    setState(() {
      _visitInDateTime = formatter.format(_visitInTime!);
    });
  }

  void _updateVisitOutDateTime() {
    final DateFormat formatter = DateFormat.yMMMMd('id_ID').addPattern(" HH:mm");
    setState(() {
      _visitOutDateTime = formatter.format(_visitOutTime!);
    });
  }

  Future<String> _uploadImageToStorage(File imageFile, String folderName) async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference ref = FirebaseStorage.instance.ref().child(folderName).child(fileName);
    UploadTask uploadTask = ref.putFile(imageFile);
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  String _formattedDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitHours = twoDigits(duration.inHours);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Peringatan', style: TextStyle(color: Colors.teal.shade900)),
          content: Text(message, style: TextStyle(color: Colors.teal.shade900)),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.teal.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message, {bool additionalDialog = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: 350),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.teal.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 54),
                          SizedBox(height: 10),
                          Text(
                            "Sukses",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18, left: 24, right: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (_isOutsideDesignatedArea) {
                              _showOutsideDesignatedAreaDialog();
                            }
                            setState(() {
                              isLoading = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                          child: Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOutsideDesignatedAreaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Peringatan', style: TextStyle(color: Colors.teal.shade900)),
          ],
        ),
        content: Text('Visit Out Completed, but you are outside the designated area', style: TextStyle(color: Colors.teal.shade900)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK', style: TextStyle(color: Colors.teal.shade700)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _saveVisitStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('visit_status', _visitStatus);
    await prefs.setBool('visit_in_completed', _visitInCompleted);
    await prefs.setBool('visit_out_completed', _visitOutCompleted);
    await prefs.setString('visit_in_document_id', _visitInDocumentId);
    await prefs.setString('clock_in_document_id', _clockInDocumentId);
    await prefs.setString('visit_in_date_time', _visitInDateTime);
    await prefs.setString('visit_out_date_time', _visitOutDateTime);
    await prefs.setString('visit_in_location', _visitInLocation);
    await prefs.setString('visit_in_address', _visitInAddress);
    await prefs.setString('visit_out_location', _visitOutLocation);
    await prefs.setString('visit_out_address', _visitOutAddress);
    await prefs.setString('next_destination', _nextDestination);
  }

  Future<void> _startVisitInProcess() async {
    setState(() {
      isLoading = true;
    });
    await _getCurrentPosition(true);
    if (_visitInImage != null && _visitInPosition != null) {
      setState(() {
        _visitInTime = DateTime.now();
        _updateVisitInDateTime();
      });
      try {
        await _showCompanyNameDialog(); // Ambil destination_company dari dialog
        String downloadUrl = await _uploadImageToStorage(_visitInImage!, 'visit_in_images');
        String documentId = await _saveVisitInToFirestore(downloadUrl);
        setState(() {
          _visitInCompleted = true;
          _visitInDocumentId = documentId;
          _visitStatus = 'Visit In';
          _visitOutCompleted = false;
          isLoading = false;
        });
        await _saveVisitStatus();
        await _autoClockIn(_visitInTime!, _visitInPosition!, downloadUrl);
        _showSuccessDialog('Visit In Completed');
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showAlertDialog('Gagal mengirim: $e');
      }
    } else {
      setState(() {
        isLoading = false;
      });
      _showAlertDialog('Gagal mendapatkan lokasi.');
    }
  }

  Future<void> _startVisitOutProcess() async {
    setState(() {
      isLoading = true;
      _nextDestination = "Pulang";
    });
    try {
      print("Memulai proses Visit Out...");
      if (_visitOutImage == null) {
        throw Exception('Foto Visit Out belum diambil');
      }
      print("Mengambil lokasi untuk Visit Out...");
      await _getCurrentPosition(false);
      if (_visitInPosition == null) {
        print("Memuat data Visit In karena posisi tidak ditemukan...");
        await _loadVisitInDetails();
        if (_visitInPosition == null) {
          throw Exception('Data Visit In tidak ditemukan');
        }
      }
      print("Menghitung jarak dari lokasi Visit In...");
      Position currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distanceInMeters = Geolocator.distanceBetween(
        _visitInPosition!.latitude,
        _visitInPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      bool isApproved = distanceInMeters <= _radius;
      print("Jarak dari lokasi Visit In: ${distanceInMeters.toStringAsFixed(2)} meter");
      print("Dalam radius yang diizinkan: $isApproved");
      setState(() {
        _visitOutTime = DateTime.now();
        _updateVisitOutDateTime();
      });
      print("Menampilkan dialog tujuan selanjutnya...");
      await _showNextDestinationDialog();
      print("Mengunggah foto Visit Out...");
      String downloadUrl = await _uploadImageToStorage(_visitOutImage!, 'visit_out_images');
      print("Foto berhasil diunggah");
      print("Menyimpan data Visit Out ke Firestore...");
      await _saveVisitOutToFirestore(downloadUrl, isApproved);
      print("Data Visit Out berhasil disimpan");
      setState(() {
        _visitOutCompleted = true;
        _visitStatus = 'Visit Out';
        _visitInCompleted = false;
        _isOutsideDesignatedArea = !isApproved;
        isLoading = false;
      });
      await _saveVisitStatus();
      print("Proses Visit Out selesai");
    } catch (e) {
      print("Error dalam proses Visit Out: $e");
      setState(() {
        isLoading = false;
      });
      String errorMessage = e.toString().contains('Exception:') ? e.toString().replaceAll('Exception: ', '') : 'Gagal melakukan Visit Out: $e';
      _showAlertDialog(errorMessage);
    }
  }

  Future<void> _showCompanyNameDialog() async {
    String destinationCompany = '';
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxWidth: 350),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade400, Colors.teal.shade900],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.business, color: Colors.white, size: 54),
                            SizedBox(height: 10),
                            Text(
                              'Nama Perusahaan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: Colors.white,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                        child: Column(
                          children: [
                            Text(
                              'Masukkan nama perusahaan yang sedang dikunjungi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
                            ),
                            SizedBox(height: 18),
                            TextField(
                              onChanged: (value) {
                                destinationCompany = value;
                              },
                              decoration: InputDecoration(
                                labelText: "Nama Perusahaan",
                                labelStyle: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                                filled: true,
                                fillColor: Colors.teal.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.teal.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                                ),
                              ),
                            ),
                            SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  elevation: 2,
                                ),
                                onPressed: () {
                                  if (destinationCompany.isEmpty) {
                                    _showAlertDialog('Nama Perusahaan harus diisi.');
                                  } else {
                                    Navigator.of(context).pop();
                                    setState(() {
                                      _nextDestination = destinationCompany;
                                    });
                                    print('Destination Company: $destinationCompany');
                                  }
                                },
                                child: Text(
                                  'Submit',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchUserAccess() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userSnapshot.exists) {
          setState(() {
            _userData = userSnapshot.data() as Map<String, dynamic>?;
            _userAccess = _userData?['access'] ?? [];
            _isLoadingUserAccess = false;
          });
        } else {
          setState(() {
            _isLoadingUserAccess = false;
          });
        }
      } else {
        setState(() {
          _isLoadingUserAccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingUserAccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserAccess) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text('Visit In/Out', style: TextStyle(color: Colors.white)),
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
          elevation: 4.0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_userAccess.contains('visit')) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text('Visit In/Out', style: TextStyle(color: Colors.white)),
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
          elevation: 4.0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: NoAccessWidget(featureName: 'Visit In/Out'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Visit In/Out', style: TextStyle(color: Colors.white)),
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
        elevation: 4.0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(),
                  SizedBox(height: 20),
                  _buildButtons(),
                  Divider(thickness: 1, color: Colors.teal.shade700),
                  ListTile(
                    title: Text(
                      'Lihat Log Kunjungan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.teal.shade700),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => VisitHistoryPage(userId: _userId)),
                      );
                    },
                  ),
                  Divider(thickness: 1, color: Colors.teal.shade700),
                ],
              ),
            ),
          ),
          if (isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(height: 10),
        Center(
          child: Text(
            'Silakan gunakan tombol di bawah untuk mencatat waktu kunjungan masuk dan keluar.',
            style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20),
        Divider(thickness: 2, color: Colors.teal.shade700),
        Center(
          child: Text(
            'Status Saat Ini: $_visitStatus',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
            textAlign: TextAlign.center,
          ),
        ),
        Divider(thickness: 2, color: Colors.teal.shade700),
      ],
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _visitInCompleted && !_visitOutCompleted ? null : _visitIn,
              icon: Icon(Icons.login),
              label: Text('Visit In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _visitInCompleted && !_visitOutCompleted ? Colors.grey : Colors.teal.shade700,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                textStyle: TextStyle(fontSize: 16),
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: !_visitInCompleted || _visitOutCompleted ? null : _visitOut,
              icon: Icon(Icons.logout),
              label: Text('Visit Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: !_visitInCompleted || _visitOutCompleted ? Colors.grey : Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                textStyle: TextStyle(fontSize: 16),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
      ],
    );
  }
}

class FullScreenImagePage extends StatelessWidget {
  final File imageFile;

  const FullScreenImagePage({Key? key, required this.imageFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.file(imageFile),
      ),
    );
  }
}