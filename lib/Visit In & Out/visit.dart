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
  String _clockInDocumentId = ''; // Untuk menyimpan ID dokumen clock in
  Position? _visitInPosition;
  String? _userId;
  DateTime? _visitInTime;
  String _visitInDateTime = 'Unknown';
  String _nextDestination = '';
  String _visitStatus = 'Not Visited';
  String? _displayName;
  String _selectedOption = 'Pulang'; // Set default to 'Pulang'
  bool _isOtherOptionSelected = false; // Variabel untuk mengatur opsi "Lainnya"

  TimeOfDay? _designatedStartTime;
  TimeOfDay? _designatedEndTime;  // Menyimpan designatedEndTime
  Duration _lateDuration = Duration.zero;
  Duration _earlyLeaveDuration = Duration.zero;  // Durasi early leave

  final double _radius = 500; // Ubah radius menjadi 500 meter
  bool isLoading = false;
  bool _isOutsideDesignatedArea = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _checkPermission();
    _getUserInfo();
    _getDesignatedTimes();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        // Izin diberikan, tidak ada tindakan lebih lanjut yang diperlukan
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
        Timestamp endTimestamp = startSnapshot['designatedEndTime'];  // Ambil designatedEndTime dari Firestore
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
      await _loadVisitStatus();
    } else {
      _showSnackBar('Pengguna belum masuk.');
    }
  }

  Future<void> _loadVisitStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _visitStatus = prefs.getString('visit_status') ?? 'Not Visited';
      _visitInCompleted = prefs.getBool('visit_in_completed') ?? false;
      _visitOutCompleted = prefs.getBool('visit_out_completed') ?? false;
      _visitInDocumentId = prefs.getString('visit_in_document_id') ?? '';
      _clockInDocumentId = prefs.getString('clock_in_document_id') ?? ''; // Load clock in document ID
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
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    DocumentReference visitDocRef = await userDocRef.collection('visits').add({
      'visit_in_time': _visitInTime,
      'visit_in_location': _visitInLocation,
      'visit_in_address': _visitInAddress,
      'visit_in_imageUrl': downloadUrl,
      'visit_status': 'Visit In',
      'displayName': _displayName,
      'approved': false,
      'destination_company': _nextDestination, // Simpan nama perusahaan
    });

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
          'visit_out_imageUrl': downloadUrl, // Save image URL to visit_out_imageUrl
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
      print('Error updating document');
      _showAlertDialog('Error updating document');
    }
  }

  Future<void> _showNextDestinationDialog() async {
    TimeOfDay now = TimeOfDay.now();
    TimeOfDay startTime1 = TimeOfDay(hour: 0, minute: 0);
    TimeOfDay endTime1 = TimeOfDay(hour: 15, minute: 34);
    TimeOfDay startTime2 = TimeOfDay(hour: 15, minute: 35);
    TimeOfDay endTime2 = TimeOfDay(hour: 23, minute: 59);

    bool withinFirstRange = _isTimeWithinRange(now, startTime1, endTime1);
    bool withinSecondRange = _isTimeWithinRange(now, startTime2, endTime2);

    if (withinSecondRange) {
      return showDialog(
        context: context,
        barrierDismissible: false, // Prevent dialog from closing when clicking outside
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Masukkan Tujuan Selanjutnya !', style: TextStyle(color: Colors.teal.shade900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('Pulang', style: TextStyle(color: Colors.teal.shade900)),
                  value: 'Pulang',
                  groupValue: _selectedOption,
                  onChanged: (value) {
                    setState(() {
                      _selectedOption = value!;
                      _isOtherOptionSelected = false;
                      _nextDestination = 'Pulang'; // Set default value to 'Pulang'
                    });
                  },
                  activeColor: Colors.teal.shade700,
                ),
                RadioListTile<String>(
                  title: Text('Lainnya', style: TextStyle(color: Colors.teal.shade900)),
                  value: 'Lainnya',
                  groupValue: _selectedOption,
                  onChanged: (value) {
                    setState(() {
                      _selectedOption = value!;
                      _isOtherOptionSelected = true;
                    });
                  },
                  activeColor: Colors.teal.shade700,
                ),
                if (_isOtherOptionSelected)
                  TextField(
                    onChanged: (value) {
                      _nextDestination = value;
                    },
                    decoration: InputDecoration(hintText: "Pilih tujuan selanjutnya !", hintStyle: TextStyle(color: Colors.teal.shade700)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (_selectedOption == 'Lainnya' && _nextDestination.isEmpty) {
                    _showAlertDialog('Tujuan Selanjutnya harus diisi.');
                  } else {
                    Navigator.of(context).pop();
                    await _submitNextDestination();
                    if (_selectedOption == 'Pulang') {
                      await _showClockOutConfirmationDialog();
                    } else {
                      await _completeVisitOut();
                    }
                  }
                },
                child: Text('Submit', style: TextStyle(color: Colors.teal.shade700)),
              ),
            ],
          ),
        ),
      );
    } else if (withinFirstRange) {
      return showDialog(
        context: context,
        barrierDismissible: false, // Prevent dialog from closing when clicking outside
        builder: (context) => AlertDialog(
          title: Text('Tujuan Selanjutnya ?', style: TextStyle(color: Colors.teal.shade900)),
          content: TextField(
            onChanged: (value) {
              setState(() {
                _nextDestination = value;
              });
            },
            decoration: InputDecoration(hintText: "Masukkan tujuan selanjutnya", hintStyle: TextStyle(color: Colors.teal.shade700)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (_nextDestination.isEmpty) {
                  _showAlertDialog('Tujuan Selanjutnya harus diisi.');
                } else {
                  Navigator.of(context).pop();
                  await _submitNextDestination();
                  await _saveVisitOutToFirestore(await _uploadImageToStorage(_visitOutImage!, 'visit_out_images'), true);
                  _showSuccessDialog('Visit Out sukses.');
                }
              },
              child: Text('Submit', style: TextStyle(color: Colors.teal.shade700)),
            ),
          ],
        ),
      );
    } else {
      _showAlertDialog('Waktu tidak valid untuk memasukkan tujuan selanjutnya.');
    }
  }

  Future<void> _submitNextDestination() async {
    // Simulate data update
    await Future.delayed(Duration(seconds: 2));
  }

  Future<void> _completeVisitOut() async {
    _showSuccessDialog('Visit Out sukses.');
  }

  Future<void> _showClockOutConfirmationDialog() async {
    bool confirmed = await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dialog from closing when clicking outside
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Clock Out', style: TextStyle(color: Colors.teal.shade900)),
        content: Text('Visit Out akan dijadikan Clock Out juga.', style: TextStyle(color: Colors.teal.shade900)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text('Ya', style: TextStyle(color: Colors.teal.shade700)),
          ),
        ],
      ),
    );

    if (confirmed) {
      await _autoClockOut();
      _showSuccessDialog('Visit Out dan Clock Out sukses.');
    }
  }

  bool _isTimeWithinRange(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
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

        // Cek apakah sudah ada clock in hari ini
        QuerySnapshot clockInSnapshot = await userDocRef.collection('clockin_records')
            .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(nowDateTime))
            .where('clock_status', isEqualTo: 'Clock In')
            .get();

        if (clockInSnapshot.docs.isEmpty) {
          DocumentReference clockInDocRef = userDocRef.collection('clockin_records').doc();
          await clockInDocRef.set({
            'user_name': user.displayName,
            'user_id': user.uid,
            'clockin_location': GeoPoint(visitInPosition.latitude, visitInPosition.longitude),
            'timestamp': Timestamp.now(),
            'clock_in_time': visitInTime,
            'is_late': nowDateTime.isAfter(startDateTime),
            'late_duration': _formattedDuration(_lateDuration),
            'image_url': visitInImageUrl,
            'clock_status': 'Clock In',
            'approved': false, // Set approved to false for all clock in from visit
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
    if (user != null) {
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      try {
        Position currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

        double distanceInMeters = Geolocator.distanceBetween(
          double.parse(_visitOutLocation.split(',')[0].trim()),
          double.parse(_visitOutLocation.split(',')[1].trim()),
          currentPosition.latitude,
          currentPosition.longitude,
        );

        bool isClockOutApproved = distanceInMeters <= _radius;

        String visitOutImageUrl = await _uploadImageToStorage(_visitOutImage!, 'visit_out_images');

        // Calculate total working hours
        Duration WorkingHours = _visitOutTime!.difference(_visitInTime!);
        String WorkingHoursStr = _formattedDuration(WorkingHours);

        // Calculate early leave duration
        if (_designatedEndTime != null) {
          final DateTime nowDateTime = _visitOutTime!;
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

        DocumentReference clockOutDocRef = userDocRef.collection('clockin_records').doc(_clockInDocumentId);
        await clockOutDocRef.update({
          'clockout_location': GeoPoint(currentPosition.latitude, currentPosition.longitude),
          'timestamp': Timestamp.now(),
          'clock_out_time': _visitOutTime,
          'approved': false, // Set approved to false for all clock out from visit
          'clock_status': 'Clock Out',
          'clock_out_image_url': visitOutImageUrl, // Save visit out image URL
          'working_hours': WorkingHoursStr, // Save total working hours
          if (_earlyLeaveDuration > Duration.zero)
            'early_leave_duration': _formattedDuration(_earlyLeaveDuration), // Save early leave duration
        });

        print("Clock out berhasil berdasarkan visit out.");
        if (!isClockOutApproved) {
          setState(() {
            _isOutsideDesignatedArea = true;
          });
        }
      } catch (e) {
        print('Error getting location');
        _showAlertDialog('Error getting location');
      }
    }
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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark placemark = placemarks.first;

      String fullAddress = '${placemark.name ?? ''}, '
          '${placemark.street ?? ''}, '
          '${placemark.subLocality ?? ''}, '
          '${placemark.locality ?? ''}, '
          '${placemark.administrativeArea ?? ''}';

      if (isVisitIn) {
        setState(() {
          _visitInPosition = position;
          _visitInLocation = '${position.latitude}, ${position.longitude}';
          _visitInAddress = fullAddress; // Menyimpan alamat lengkap termasuk nama gedung
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      _showAlertDialog('Error getting location');
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
      barrierDismissible: false, // Prevent dialog from closing when clicking outside
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
      barrierDismissible: false, // Prevent dialog from closing when clicking outside
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Sukses', style: TextStyle(color: Colors.teal.shade900)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.teal.shade900)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_isOutsideDesignatedArea) {
                _showOutsideDesignatedAreaDialog();
              }
              setState(() {
                isLoading = false;
              });
            },
            child: Text('OK', style: TextStyle(color: Colors.teal.shade700)),
          ),
        ],
      ),
    );
  }

  void _showOutsideDesignatedAreaDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dialog from closing when clicking outside
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
                style: TextStyle(color: Colors.white)
            )
        )
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
        // Setelah mengambil gambar, tampilkan dialog untuk memasukkan nama perusahaan
        await _showCompanyNameDialog(); // Menambahkan dialog

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
        _showAlertDialog('Gagal mengirim');
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
      _nextDestination = "Pulang";  // Set default value for next destination to "Pulang"
    });

    await _getCurrentPosition(false);

    if (_visitOutImage != null && _visitInPosition != null) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distanceInMeters = Geolocator.distanceBetween(
        _visitInPosition!.latitude,
        _visitInPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      bool isApproved = distanceInMeters <= _radius;

      setState(() {
        _visitOutTime = DateTime.now();
        _updateVisitOutDateTime();
      });

      await _showNextDestinationDialog();
      try {
        String downloadUrl = await _uploadImageToStorage(_visitOutImage!, 'visit_out_images');
        await _saveVisitOutToFirestore(downloadUrl, isApproved);
        setState(() {
          _visitOutCompleted = true;
          _visitStatus = 'Visit Out';
          _visitInCompleted = false;
          _isOutsideDesignatedArea = !isApproved;
        });

        await _saveVisitStatus();
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        _showAlertDialog('Gagal mengirim');
      }
    } else {
      setState(() {
        isLoading = false;
      });
      _showAlertDialog('Gagal mendapatkan lokasi.');
    }
  }

  Future<void> _showCompanyNameDialog() async {
    String companyName = '';
    return showDialog(
      context: context,
      barrierDismissible: false, // Prevent dialog from closing when clicking outside
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: Center( // Center the title
            child: Text(
              'Masukkan Nama Perusahaan Yang Sedang Dikunjungi',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.teal.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 15),
              TextField(
                onChanged: (value) {
                  companyName = value;
                },
                decoration: InputDecoration(
                  labelText: "Nama Perusahaan",
                  labelStyle: TextStyle(color: Colors.teal.shade700),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal.shade700, width: 2.0),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center( // Center the button
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () {
                    if (companyName.isEmpty) {
                      _showAlertDialog('Nama Perusahaan harus diisi.');
                    } else {
                      Navigator.of(context).pop();
                      setState(() {
                        _nextDestination = companyName; // Simpan nama perusahaan ke _nextDestination
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                    child: Text(
                      'Submit',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
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
