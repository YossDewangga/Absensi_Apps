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
  Position? _visitInPosition;
  String? _userId;
  DateTime? _visitInTime;
  String _visitInDateTime = 'Unknown';
  String _nextDestination = '';
  String _visitStatus = 'Not Visited';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _checkPermission();
    _getUserInfo();
  }

  Future<void> _checkPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        // Permission granted, no further action needed
      } else {
        _showSnackBar('Location permission is required to access GPS.');
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _getUserInfo() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
      await _loadVisitStatus();
    } else {
      _showSnackBar('User not logged in.');
    }
  }

  Future<void> _loadVisitStatus() async {
    if (_userId != null) {
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
      DocumentSnapshot snapshot = await userDocRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        setState(() {
          _visitStatus = snapshot['visit_status'] ?? 'Not Visited';
          _visitInCompleted = _visitStatus == 'Visit In';
          _visitOutCompleted = _visitStatus == 'Visit Out';
        });

        if (_visitInCompleted) {
          await _loadVisitInDetails();
        }
      }
    }
  }

  Future<void> _loadVisitInDetails() async {
    if (_userId != null && _visitStatus == 'Visit In') {
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
      QuerySnapshot visitSnapshots = await userDocRef.collection('visits').orderBy('visit_in_time', descending: true).limit(1).get();
      if (visitSnapshots.docs.isNotEmpty) {
        DocumentSnapshot visitSnapshot = visitSnapshots.docs.first;
        setState(() {
          _visitInDocumentId = visitSnapshot.id;
          _visitInLocation = visitSnapshot['visit_in_location'];
          _visitInAddress = visitSnapshot['visit_in_address'];
          _visitInTime = (visitSnapshot['visit_in_time'] as Timestamp).toDate();
          _updateVisitInDateTime();

          List<String> locationParts = _visitInLocation.split(',');
          _visitInPosition = Position(
            latitude: double.parse(locationParts[0]),
            longitude: double.parse(locationParts[1]),
            timestamp: DateTime.now(), // Set a valid timestamp
            altitude: 0.0,
            accuracy: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0, headingAccuracy: 0.0,
          );
        });
      }
    }
  }

  Future<void> _updateVisitStatus(String status) async {
    if (_userId != null) {
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
      await userDocRef.set({'visit_status': status}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Visit In/Out'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildHeader(),
              SizedBox(height: 20),
              _buildButtons(),
              Divider(thickness: 1),
              ListTile(
                title: Text(
                  'Lihat Log Kunjungan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.blue),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VisitHistoryPage(userId: _userId)),
                  );
                },
              ),
              Divider(thickness: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        SizedBox(height: 10),
        Center(
          child: Text(
            'Please use the buttons below to record your visit in and out times.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20),
        Divider(thickness: 2),
        Center(
          child: Text(
            'Current Status: $_visitStatus',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
        ),
        Divider(thickness: 2),
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
              onPressed: _visitInCompleted ? null : _visitIn,
              icon: Icon(Icons.login),
              label: Text('Visit In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _visitInCompleted ? Colors.grey : Colors.blue,
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
      ],
    );
  }

  Future<void> _visitIn() async {
    await _takePicture(true);
    await _getCurrentPosition(true);

    if (_visitInImage != null && _visitInPosition != null) {
      setState(() {
        _visitInTime = DateTime.now();
        _updateVisitInDateTime();
      });

      try {
        String downloadUrl = await _uploadImageToStorage(_visitInImage!, 'visit_in_images');
        String documentId = await _saveVisitInToFirestore(downloadUrl);

        setState(() {
          _visitInCompleted = true;
          _visitInDocumentId = documentId;
        });

        await _updateVisitStatus('Visit In');
        _showDialog('Visit In Completed');
      } catch (e) {
        _showDialog('Failed to submit: $e');
      }
    } else {
      _showDialog('Failed to take picture or get location.');
    }
  }

  Future<void> _visitOut() async {
    await _takePicture(false);
    await _getCurrentPosition(false);

    if (_visitOutImage != null && _visitInPosition != null) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distanceInMeters = Geolocator.distanceBetween(
        _visitInPosition!.latitude, _visitInPosition!.longitude,
        position.latitude, position.longitude,
      );

      if (distanceInMeters > 50) {
        _showDialog('Visit Out gagal: Anda berada lebih dari 50 meter dari lokasi Visit In.');
        return;
      }

      setState(() {
        _visitOutTime = DateTime.now();
        _updateVisitOutDateTime();
      });

      await _showNextDestinationDialog();

      if (_nextDestination.isEmpty) {
        _showDialog('Tujuan Selanjutnya harus diisi.');
        return;
      }

      try {
        String downloadUrl = await _uploadImageToStorage(_visitOutImage!, 'visit_out_images');
        await _saveVisitOutToFirestore(downloadUrl);

        setState(() {
          _visitOutCompleted = true;
        });

        await _updateVisitStatus('Visit Out');
        _showDialog('Visit Out Completed');
      } catch (e) {
        _showDialog('Failed to submit: $e');
      }
    } else {
      _showDialog('Failed to take picture or get location.');
    }
  }

  Future<void> _showNextDestinationDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tujuan Selanjutnya'),
        content: TextField(
          onChanged: (value) {
            setState(() {
              _nextDestination = value;
            });
          },
          decoration: InputDecoration(hintText: "Masukkan tujuan selanjutnya"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_nextDestination.isEmpty) {
                _showDialog('Tujuan Selanjutnya harus diisi.');
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
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
    }
  }

  Future<void> _getCurrentPosition(bool isVisitIn) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark placemark = placemarks.first;

      if (isVisitIn) {
        setState(() {
          _visitInPosition = position;
          _visitInLocation = '${position.latitude}, ${position.longitude}';
          _visitInAddress = '${placemark.street}, ${placemark.subLocality}, ${placemark.locality}, ${placemark.subAdministrativeArea}';
        });
      } else {
        setState(() {
          _visitOutLocation = '${position.latitude}, ${position.longitude}';
          _visitOutAddress = '${placemark.street}, ${placemark.subLocality}, ${placemark.locality}, ${placemark.subAdministrativeArea}';
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      _showDialog('Error getting location: $e');
    }
  }

  void _updateVisitInDateTime() {
    final DateFormat formatter = DateFormat.yMMMMd('id_ID').add_jm();
    setState(() {
      _visitInDateTime = formatter.format(_visitInTime!);
    });
  }

  void _updateVisitOutDateTime() {
    final DateFormat formatter = DateFormat.yMMMMd('id_ID').add_jm();
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

  Future<String> _saveVisitInToFirestore(String downloadUrl) async {
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    DocumentReference visitDocRef = await userDocRef.collection('visits').add({
      'visit_in_time': _visitInTime,
      'visit_in_location': _visitInLocation,
      'visit_in_address': _visitInAddress,
      'visit_in_imageUrl': downloadUrl,
    });

    return visitDocRef.id;
  }

  Future<void> _saveVisitOutToFirestore(String downloadUrl) async {
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    DocumentReference visitDocRef = userDocRef.collection('visits').doc(_visitInDocumentId);

    await visitDocRef.update({
      'visit_out_time': _visitOutTime,
      'visit_out_location': _visitOutLocation,
      'visit_out_address': _visitOutAddress,
      'visit_out_imageUrl': downloadUrl,
      'next_destination': _nextDestination,
    });
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notification'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showImageDialog(BuildContext context, File imageFile) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(imageFile),
              SizedBox(height: 8.0),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          ),
        ),
      ),
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
