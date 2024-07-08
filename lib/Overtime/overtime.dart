import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'history_overtime_page.dart';

class OvertimePage extends StatefulWidget {
  const OvertimePage({Key? key}) : super(key: key);

  @override
  _OvertimePageState createState() => _OvertimePageState();
}

class _OvertimePageState extends State<OvertimePage> {
  String _overtimeStatus = 'Overtime Out';
  DateTime? _overtimeInTime;
  Position? _currentPosition;
  bool _isOvertimeInDisabled = false;
  bool _isOvertimeOutDisabled = true;
  String _overtimeInTimeStr = '';
  String _overtimeOutTimeStr = '';
  String _totalOvertimeStr = '';
  String? _currentRecordId;
  User? _currentUser;
  File? _image;

  final double _officeLat = -6.12333;
  final double _officeLong = 106.79869;

  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _getCurrentUser();
    _loadOvertimeStatus();
  }

  void _getCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageReference = _storage.ref().child("overtime_images/$fileName");
      UploadTask uploadTask = storageReference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      throw e;
    }
  }

  void _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _showAlertDialog("Aplikasi membutuhkan izin lokasi untuk berfungsi.");
    }
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
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

  Future<void> _loadOvertimeStatus() async {
    if (_currentUser != null) {
      DocumentReference userDocRef = _firestore.collection('users').doc(_currentUser!.uid);
      QuerySnapshot snapshot = await userDocRef.collection('overtime_records')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var latestRecord = snapshot.docs.first;
        var data = latestRecord.data() as Map<String, dynamic>;

        if (data['overtime_status'] == 'Overtime In') {
          setState(() {
            _overtimeStatus = 'Overtime In';
            _overtimeInTime = (data['overtime_in_time'] as Timestamp).toDate();
            _overtimeInTimeStr = _formattedDateTime(_overtimeInTime!);
            _isOvertimeInDisabled = true;
            _isOvertimeOutDisabled = false;
            _currentRecordId = latestRecord.id;
          });
        }
      }
    }
  }

  Future<void> _overtimeIn() async {
    if (_currentUser != null && _currentPosition != null) {
      double distanceInMeters = Geolocator.distanceBetween(
          _officeLat, _officeLong, _currentPosition!.latitude, _currentPosition!.longitude);

      if (distanceInMeters <= 100) {
        await _pickImage();
        if (_image != null) {
          String imageUrl = await _uploadImage(_image!);
          String userName = _currentUser!.displayName ?? 'User';
          DocumentReference userDocRef = _firestore.collection('users').doc(_currentUser!.uid);
          DocumentReference docRef = await userDocRef.collection('overtime_records').add({
            'user_name': userName,
            'overtime_location': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
            'timestamp': Timestamp.now(),
            'overtime_status': 'Overtime In',
            'overtime_in_time': DateTime.now(),
            'overtime_in_image_url': imageUrl, // Simpan URL gambar Overtime In
          });

          setState(() {
            _overtimeStatus = 'Overtime In';
            _overtimeInTime = DateTime.now();
            _overtimeInTimeStr = _formattedDateTime(_overtimeInTime!);
            _isOvertimeInDisabled = true;
            _isOvertimeOutDisabled = false;
            _currentRecordId = docRef.id;
          });

          print("Overtime in recorded successfully.");
        } else {
          _showAlertDialog("Anda harus mengambil foto untuk Overtime In.");
        }
      } else {
        _showAlertDialog("Anda berada diluar jangkauan lokasi kantor.");
      }
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _overtimeOut() async {
    if (_currentUser != null && _currentRecordId != null && _currentPosition != null) {
      double distanceInMeters = Geolocator.distanceBetween(
          _officeLat, _officeLong, _currentPosition!.latitude, _currentPosition!.longitude);

      if (distanceInMeters <= 100) {
        await _pickImage();
        if (_image != null) {
          DateTime overtimeOutTime = DateTime.now();
          Duration totalOvertime = overtimeOutTime.difference(_overtimeInTime!);
          String imageUrl = await _uploadImage(_image!);

          DocumentReference userDocRef = _firestore.collection('users').doc(_currentUser!.uid);
          await userDocRef.collection('overtime_records').doc(_currentRecordId).update({
            'overtime_out_location': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
            'timestamp': Timestamp.now(),
            'overtime_status': 'Overtime Out',
            'overtime_out_time': DateTime.now(),
            'total_overtime': totalOvertime.inSeconds,
            'overtime_out_image_url': imageUrl, // Simpan URL gambar Overtime Out
          });

          setState(() {
            _overtimeStatus = 'Overtime Out';
            _overtimeOutTimeStr = _formattedDateTime(overtimeOutTime);
            _totalOvertimeStr = _formattedDuration(totalOvertime);
            _isOvertimeInDisabled = false;
            _isOvertimeOutDisabled = true;
          });

          _showSuccessDialog("Overtime Out berhasil!");
        } else {
          _showAlertDialog("Anda harus mengambil foto untuk Overtime Out.");
        }
      } else {
        _showAlertDialog("Anda berada diluar jangkauan lokasi kantor.");
      }
    } else {
      _getCurrentLocation();
    }
  }

  void _showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text("Peringatan"),
            ],
          ),
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text("Sukses"),
            ],
          ),
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
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}:"
        "${dateTime.second.toString().padLeft(2, '0')}";
  }

  String _formattedDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildLogBox(String title, String content, double width, double height, double textSize, double contentTextSize) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 0.0),
            child: Divider(thickness: 1),
          ),
          Expanded(
            child: Center(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: contentTextSize,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Overtime In/Out"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Status: $_overtimeStatus',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: _isOvertimeInDisabled ? null : _overtimeIn,
                      child: Text('Overtime In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        textStyle: TextStyle(fontSize: 16),
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isOvertimeOutDisabled ? null : _overtimeOut,
                      child: Text('Overtime Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        textStyle: TextStyle(fontSize: 16),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                SizedBox(height: 15),
                Divider(thickness: 1),
                ListTile(
                  title: Text(
                    'Lihat Log Pencatatan Overtime',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.blue),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HistoryOvertimePage()),
                    );
                  },
                ),
                Divider(thickness: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
