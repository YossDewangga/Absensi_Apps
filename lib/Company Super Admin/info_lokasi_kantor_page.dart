import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoLokasiKantorPage extends StatefulWidget {
  final String companyName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? radius;
  final String? jamMasuk;
  final String? jamPulang;
  final Function(String, double, double, String?, String?)? onSaveLocation;

  const InfoLokasiKantorPage({
    Key? key,
    required this.companyName,
    this.address,
    this.latitude,
    this.longitude,
    this.radius,
    this.jamMasuk,
    this.jamPulang,
    this.onSaveLocation,
  }) : super(key: key);

  @override
  State<InfoLokasiKantorPage> createState() => _InfoLokasiKantorPageState();
}

class _InfoLokasiKantorPageState extends State<InfoLokasiKantorPage> {
  String? address;
  double? latitude;
  double? longitude;
  double? radius;
  String? jamMasuk;
  String? jamPulang;
  bool _isLoading = false;
  bool _noData = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
    _checkAdminRole(); // Memeriksa peran admin saat inisialisasi
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final idTokenResult = await user.getIdTokenResult();
      final isAdmin = idTokenResult.claims?['admin'] == true;
      final isSuperAdmin = idTokenResult.claims?['company_super_admin'] == true;
      print("User UID: ${user.uid}, Is Admin: $isAdmin, Is Company Super Admin: $isSuperAdmin");
    }
  }

  Future<void> _fetchCompanyData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyName)
          .get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          address = data['address'];
          latitude = (data['latitude'] as num?)?.toDouble();
          longitude = (data['longitude'] as num?)?.toDouble();
          radius = (data['radius'] as num?)?.toDouble();
          jamMasuk = (data['designatedStartTime'] != null)
              ? _formatTime(data['designatedStartTime'])
              : null;
          jamPulang = (data['designatedEndTime'] != null)
              ? _formatTime(data['designatedEndTime'])
              : null;
          _isLoading = false;
          _noData = false;
        });
      } else {
        setState(() {
          address = "Alamat belum diset";
          latitude = 0.0;
          longitude = 0.0;
          radius = 100.0;
          jamMasuk = "08:00";
          jamPulang = "17:00";
          _isLoading = false;
          _noData = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data untuk ${widget.companyName} tidak ditemukan. Silakan atur lokasi.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data perusahaan: $e')),
      );
    }
  }

  String _formatTime(dynamic timestamp) {
    final dt = (timestamp as Timestamp).toDate();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _ambilLokasiBaru() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Izin lokasi diperlukan.")),
        );
        return;
      }
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String newAddress = "Alamat tidak ditemukan";
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        newAddress =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
      }
      setState(() => _isLoading = false);

      print("New location data: Address=$newAddress, Lat=${pos.latitude}, Long=${pos.longitude}");

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Icon(Icons.location_on, color: Colors.teal.shade900, size: 44),
              ),
              const SizedBox(height: 14),
              Text(
                "Konfirmasi Alamat Baru",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.teal.shade900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Text(
                  newAddress,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade900,
                    fontSize: 15.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map, color: Colors.teal.shade400, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "Lat: ",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                  Text(
                    pos.latitude.toStringAsFixed(6),
                    style: TextStyle(color: Colors.teal.shade900),
                  ),
                  const SizedBox(width: 18),
                  Icon(Icons.map, color: Colors.teal.shade400, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    "Long: ",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                  ),
                  Text(
                    pos.longitude.toStringAsFixed(6),
                    style: TextStyle(color: Colors.teal.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  "Lihat lokasi di Google Maps",
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                if (newAddress.isEmpty || newAddress == "Alamat tidak ditemukan") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alamat tidak boleh kosong!')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (confirm == true && widget.onSaveLocation != null) {
        final idTokenResult = await user?.getIdTokenResult();
        final isAdmin = idTokenResult?.claims?['admin'] == true;
        final isSuperAdmin = idTokenResult?.claims?['company_super_admin'] == true;
        if (!isAdmin && !isSuperAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hanya admin atau company super admin yang dapat menyimpan lokasi.")),
          );
          return;
        }
        print("Attempting to save location: address=$newAddress, lat=${pos.latitude}, long=${pos.longitude}, jamMasuk=$jamMasuk, jamPulang=$jamPulang");
        widget.onSaveLocation!(
          newAddress,
          pos.latitude,
          pos.longitude,
          jamMasuk,
          jamPulang,
        );
        setState(() {
          address = newAddress;
          latitude = pos.latitude;
          longitude = pos.longitude;
          _noData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lokasi berhasil diperbarui!")),
        );
      } else {
        setState(() => _isLoading = false);
        if (widget.onSaveLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Callback penyimpanan tidak didefinisikan.")),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error in _ambilLokasiBaru: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal menyimpan lokasi: $e")),
      );
    }
  }

  Future<void> _updateRadius(double newRadius) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idTokenResult = await user?.getIdTokenResult();
      final isAdmin = idTokenResult?.claims?['admin'] == true;
      final isSuperAdmin = idTokenResult?.claims?['company_super_admin'] == true;
      if (!isAdmin && !isSuperAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hanya admin atau company super admin yang dapat memperbarui radius.")),
        );
        return;
      }
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyName)
          .set({'radius': newRadius}, SetOptions(merge: true));
      setState(() {
        radius = newRadius;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Radius berhasil diperbarui!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memperbarui radius: $e")),
      );
    }
  }

  Future<void> _updateJamMasukPulang(TimeOfDay jamMasuk, TimeOfDay jamPulang) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idTokenResult = await user?.getIdTokenResult();
      final isAdmin = idTokenResult?.claims?['admin'] == true;
      final isSuperAdmin = idTokenResult?.claims?['company_super_admin'] == true;
      if (!isAdmin && !isSuperAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hanya admin atau company super admin yang dapat memperbarui jam.")),
        );
        return;
      }
      final masuk = DateTime(2000, 1, 1, jamMasuk.hour, jamMasuk.minute);
      final pulang = DateTime(2000, 1, 1, jamPulang.hour, jamPulang.minute);
      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyName)
          .set({
        'designatedStartTime': Timestamp.fromDate(masuk),
        'designatedEndTime': Timestamp.fromDate(pulang),
      }, SetOptions(merge: true));
      setState(() {
        this.jamMasuk = "${jamMasuk.hour.toString().padLeft(2, '0')}:${jamMasuk.minute.toString().padLeft(2, '0')}";
        this.jamPulang = "${jamPulang.hour.toString().padLeft(2, '0')}:${jamPulang.minute.toString().padLeft(2, '0')}";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Jam masuk dan pulang berhasil diperbarui!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memperbarui jam masuk dan pulang: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Info Lokasi Kantor',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade900,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Center(
                child: Container(
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
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Info Lokasi Kantor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.teal.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Divider(color: Colors.teal.shade100, thickness: 1.3),
              const SizedBox(height: 18),

              // Section alamat + koordinat
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
                          Row(
                            children: [
                              Text('Alamat:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal.shade900)),
                              const Spacer(),
                              if (address != null && address!.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: Colors.teal.shade700, size: 20),
                                  tooltip: "Ambil Lokasi Baru",
                                  onPressed: _isLoading ? null : _ambilLokasiBaru,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address ?? "--",
                            style: TextStyle(color: Colors.teal.shade900, fontSize: 15),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.map, color: Colors.teal.shade400, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Lat: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade900),
                              ),
                              Text(
                                latitude?.toStringAsFixed(6) ?? "--",
                                style: TextStyle(color: Colors.teal.shade900),
                              ),
                              const SizedBox(width: 18),
                              Icon(Icons.map, color: Colors.teal.shade400, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Long: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade900),
                              ),
                              Text(
                                longitude?.toStringAsFixed(6) ?? "--",
                                style: TextStyle(color: Colors.teal.shade900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Radius
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.straighten, color: Colors.teal.shade400, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Radius: ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    Text(
                      radius != null ? "$radius meter" : "--",
                      style: TextStyle(color: Colors.teal.shade900),
                    ),
                    const Spacer(),
                    if (radius != null)
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.teal.shade700, size: 20),
                        tooltip: "Edit Radius",
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final newRadius = await showDialog<double>(
                                  context: context,
                                  builder: (context) {
                                    final controller =
                                        TextEditingController(text: radius?.toString() ?? "");
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
                                      title: Column(
                                        children: [
                                          Icon(Icons.straighten,
                                              color: Colors.teal.shade700, size: 40),
                                          const SizedBox(height: 10),
                                          Text(
                                            "Edit Radius Absensi",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal.shade900,
                                              fontSize: 18,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Masukkan radius absensi dalam satuan meter.",
                                            style: TextStyle(
                                                color: Colors.grey[700], fontSize: 14),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 18),
                                          TextField(
                                            controller: controller,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              prefixIcon: Icon(Icons.straighten,
                                                  color: Colors.teal.shade400),
                                              hintText: "Contoh: 100",
                                              suffixText: "meter",
                                              border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12)),
                                              contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 14),
                                            ),
                                            style: const TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Batal"),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.save,
                                              color: Colors.white, size: 20),
                                          onPressed: () async {
                                            final value = double.tryParse(controller.text);
                                            if (value != null && value > 0) {
                                              Navigator.pop(context, value);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                    content:
                                                        Text("Masukkan nilai radius yang valid.")),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.teal.shade900,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                          ),
                                          label: const Text("Simpan",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (newRadius != null) {
                                  await _updateRadius(newRadius);
                                }
                              },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Jam Masuk & Pulang
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
                        Icon(Icons.access_time, color: Colors.teal.shade400, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Jam Masuk: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        Text(
                          jamMasuk ?? "--",
                          style: TextStyle(color: Colors.teal.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_filled,
                            color: Colors.teal.shade400, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Jam Pulang: ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                        ),
                        Text(
                          jamPulang ?? "--",
                          style: TextStyle(color: Colors.teal.shade900),
                        ),
                        const Spacer(),
                        if (jamMasuk != null && jamPulang != null)
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.teal.shade700, size: 20),
                            tooltip: "Edit Jam Masuk & Pulang",
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    TimeOfDay? newMasuk = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                      helpText: "Pilih Jam Masuk",
                                    );
                                    if (newMasuk != null && mounted) {
                                      TimeOfDay? newPulang = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                        helpText: "Pilih Jam Pulang",
                                      );
                                      if (newPulang != null) {
                                        await _updateJamMasukPulang(newMasuk, newPulang);
                                      }
                                    }
                                  },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_noData)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(
                    child: Text(
                      "Data perusahaan belum diatur. Gunakan tombol 'Ambil Lokasi Baru' untuk mengatur.",
                      style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}