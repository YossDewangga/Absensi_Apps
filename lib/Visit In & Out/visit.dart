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
  bool _approvalRequested = false;
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
  String? _displayName;

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
        // Izin diberikan, tidak ada tindakan lebih lanjut yang diperlukan
      } else {
        _showSnackBar('Izin lokasi diperlukan untuk mengakses GPS.');
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
      _approvalRequested = prefs.getBool('approval_requested') ?? false;
      _visitInDocumentId = prefs.getString('visit_in_document_id') ?? '';
      _visitInDateTime = prefs.getString('visit_in_date_time') ?? 'Unknown';
      _visitOutDateTime = prefs.getString('visit_out_date_time') ?? 'Unknown';
      _visitInLocation = prefs.getString('visit_in_location') ?? 'Unknown';
      _visitInAddress = prefs.getString('visit_in_address') ?? 'Unknown';
      _visitOutLocation = prefs.getString('visit_out_location') ?? 'Unknown';
      _visitOutAddress = prefs.getString('visit_out_address') ?? 'Unknown';
      if (_visitStatus == 'Visit In' && _visitInCompleted) {
        _loadVisitInDetails();
      }
      _checkVisitOutApproval(); // Check approval status and handle accordingly
    });
  }

  Future<void> _checkVisitOutApproval() async {
    if (_userId != null && _visitInDocumentId.isNotEmpty) {
      DocumentReference visitDocRef = FirebaseFirestore.instance.collection('users').doc(_userId).collection('visits').doc(_visitInDocumentId);
      DocumentSnapshot visitSnapshot = await visitDocRef.get();
      if (visitSnapshot.exists) {
        bool isApproved = visitSnapshot['visit_out_isApproved'] ?? false;
        if (isApproved) {
          setState(() {
            _visitInCompleted = false;
            _visitOutCompleted = true;
            _visitStatus = 'Not Visited'; // Reset status
          });
          await _saveVisitStatus();
          _showSnackBar('Visit Out approved, you can now check-in again.');
        }
      }
    }
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
          _visitStatus = 'Visit In';
          _visitOutCompleted = false;
        });

        await _saveVisitStatus();

        _showDialog('Visit In Completed');
      } catch (e) {
        _showDialog('Gagal mengirim: $e');
      }
    } else {
      _showDialog('Gagal mengambil gambar atau mendapatkan lokasi.');
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
      'approval_requested': false,
      'visit_out_isApproved': false,
    });

    return visitDocRef.id;
  }

  Future<void> _saveVisitStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('visit_status', _visitStatus);
    prefs.setBool('visit_in_completed', _visitInCompleted);
    prefs.setBool('visit_out_completed', _visitOutCompleted);
    prefs.setBool('approval_requested', _approvalRequested);
    prefs.setString('visit_in_document_id', _visitInDocumentId);
    prefs.setString('visit_in_date_time', _visitInDateTime);
    prefs.setString('visit_out_date_time', _visitOutDateTime);
    prefs.setString('visit_in_location', _visitInLocation);
    prefs.setString('visit_in_address', _visitInAddress);
    prefs.setString('visit_out_location', _visitOutLocation);
    prefs.setString('visit_out_address', _visitOutAddress);
  }

  Future<void> _requestApproval() async {
    if (_userId != null && _visitInDocumentId.isNotEmpty) {
      DocumentReference visitDocRef = FirebaseFirestore.instance.collection('users').doc(_userId).collection('visits').doc(_visitInDocumentId);
      await visitDocRef.update({
        'approval_requested': true,
      });
      setState(() {
        _approvalRequested = true;
      });

      await _saveVisitStatus();

      _showDialog('Permintaan persetujuan telah dikirim ke admin.');
    } else {
      _showDialog('Gagal mengirim permintaan persetujuan.');
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
          _visitStatus = 'Visit Out';
          _visitInCompleted = false;
        });

        await _saveVisitStatus();

        _showDialog('Visit Out Completed');
      } catch (e) {
        _showDialog('Gagal mengirim: $e');
      }
    } else {
      _showDialog('Gagal mengambil gambar atau mendapatkan lokasi.');
    }
  }

  Future<void> _saveVisitOutToFirestore(String downloadUrl) async {
    DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId);
    DocumentReference visitDocRef = userDocRef.collection('visits').doc(_visitInDocumentId);

    try {
      if (_visitOutTime != null && _visitOutLocation.isNotEmpty && _visitOutAddress.isNotEmpty && downloadUrl.isNotEmpty && _nextDestination.isNotEmpty) {
        await visitDocRef.update({
          'visit_out_time': _visitOutTime,
          'visit_out_location': _visitOutLocation,
          'visit_out_address': _visitOutAddress,
          'visit_out_imageUrl': downloadUrl,
          'next_destination': _nextDestination,
          'visit_status': 'Visit Out',
          'approval_requested': true,
        });

        print('Data updated successfully');
      } else {
        print('One or more fields are null or empty');
      }
    } catch (e) {
      print('Error updating document: $e');
      _showDialog('Error updating document: $e');
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
        print('Visit Out Location: $_visitOutLocation');
        print('Visit Out Address: $_visitOutAddress');
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

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pemberitahuan'),
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
                child: Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
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
            'Silakan gunakan tombol di bawah untuk mencatat waktu kunjungan masuk dan keluar Anda.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 20),
        Divider(thickness: 2),
        Center(
          child: Text(
            'Status Saat Ini: $_visitStatus',
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
              onPressed: _visitInCompleted && !_visitOutCompleted ? null : _visitIn,
              icon: Icon(Icons.login),
              label: Text('Visit In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _visitInCompleted && !_visitOutCompleted ? Colors.grey : Colors.blue,
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
        _visitInCompleted && !_visitOutCompleted ? _buildRequestApprovalButton() : Container(),
      ],
    );
  }

  Widget _buildRequestApprovalButton() {
    return ElevatedButton.icon(
      onPressed: _requestApproval,
      icon: Icon(Icons.admin_panel_settings),
      label: Text('Minta Persetujuan Admin'),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        textStyle: TextStyle(fontSize: 16),
        foregroundColor: Colors.white,
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
