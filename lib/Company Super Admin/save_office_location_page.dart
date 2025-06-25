import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // Untuk input formatter angka
import 'info_lokasi_kantor_page.dart'; // Import halaman InfoLokasiKantorPage

class SaveOfficeLocationPage extends StatefulWidget {
  const SaveOfficeLocationPage({Key? key}) : super(key: key);

  @override
  State<SaveOfficeLocationPage> createState() => _SaveOfficeLocationPageState();
}

enum SaveLocationStep { initial, confirmLocation, setRadiusAndTime }

class _SaveOfficeLocationPageState extends State<SaveOfficeLocationPage> {
  SaveLocationStep _step = SaveLocationStep.initial;
  bool _isLoading = false;
  String? _statusMessage;
  String? _address;
  double? _latitude;
  double? _longitude;
  final TextEditingController _radiusController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  int? _startHour;
  int? _startMinute;
  int? _endHour;
  int? _endMinute;

  @override
  void initState() {
    super.initState();
    _radiusController.addListener(() {
      setState(() {}); // Update UI saat radius berubah
    });
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationAndAddress() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _address = null;
    });
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _statusMessage = "Izin lokasi diperlukan.";
          _isLoading = false;
        });
        return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String address = "Alamat tidak ditemukan";
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = address;
        _isLoading = false;
        _step = SaveLocationStep.confirmLocation;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Gagal mendapatkan lokasi/alamat: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay(hour: 8, minute: 0)) : (_endTime ?? TimeOfDay(hour: 17, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveLocation() async {
    if (_latitude == null || _longitude == null || _address == null) {
      setState(() {
        _statusMessage = "Ambil lokasi terlebih dahulu.";
      });
      return;
    }
    if (_radiusController.text.isEmpty) {
      setState(() {
        _statusMessage = "Isi radius terlebih dahulu.";
      });
      return;
    }
    double? radius = double.tryParse(_radiusController.text);
    if (radius == null || radius <= 0) {
      setState(() {
        _statusMessage = "Radius harus berupa angka lebih dari 0.";
      });
      return;
    }
    if (_startTime == null || _endTime == null) {
      setState(() {
        _statusMessage = "Pilih jam masuk dan jam pulang terlebih dahulu.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _statusMessage = "User tidak ditemukan.";
          _isLoading = false;
        });
        return;
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null || userData['role'] != 'Admin') {
        setState(() {
          _statusMessage = "Hanya Admin yang bisa menyimpan lokasi kantor.";
          _isLoading = false;
        });
        return;
      }
      final companyName = userData['Company Name'];
      if (companyName == null || companyName.toString().isEmpty) {
        setState(() {
          _statusMessage = "Company Name tidak ditemukan.";
          _isLoading = false;
        });
        return;
      }
      await FirebaseFirestore.instance.collection('companies').doc(companyName).set({
        'company_name': companyName,
        'latitude': _latitude,
        'longitude': _longitude,
        'radius': radius,
        'address': _address ?? "",
        'designatedStartTime': Timestamp.fromDate(DateTime(2000, 1, 1, _startTime!.hour, _startTime!.minute)),
        'designatedEndTime': Timestamp.fromDate(DateTime(2000, 1, 1, _endTime!.hour, _endTime!.minute)),
      });
      setState(() {
        _statusMessage = "Lokasi kantor berhasil disimpan!";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Gagal menyimpan lokasi: $e";
        _isLoading = false;
      });
    }
  }

  Widget _buildInitialCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade100.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_searching, size: 60, color: Colors.teal.shade900),
          const SizedBox(height: 18),
          Text(
            'Ambil Lokasi Kantor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.teal.shade900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tekan tombol di bawah untuk mengambil lokasi kantor sesuai posisi Anda saat ini.',
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: const Text('Ambil Lokasi Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade900,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 2,
              ),
              onPressed: _isLoading ? null : _getCurrentLocationAndAddress,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmLocationCard() {
    return Center(
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: const EdgeInsets.symmetric(vertical: 28, horizontal: 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon bulat besar di atas
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade100, Colors.teal.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade100.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Icon(Icons.location_on, color: Colors.teal.shade900, size: 48),
              ),
              const SizedBox(height: 18),
              Text(
                'Konfirmasi Lokasi Kantor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Colors.teal.shade900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 22),
              Divider(color: Colors.teal.shade100, thickness: 1.3),
              const SizedBox(height: 18),
              // Alamat
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () async {
                    if (_latitude != null && _longitude != null) {
                      final url = 'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                    child: Text(
                      'klik untuk melihat lokasi di maps',
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.home, color: Colors.teal.shade400, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alamat:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                          const SizedBox(height: 2),
                          Text(
                            _address ?? "--",
                            style: TextStyle(color: Colors.teal.shade900, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // Latitude & Longitude (VERTIKAL agar tidak overflow)
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map, color: Colors.teal.shade400, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Latitude: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        Expanded(
                          child: Text(
                            _latitude?.toStringAsFixed(6) ?? "--",
                            style: TextStyle(color: Colors.teal.shade900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.map, color: Colors.teal.shade400, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Longitude: ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        Expanded(
                          child: Text(
                            _longitude?.toStringAsFixed(6) ?? "--",
                            style: TextStyle(color: Colors.teal.shade900),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back, color: Colors.teal),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.teal.shade900),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setState(() {
                          _step = SaveLocationStep.initial;
                        });
                      },
                      label: Text('Back', style: TextStyle(color: Colors.teal.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        setState(() {
                          _step = SaveLocationStep.setRadiusAndTime;
                        });
                      },
                      label: const Text('Next', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required IconData icon,
    required TimeOfDay? value,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            child: Row(
              children: [
                Icon(icon, color: color ?? Colors.teal.shade700, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: BoxDecoration(
                    color: value != null ? Colors.teal.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    value != null ? value.format(context) : "Pilih",
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, color: Colors.teal.shade300, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jam Masuk',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<int>(
              value: _startHour,
              hint: const Text('Jam'),
              items: List.generate(24, (i) => i)
                  .map((h) => DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))))
                  .toList(),
              onChanged: (val) => setState(() => _startHour = val),
            ),
            const Text(':'),
            DropdownButton<int>(
              value: _startMinute,
              hint: const Text('Menit'),
              items: List.generate(60, (i) => i)
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                  .toList(),
              onChanged: (val) => setState(() => _startMinute = val),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Jam Pulang',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<int>(
              value: _endHour,
              hint: const Text('Jam'),
              items: List.generate(24, (i) => i)
                  .map((h) => DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))))
                  .toList(),
              onChanged: (val) => setState(() => _endHour = val),
            ),
            const Text(':'),
            DropdownButton<int>(
              value: _endMinute,
              hint: const Text('Menit'),
              items: List.generate(60, (i) => i)
                  .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                  .toList(),
              onChanged: (val) => setState(() => _endMinute = val),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildLocationInfo() {
    if (_latitude == null || _longitude == null) {
      return const SizedBox();
    }
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Radius
            Row(
              children: [
                Icon(Icons.circle, color: Colors.teal.shade700),
                const SizedBox(width: 10),
                Text(
                  'Radius Absensi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.straighten, color: Colors.teal.shade400),
                hintText: 'Contoh: 100',
                suffixText: 'meter',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 22),

            // Jam Masuk
            Row(
              children: [
                Icon(Icons.login, color: Colors.teal.shade700),
                const SizedBox(width: 10),
                Text(
                  'Jam Masuk',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                    fontSize: 16,
                  ),
                ),
                if (_startTime != null) ...[
                  const SizedBox(width: 10),
                  Chip(
                    label: Text(_startTime!.format(context),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.teal.shade700,
                  ),
                ]
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickTime(isStart: true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade50,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.teal.shade400),
                    const SizedBox(width: 14),
                    Text(
                      _startTime != null
                          ? "Ubah Jam Masuk"
                          : 'Pilih Jam Masuk',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Jam Pulang
            Row(
              children: [
                Icon(Icons.logout, color: Colors.teal.shade700),
                const SizedBox(width: 10),
                Text(
                  'Jam Pulang',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                    fontSize: 16,
                  ),
                ),
                if (_endTime != null) ...[
                  const SizedBox(width: 10),
                  Chip(
                    label: Text(_endTime!.format(context),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.teal.shade700,
                  ),
                ]
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickTime(isStart: false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.shade200, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade50,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time_filled, color: Colors.teal.shade400),
                    const SizedBox(width: 14),
                    Text(
                      _endTime != null
                          ? "Ubah Jam Pulang"
                          : 'Pilih Jam Pulang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final radiusText = _radiusController.text.trim();
    final isRadiusValid = radiusText.isNotEmpty &&
        double.tryParse(radiusText) != null &&
        double.parse(radiusText) > 0;
    final isTimeValid = _startTime != null && _endTime != null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save, color: Colors.white),
        label: const Text('Simpan Lokasi Kantor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade900,
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 2,
        ),
        onPressed: (_latitude != null && _longitude != null && !_isLoading && isRadiusValid && isTimeValid)
            ? _saveLocation
            : null,
      ),
    );
  }

  void _showSettingDialog() async {
    // Ambil user dan companyName dari Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final companyName = userData?['Company Name'];
    if (companyName == null) return;

    // Navigasi ke InfoLokasiKantorPage dengan companyName
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InfoLokasiKantorPage(companyName: companyName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.teal.shade900,
        title: const Text('Simpan Lokasi Kantor', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false, // <-- ini untuk menghilangkan tombol back
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: "Lihat/Edit Pengaturan",
            onPressed: _showSettingDialog,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_step == SaveLocationStep.initial)
                  _buildInitialCard(),
                if (_step == SaveLocationStep.confirmLocation)
                  _buildConfirmLocationCard(),
                if (_step == SaveLocationStep.setRadiusAndTime && _latitude != null && _longitude != null) ...[
                  _buildLocationInfo(),
                  _buildSaveButton(),
                ],
                if (_isLoading) ...[
                  const SizedBox(height: 18),
                  CircularProgressIndicator(color: Colors.teal.shade900),
                ],
                if (_statusMessage != null && !_statusMessage!.contains('berhasil')) ...[
                  const SizedBox(height: 18),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}