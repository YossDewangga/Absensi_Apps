import 'dart:io';
import 'package:absensi_apps/User/user_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/foundation.dart'; // Untuk mendeteksi platform (web atau mobile)
import 'history_clock_page.dart';

class ClockPage extends StatefulWidget {
  const ClockPage({Key? key}) : super(key: key);

  @override
  _ClockPageState createState() => _ClockPageState();
}

class _ClockPageState extends State<ClockPage> with WidgetsBindingObserver {
  String _clockStatus = 'Clock Out';
  List<Map<String, dynamic>> _logbookEntries = [];
  DateTime? _clockInTime;
  DateTime? _clockOutTime;
  Position? _currentPosition;
  String? _currentRecordId;
  TimeOfDay? _designatedStartTime;
  TimeOfDay? _designatedEndTime;
  Duration _lateDuration = Duration.zero;
  Duration _workingHours = Duration.zero;
  String? _lateReason;
  File? _image;

  String? _userName;
  String? _userId;

  final double _officeLat = -6.12333; // Koordinat latitude kantor
  final double _officeLong = 106.79869; // Koordinat longitude kantor
  final double _radius = 100; // Radius dalam meter

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
    _getDesignatedTimes();
    _getUserInfo();
    _getClockStatus(); // Ambil status tombol saat inisialisasi
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_clockStatus == 'Clock Out') {
      _logbookEntries.clear(); // Kosongkan logbook saat keluar dari halaman jika sudah clock out
    }
    super.dispose();
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

  void _getDesignatedTimes() async {
    try {
      DocumentSnapshot startSnapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('absensi_times')
          .get();

      if (startSnapshot.exists) {
        Timestamp startTimestamp = startSnapshot['designatedStartTime'];
        DateTime startDateTime = startTimestamp.toDate();
        setState(() {
          _designatedStartTime = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
        });

        Timestamp endTimestamp = startSnapshot['designatedEndTime'];
        DateTime endDateTime = endTimestamp.toDate();
        setState(() {
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
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print("User found in FirebaseAuth: ${user.uid}");
        DocumentSnapshot userSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userSnapshot.exists) {
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

  Future<void> _getClockStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot userSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('clockin_records')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          DocumentSnapshot latestRecord = userSnapshot.docs.first;
          setState(() {
            _clockStatus = latestRecord['clock_status'] ?? 'Clock Out';
            _currentRecordId = latestRecord.id;
            _clockInTime = (latestRecord['clock_in_time'] as Timestamp).toDate();
            if (latestRecord['is_late'] == true) {
              _lateDuration = _parseDuration(latestRecord['late_duration']);
            }
          });
        }
      }
    } catch (e) {
      print("Error getting clock status: $e");
    }
  }

  Duration _parseDuration(String duration) {
    List<String> parts = duration.split(':');
    int hours = int.parse(parts[0]);
    int minutes = int.parse(parts[1]);
    int seconds = int.parse(parts[2]);
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  Future<void> _pickImageForClockIn() async {
    final pickedFile;

    if (kIsWeb) {
      // Gunakan kamera di web
      pickedFile = await _picker.pickImage(source: ImageSource.camera);
    } else {
      // Gunakan kamera di mobile
      pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // Kamera depan
      );
    }

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      setState(() {
        _image = File(pickedFile.path);
      });

      // Deteksi wajah setelah mengambil gambar
      bool isFaceDetected = await _detectFace(_image!);
      if (isFaceDetected) {
        _clockIn(); // Lanjutkan Clock In jika wajah terdeteksi
      } else {
        _showAlertDialog("Wajah tidak terdeteksi, silakan coba lagi.");
      }
    } else {
      _showAlertDialog("Anda harus mengambil foto dengan kamera depan untuk Clock In.");
    }
  }

  Future<void> _pickImageForClockOut() async {
    final pickedFile;

    if (kIsWeb) {
      // Gunakan kamera di web
      pickedFile = await _picker.pickImage(source: ImageSource.camera);
    } else {
      // Gunakan kamera di mobile
      pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // Kamera depan
      );
    }

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      setState(() {
        _image = File(pickedFile.path);
      });

      // Deteksi wajah setelah mengambil gambar
      bool isFaceDetected = await _detectFace(_image!);
      if (isFaceDetected) {
        _performClockOut(); // Lanjutkan Clock Out jika wajah terdeteksi
      } else {
        _showAlertDialog("Wajah tidak terdeteksi, silakan coba lagi.");
      }
    } else {
      _showAlertDialog("Anda harus mengambil foto dengan kamera depan untuk Clock Out.");
    }
  }

  // Fungsi deteksi wajah menggunakan Google ML Kit
  Future<bool> _detectFace(File image) async {
    final InputImage inputImage = InputImage.fromFile(image);
    final FaceDetector faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
      ),
    );

    final List<Face> faces = await faceDetector.processImage(inputImage);

    return faces.isNotEmpty;
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

    if (_clockStatus == 'Clock Out') {
      if (_currentPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
            _officeLat, _officeLong, _currentPosition!.latitude, _currentPosition!.longitude);
        bool isClockInApproved = distanceInMeters <= _radius;

        if (!isClockInApproved) {
          _showAlertDialog("Anda berada di luar radius yang diizinkan untuk Clock In.");
          return;
        }

        if (nowDateTime.isAfter(startDateTime)) {
          _showLateReasonDialog(isClockInApproved);
        } else {
          _processClockIn(isClockInApproved);
        }
      } else {
        _getCurrentLocation();
      }
    } else {
      _showAlertDialog("Anda harus melakukan Clock Out terlebih dahulu.");
    }
  }

  Future<void> _processClockIn(bool isClockInApproved) async {
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

    // Tampilkan dialog loading
    await _showLoadingDialog();

    setState(() {
      _clockStatus = 'Clock In';
      _clockInTime = DateTime.now();
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
      'clock_status': _clockStatus,
      'approved': false, // Set approved to false until clock out
      'date': DateFormat('yyyy-MM-dd').format(_clockInTime!), // Tambahkan date saat clock in
    });

    setState(() {
      _currentRecordId = docRef.id;
    });

    // Tampilkan dialog sukses clock in
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading
      _showSuccessDialog("Clock in sukses");
    }
  }

  Future<void> _performClockOut() async {
    final clockOutDateTime = DateTime.now();

    // Tampilkan dialog loading
    await _showLoadingDialog();

    bool isClockOutApproved = true;
    setState(() {
      _clockStatus = 'Clock Out';
      _clockOutTime = clockOutDateTime; // Menyimpan waktu clock out
    });

    if (_currentRecordId != null) {
      if (_currentPosition != null) {
        double distanceInMeters = Geolocator.distanceBetween(
            _officeLat, _officeLong, _currentPosition!.latitude, _currentPosition!.longitude);
        isClockOutApproved = distanceInMeters <= _radius;

        // Cek apakah clock out dilakukan pada hari yang berbeda dari clock in
        if (_clockInTime != null && (_clockInTime!.day != _clockOutTime!.day || _clockInTime!.month != _clockOutTime!.month || _clockInTime!.year != _clockOutTime!.year)) {
          isClockOutApproved = false; // Set approved to false jika clock out dilakukan pada hari yang berbeda
        }

        // Lanjutkan dengan proses clock out meskipun tidak disetujui
        String imageUrl = await _uploadImage(_image!); // Upload image for clock out

        // Hitung working hours
        if (_clockInTime != null) {
          _workingHours = _clockOutTime!.difference(_clockInTime!);
        }

        // Hitung pulang cepat jika clock out lebih awal dari waktu yang ditentukan
        DateTime designatedEndDateTime = DateTime(
          _clockOutTime!.year,
          _clockOutTime!.month,
          _clockOutTime!.day,
          _designatedEndTime!.hour,
          _designatedEndTime!.minute,
        );

        Duration earlyLeaveDuration = Duration.zero;

        if (clockOutDateTime.isBefore(designatedEndDateTime)) {
          earlyLeaveDuration = designatedEndDateTime.difference(clockOutDateTime);
        }

        DocumentReference userDocRef = _firestore.collection('users').doc(_userId);
        await userDocRef.collection('clockin_records').doc(_currentRecordId).update({
          'clockout_location': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          'timestamp': Timestamp.now(),
          'clock_out_time': clockOutDateTime,
          'approved': isClockOutApproved, // Approval based on distance check and date check
          'clock_out_image_url': imageUrl,
          'clock_status': _clockStatus,
          'working_hours': _formattedDuration(_workingHours), // Simpan working hours
          'early_leave_duration': _formattedDuration(earlyLeaveDuration), // Simpan durasi pulang cepat jika ada
        });

        // Tampilkan dialog sukses clock out meskipun approval false
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading
          String successMessage = "Clock out sukses";
          if (earlyLeaveDuration > Duration.zero) {
            successMessage += "\nAnda pulang lebih awal selama: ${_formattedDuration(earlyLeaveDuration)}";
          }
          _showSuccessDialog(successMessage);
        }
      } else {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading
        _showAlertDialog("Tidak dapat menemukan ID catatan saat ini untuk pembaruan clock out.");
      }
    }
  }

  Future<void> _showLoadingDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _showLateReasonDialog(bool isClockInApproved) {
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
                if (reasonController.text.isNotEmpty) {
                  setState(() {
                    _lateReason = reasonController.text;
                    Navigator.of(context).pop();
                    _processClockIn(isClockInApproved);
                  });
                } else {
                  _showAlertDialog("Alasan keterlambatan wajib diisi.");
                }
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
          title: Text("Peringatan", style: TextStyle(color: Colors.teal.shade900)),
          content: Text(message, style: TextStyle(color: Colors.teal.shade900)),
          actions: <Widget>[
            TextButton(
              child: Text("OK", style: TextStyle(color: Colors.teal.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text("Sukses", style: TextStyle(color: Colors.teal.shade900)),
            ],
          ),
          content: Text(message, style: TextStyle(color: Colors.teal.shade900)),
          actions: <Widget>[
            TextButton(
              child: Text("OK", style: TextStyle(color: Colors.teal.shade700)),
              onPressed: () {
                Navigator.of(context).pop();
                // Update the state to reflect late duration without reloading the page
                setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  String _formattedDateTime(DateTime dateTime) {
    return "${_getFormattedDay(dateTime)},"
        " ${dateTime.day} ${_getFormattedMonth(dateTime)}"
        " ${dateTime.year} ${_getFormattedTime(dateTime)}";
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

  void _navigateToHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ClockHistoryPage(userId: _userId)),
    );
  }

  void _navigateToUserPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserPage()), // Navigasi ke UserPage
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Absensi'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _navigateToUserPage,
        ),
        backgroundColor: Colors.teal.shade700, // Sesuaikan warna AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 20),
              if (_designatedStartTime != null && _designatedEndTime != null)
                Column(
                  children: [
                    Text(
                      'Working Hours:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    Text(
                      'Start: ${_designatedStartTime!.format(context)}',
                      style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
                    ),
                    Text(
                      'End: ${_designatedEndTime!.format(context)}',
                      style: TextStyle(fontSize: 16, color: Colors.teal.shade900),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              Text(
                'Status: $_clockStatus',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: (_clockStatus == 'Clock In') ? null : _pickImageForClockIn,
                    child: Text('Clock In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_clockStatus == 'Clock In') ? Colors.grey : Colors.teal.shade700, // Warna teal untuk tombol aktif
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      textStyle: TextStyle(fontSize: 16),
                      foregroundColor: Colors.white, // Warna teks putih
                      minimumSize: Size(150, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.teal.shade700), // Border teal
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (_clockStatus == 'Clock Out') ? null : _pickImageForClockOut,
                    child: Text('Clock Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700, // Warna teal untuk tombol aktif
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      textStyle: TextStyle(fontSize: 16),
                      foregroundColor: Colors.white, // Warna teks putih
                      minimumSize: Size(150, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.teal.shade700), // Border teal
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    Divider(thickness: 1),
                    ListTile(
                      title: Text(
                        'Lihat Riwayat Clock In/Out',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                      ),
                      trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.teal.shade700),
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
