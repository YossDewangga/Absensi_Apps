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
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Super Admin/super_admin_page.dart';
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
  double? _companyLat;
  double? _companyLong;
  double? _companyRadius;
  String? _companyName;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _userData;
  List<dynamic> _userAccess = [];
  bool _isLoadingUserAccess = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
    _getUserInfo(); // Pastikan _companyName tersedia sebelum mengambil designated times
    _getClockStatus();
    _fetchUserAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logbookEntries.clear();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showAlertDialog("Izin lokasi ditolak. Silakan aktifkan di pengaturan.");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showAlertDialog("Izin lokasi ditolak secara permanen. Silakan aktifkan di pengaturan.");
      return;
    }
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15));
      if (mounted) setState(() => _currentPosition = position);
      print("Lokasi saat ini: Latitude = ${position.latitude}, Longitude = ${position.longitude}");
    } catch (e) {
      print("Gagal mendapatkan lokasi: $e");
      if (mounted) _showAlertDialog("Gagal mendapatkan lokasi. Pastikan GPS aktif dan coba lagi.");
    }
  }

  Future<void> _getDesignatedTimesFromCompany() async {
    if (_companyName == null || _companyName!.isEmpty) {
      print("Company Name belum tersedia untuk pengguna $_userId");
      if (mounted) _showAlertDialog("Data perusahaan belum tersedia. Silakan periksa pengaturan akun Anda.");
      return;
    }

    try {
      DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyName) // Menggunakan _companyName sebagai ID dokumen
          .get();

      if (!mounted) return;

      if (companySnapshot.exists) {
        Timestamp startTimestamp = companySnapshot['designatedStartTime'];
        DateTime startDateTime = startTimestamp.toDate();
        Timestamp endTimestamp = companySnapshot['designatedEndTime'];
        DateTime endDateTime = endTimestamp.toDate();
        if (mounted) {
          setState(() {
            _designatedStartTime = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
            _designatedEndTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
            print("Designated Times for $_companyName: Start = $_designatedStartTime, End = $_designatedEndTime");
          });
        }
      } else {
        print("Dokumen perusahaan $_companyName tidak ditemukan untuk pengguna $_userId");
        if (mounted) _showAlertDialog("Data jam kerja untuk perusahaan $_companyName tidak ditemukan. Silakan hubungi admin.");
      }
    } catch (e) {
      print('Error loading designated times for $_companyName: $e');
      if (mounted) {
        _showAlertDialog('Error loading designated times: $e');
      }
    }
  }

  Future<void> _getUserInfo() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(user.uid).get();
        if (!mounted) return;
        if (userSnapshot.exists) {
          if (mounted) {
            setState(() {
              _userName = userSnapshot['displayName'];
              _userId = user.uid;
            });
            await _getUserCompanyName();
            await _getDesignatedTimesFromCompany(); // Panggil setelah _companyName tersedia
          }
        } else {
          print("Dokumen pengguna tidak ditemukan untuk userId: $user.uid");
          if (mounted) _showAlertDialog("Dokumen pengguna tidak ditemukan. Silakan hubungi admin.");
        }
      } else {
        print("Pengguna belum masuk");
        if (mounted) _showAlertDialog("Pengguna belum masuk. Silakan login kembali.");
      }
    } catch (e) {
      print("Terjadi kesalahan saat mengambil informasi pengguna: $e");
      if (mounted) _showAlertDialog("Terjadi kesalahan saat mengambil data pengguna: $e");
    }
  }

  Future<void> _getUserCompanyName() async {
    try {
      DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(_userId).get();
      if (userSnapshot.exists) {
        if (mounted) {
          setState(() {
            _companyName = userSnapshot['Company Name'] ?? '';
            print('Company Name for user $_userId: $_companyName');
          });
        }
        if (_companyName != null && _companyName!.isNotEmpty) {
          DocumentSnapshot companySnapshot = await _firestore.collection('companies').doc(_companyName).get();
          if (!mounted) return;
          if (companySnapshot.exists) {
            if (mounted) {
              setState(() {
                _companyLat = companySnapshot['latitude'];
                _companyLong = companySnapshot['longitude'];
                _companyRadius = companySnapshot['radius']?.toDouble() ?? 250.0;
              });
              print("Koordinat perusahaan $_companyName: Latitude = $_companyLat, Longitude = $_companyLong, Radius = $_companyRadius");
            }
          } else {
            print("Dokumen perusahaan $_companyName tidak ditemukan untuk user $_userId");
            if (mounted) _showAlertDialog("Data perusahaan tidak ditemukan untuk $_companyName. Silakan hubungi admin.");
          }
        } else {
          print("Nama perusahaan tidak valid untuk user $_userId");
          if (mounted) _showAlertDialog("Nama perusahaan tidak valid. Silakan hubungi admin.");
        }
      } else {
        print('Dokumen pengguna tidak ditemukan untuk userId: $_userId');
        if (mounted) _showAlertDialog('Dokumen pengguna tidak ditemukan');
      }
    } catch (e) {
      print('Error saat mengambil Company Name untuk user $_userId: $e');
      if (mounted) _showAlertDialog('Gagal mengambil nama perusahaan: $e');
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

        if (!mounted) return;

        if (userSnapshot.docs.isNotEmpty) {
          DocumentSnapshot latestRecord = userSnapshot.docs.first;
          if (mounted) {
            setState(() {
              _clockStatus = latestRecord['clock_status'] ?? 'Clock Out';
              _currentRecordId = latestRecord.id;
              _clockInTime = (latestRecord['clock_in_time'] as Timestamp?)?.toDate();
              if (latestRecord['is_late'] == true) {
                _lateDuration = _parseDuration(latestRecord['late_duration']);
              }
            });
          }
        }
      }
    } catch (e) {
      print("Error getting clock status for user $_userId: $e");
    }
  }

  Duration _parseDuration(String duration) {
    List<String> parts = duration.split(':');
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]), seconds: int.parse(parts[2]));
  }

  Future<void> _pickImageForClockIn() async {
    final pickedFile = kIsWeb
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.front,
          );

    if (!mounted) return;

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      setState(() {
        _image = File(pickedFile.path);
      });

      bool isFaceDetected = await _detectFace(_image!);
      if (!mounted) return;
      if (isFaceDetected) {
        _clockIn();
      } else {
        _showAlertDialog("Wajah tidak terdeteksi, silakan coba lagi.");
      }
    } else {
      _showAlertDialog("Anda harus mengambil foto dengan kamera depan untuk Clock In.");
    }
  }

  Future<void> _pickImageForClockOut() async {
    final pickedFile = kIsWeb
        ? await _picker.pickImage(source: ImageSource.camera)
        : await _picker.pickImage(
            source: ImageSource.camera,
            preferredCameraDevice: CameraDevice.front,
          );

    if (!mounted) return;

    if (pickedFile != null && pickedFile.path.isNotEmpty) {
      setState(() {
        _image = File(pickedFile.path);
      });

      bool isFaceDetected = await _detectFace(_image!);
      if (!mounted) return;
      if (isFaceDetected) {
        _performClockOut();
      } else {
        _showAlertDialog("Wajah tidak terdeteksi, silakan coba lagi.");
      }
    } else {
      _showAlertDialog("Anda harus mengambil foto dengan kamera depan untuk Clock Out.");
    }
  }

  Future<bool> _detectFace(File image) async {
    final InputImage inputImage = InputImage.fromFile(image);
    final FaceDetector faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
      ),
    );

    final List<Face> faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();
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
      print("Error uploading image for user $_userId: $e");
      throw e;
    }
  }

  Future<void> _clockIn() async {
    if (_designatedStartTime == null) {
      if (mounted) {
        _showAlertDialog("Designated start time not set for $_companyName.");
      }
      return;
    }

    if (_userName == null || _userId == null || _companyLat == null || _companyLong == null || _companyName == null || _companyName!.isEmpty) {
      await _getUserInfo();
      if (!mounted) return;
      if (_userName == null || _userId == null || _companyLat == null || _companyLong == null || _companyName == null || _companyName!.isEmpty) {
        _showAlertDialog("Informasi pengguna atau perusahaan tidak lengkap atau tidak valid. Silakan hubungi admin.");
        return;
      }
    }

    if (_currentPosition == null) {
      if (mounted) {
        _showAlertDialog("Menunggu pembaruan lokasi. Pastikan GPS aktif dan coba lagi.");
      }
      await _getCurrentLocation();
      if (!mounted) return;
      if (_currentPosition == null) {
        _showAlertDialog("Gagal mendapatkan lokasi. Pastikan GPS aktif dan koneksi baik.");
        return;
      }
    }

    print("Lokasi saat ini digunakan: Latitude = ${_currentPosition!.latitude}, Longitude = ${_currentPosition!.longitude}");
    print("Koordinat perusahaan: Latitude = $_companyLat, Longitude = $_companyLong");

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
      double distanceInMeters = Geolocator.distanceBetween(
        _companyLat!,
        _companyLong!,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      print("Jarak antara lokasi perusahaan dan pengguna: $distanceInMeters meters");
      bool isClockInApproved = distanceInMeters <= (_companyRadius ?? 250);

      print("Apakah Clock In Disetujui? $isClockInApproved");

      if (!isClockInApproved) {
        if (mounted) {
          _showAlertDialog("Anda berada di luar radius yang diizinkan untuk Clock In (maksimum ${_companyRadius ?? 250} meter). Jarak saat ini: $distanceInMeters meter.");
        }
        return;
      }

      if (nowDateTime.isAfter(startDateTime)) {
        if (mounted) {
          _showLateReasonDialog(isClockInApproved);
        }
      } else {
        await _processClockIn(isClockInApproved);
      }
    } else {
      if (mounted) {
        _showAlertDialog("Anda harus melakukan Clock Out terlebih dahulu.");
      }
    }
  }

  Future<void> _processClockIn(bool isClockInApproved) async {
    await _showLoadingDialog();

    if (_companyName == null || _companyName!.isEmpty) {
      await _getUserCompanyName();
      if (_companyName == null || _companyName!.isEmpty) {
        Navigator.of(context, rootNavigator: true).pop();
        _showAlertDialog("Nama perusahaan tidak valid. Silakan hubungi admin.");
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

    String imageUrl = await _uploadImage(_image!);

    if (!mounted) return;

    setState(() {
      _clockStatus = 'Clock In';
      _clockInTime = DateTime.now();
      _lateDuration = Duration.zero; // Reset _lateDuration
      if (nowDateTime.isAfter(startDateTime)) {
        _lateDuration = nowDateTime.difference(startDateTime);
      }
    });

    DocumentReference userDocRef = _firestore.collection('users').doc(_userId);
    DocumentReference docRef = await userDocRef.collection('clockin_records').add({
      'user_name': _userName,
      'user_id': _userId,
      'Company Name': _companyName ?? 'Unknown',
      'clockin_location': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
      'timestamp': Timestamp.now(),
      'clock_in_time': _clockInTime,
      'is_late': nowDateTime.isAfter(startDateTime),
      'late_duration': _formattedDuration(_lateDuration),
      'late_reason': _lateReason,
      'image_url': imageUrl,
      'clock_status': _clockStatus,
      'approved': isClockInApproved,
      'date': DateFormat('yyyy-MM-dd').format(_clockInTime!),
    });

    if (!mounted) return;

    setState(() {
      _currentRecordId = docRef.id;
    });

    Navigator.of(context, rootNavigator: true).pop();
    _showSuccessDialog("Clock in sukses");
  }

  Future<void> _performClockOut() async {
    final clockOutDateTime = DateTime.now();

    await _showLoadingDialog();

    if (_currentPosition == null) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showAlertDialog("Lokasi tidak tersedia. Pastikan GPS aktif.");
      }
      return;
    }

    double distanceInMeters = Geolocator.distanceBetween(
        _companyLat ?? 0, _companyLong ?? 0, _currentPosition!.latitude, _currentPosition!.longitude);
    bool isClockOutApproved = distanceInMeters <= (_companyRadius ?? 250);

    if (!isClockOutApproved) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showAlertDialog("Anda berada di luar radius yang diizinkan untuk Clock Out.");
      }
      return;
    }

    String imageUrl = await _uploadImage(_image!);

    if (!mounted) return;

    if (_clockInTime != null) {
      _workingHours = clockOutDateTime.difference(_clockInTime!);
    }

    DateTime designatedEndDateTime = DateTime(
      clockOutDateTime.year,
      clockOutDateTime.month,
      clockOutDateTime.day,
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
      'approved': isClockOutApproved,
      'clock_out_image_url': imageUrl,
      'clock_status': 'Clock Out',
      'working_hours': _formattedDuration(_workingHours),
      'early_leave_duration': _formattedDuration(earlyLeaveDuration),
    });

    if (!mounted) return;

    setState(() {
      _clockStatus = 'Clock Out';
    });
    Navigator.of(context, rootNavigator: true).pop();
    String successMessage = "Clock out sukses";
    if (earlyLeaveDuration > Duration.zero) {
      successMessage += "\nAnda pulang lebih awal selama: ${_formattedDuration(earlyLeaveDuration)}";
    }
    _showSuccessDialog(successMessage);
  }

  Future<void> _showLoadingDialog() async {
    if (!mounted) return;
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
    if (!mounted) return;
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          double dialogWidth = constraints.maxWidth < 500 ? constraints.maxWidth * 0.92 : 400;
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  minWidth: 280,
                  maxWidth: 400,
                  minHeight: 0,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade400, Colors.teal.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 48),
                                SizedBox(height: 10),
                                Text(
                                  "Keterangan Terlambat",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              children: [
                                Text(
                                  "Anda terlambat. Silakan isi alasan keterlambatan di bawah ini.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 15, color: Colors.teal.shade900),
                                ),
                                SizedBox(height: 14),
                                TextField(
                                  controller: reasonController,
                                  maxLines: 2,
                                  style: TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    labelText: 'Alasan Keterlambatan',
                                    labelStyle: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                                    filled: true,
                                    fillColor: Colors.teal.shade50,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.teal.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.teal.shade700, width: 2),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.teal.shade200),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Text('Batal', style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (reasonController.text.isNotEmpty) {
                                            if (mounted) {
                                              setState(() {
                                                _lateReason = reasonController.text;
                                              });
                                              Navigator.of(context).pop();
                                              _processClockIn(isClockInApproved);
                                            }
                                          } else {
                                            _showAlertDialog("Alasan keterlambatan wajib diisi.");
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade700,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          elevation: 2,
                                        ),
                                        child: Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
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
          );
        },
      ),
    );
  }

  void _showAlertDialog(String message) {
    if (!mounted) return;
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
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                              if (mounted) {
                                setState(() {});
                              }
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
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ClockHistoryPage(userId: _userId)),
      );
    }
  }

  void _navigateToUserPage() {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => UserPage()),
      );
    }
  }

  Future<void> _fetchUserAccess() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(user.uid).get();
        if (!mounted) return;
        if (userSnapshot.exists) {
          if (mounted) {
            setState(() {
              _userData = userSnapshot.data() as Map<String, dynamic>?;
              _userAccess = _userData?['access'] ?? [];
              _isLoadingUserAccess = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoadingUserAccess = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingUserAccess = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserAccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserAccess) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Absensi'),
          centerTitle: true,
          leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _navigateToUserPage),
          backgroundColor: Colors.teal.shade700,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_userAccess.contains('clock')) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Absensi'),
          centerTitle: true,
          leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _navigateToUserPage),
          backgroundColor: Colors.teal.shade700,
        ),
        body: NoAccessWidget(featureName: 'Clock In/Out'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Absensi'),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _navigateToUserPage),
        backgroundColor: Colors.teal.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
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
                      backgroundColor: (_clockStatus == 'Clock In') ? Colors.grey : Colors.teal.shade700,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      textStyle: TextStyle(fontSize: 16),
                      foregroundColor: Colors.white,
                      minimumSize: Size(150, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.teal.shade700),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (_clockStatus == 'Clock Out') ? null : _pickImageForClockOut,
                    child: Text('Clock Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_clockStatus == 'Clock Out') ? Colors.grey : Colors.teal.shade700,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      textStyle: TextStyle(fontSize: 16),
                      foregroundColor: Colors.white,
                      minimumSize: Size(150, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.teal.shade700),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ListTile(
                title: Text(
                  'Lihat Riwayat Clock In/Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                ),
                trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.teal.shade700),
                onTap: _navigateToHistoryPage,
              ),
              Divider(thickness: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class NoAccessWidget extends StatelessWidget {
  final String featureName;

  const NoAccessWidget({required this.featureName, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Akses Ditolak',
            style: TextStyle(
              fontSize: 20,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda tidak memiliki akses ke fitur $featureName.',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}