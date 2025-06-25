import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Pastikan intl diimpor untuk NumberFormat

class EditSalaryPage extends StatefulWidget {
  final String userId;
  final String displayName;
  final Map<String, dynamic>? initialSalaryData; // Parameter opsional untuk data awal

  const EditSalaryPage({
    super.key,
    required this.userId,
    required this.displayName,
    this.initialSalaryData, // Bisa null jika tidak ada data awal
  });

  @override
  State<EditSalaryPage> createState() => _EditSalaryPageState();
}

class _EditSalaryPageState extends State<EditSalaryPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _gajiPokokController = TextEditingController();
  final TextEditingController _gajiHarianController = TextEditingController();
  final TextEditingController _potonganTelatController = TextEditingController();
  final TextEditingController _potonganAbsentController = TextEditingController();
  final TextEditingController _potonganCutiController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupListeners(); // Menambahkan listener untuk formatting real-time
    _initializeControllers();
  }

  void _setupListeners() {
    // Listener untuk memformat input secara real-time
    _gajiPokokController.addListener(_formatNumber(_gajiPokokController));
    _gajiHarianController.addListener(_formatNumber(_gajiHarianController));
    _potonganTelatController.addListener(_formatNumber(_potonganTelatController));
    _potonganAbsentController.addListener(_formatNumber(_potonganAbsentController));
    _potonganCutiController.addListener(_formatNumber(_potonganCutiController));
  }

  // Fungsi untuk memformat angka dengan titik
  void Function() _formatNumber(TextEditingController controller) {
    return () {
      if (controller.text.isNotEmpty) {
        final cleanText = controller.text.replaceAll('.', ''); // Hapus titik sebelum parsing
        final number = int.tryParse(cleanText) ?? 0;
        final formatted = NumberFormat.decimalPattern('id').format(number);
        if (controller.text != formatted) {
          controller.value = controller.value.copyWith(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      }
    };
  }

  void _initializeControllers() {
    // Gunakan initialSalaryData jika tersedia, jika tidak, ambil dari Firestore
    if (widget.initialSalaryData != null) {
      _gajiPokokController.text = NumberFormat.decimalPattern('id').format(widget.initialSalaryData!['gaji_pokok'] ?? 0);
      _gajiHarianController.text = NumberFormat.decimalPattern('id').format(widget.initialSalaryData!['gaji_harian'] ?? 0);
      _potonganTelatController.text = NumberFormat.decimalPattern('id').format(widget.initialSalaryData!['potongan_telat_per_hari'] ?? 0);
      _potonganAbsentController.text = NumberFormat.decimalPattern('id').format(widget.initialSalaryData!['potongan_tidak_masuk'] ?? 0);
      _potonganCutiController.text = NumberFormat.decimalPattern('id').format(widget.initialSalaryData!['potongan_cuti'] ?? 0);
      setState(() {
        _isLoading = false;
      });
    } else {
      _loadSalaryData();
    }
  }

  Future<void> _loadSalaryData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('salary')
          .doc('current')
          .get();
      final data = doc.data();
      if (data != null) {
        _gajiPokokController.text = NumberFormat.decimalPattern('id').format(data['gaji_pokok'] ?? 0);
        _gajiHarianController.text = NumberFormat.decimalPattern('id').format(data['gaji_harian'] ?? 0);
        _potonganTelatController.text = NumberFormat.decimalPattern('id').format(data['potongan_telat_per_hari'] ?? 0);
        _potonganAbsentController.text = NumberFormat.decimalPattern('id').format(data['potongan_tidak_masuk'] ?? 0);
        _potonganCutiController.text = NumberFormat.decimalPattern('id').format(data['potongan_cuti'] ?? 0);
      }
      print('Loaded salary data: $data');
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading salary data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data gaji: $e')),
      );
    }
  }

  Future<void> _saveSalary() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Hapus titik sebelum menyimpan ke Firestore
        final gajiPokok = int.tryParse(_gajiPokokController.text.replaceAll('.', '')) ?? 0;
        final gajiHarian = int.tryParse(_gajiHarianController.text.replaceAll('.', '')) ?? 0;
        final potonganTelat = int.tryParse(_potonganTelatController.text.replaceAll('.', '')) ?? 0;
        final potonganAbsent = int.tryParse(_potonganAbsentController.text.replaceAll('.', '')) ?? 0;
        final potonganCuti = int.tryParse(_potonganCutiController.text.replaceAll('.', '')) ?? 0;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('salary')
            .doc('current')
            .set({
          'gaji_pokok': gajiPokok,
          'gaji_harian': gajiHarian,
          'potongan_telat_per_hari': potonganTelat,
          'potongan_tidak_masuk': potonganAbsent,
          'potongan_cuti': potonganCuti,
        }, SetOptions(merge: true));
        print('Saved salary data: $gajiPokok, $gajiHarian, $potonganTelat, $potonganAbsent, $potonganCuti');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Data gaji berhasil disimpan')),
          );
          Navigator.pop(context, true); // Kembali dengan indikator perubahan
        }
      } catch (e) {
        print('Error saving salary data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data gaji: $e')),
        );
      }
    }
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    required String label,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.teal.shade700),
      labelText: label,
      labelStyle: TextStyle(color: Colors.teal.shade900, fontSize: 16),
      hintStyle: TextStyle(color: Colors.teal.shade400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.teal.shade700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.teal.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.teal.shade900, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal.shade50,
      appBar: AppBar(
        title: Text('Edit Gaji: ${widget.displayName}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal.shade900,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Center(
              child: Card(
                elevation: 8,
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet, size: 48, color: Colors.teal.shade700),
                        const SizedBox(height: 16),
                        Text(
                          widget.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _gajiPokokController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            icon: Icons.monetization_on,
                            label: 'Gaji Pokok (Rp)',
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _gajiHarianController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            icon: Icons.calendar_today,
                            label: 'Gaji Harian (Rp)',
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _potonganTelatController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            icon: Icons.timer_off,
                            label: 'Potongan Telat per Hari (Rp)',
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _potonganAbsentController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            icon: Icons.do_not_disturb_on,
                            label: 'Potongan Tidak Masuk per Hari (Rp)',
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _potonganCutiController,
                          keyboardType: TextInputType.number,
                          decoration: _fieldDecoration(
                            icon: Icons.event_busy,
                            label: 'Potongan Cuti per Hari (Rp)',
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Simpan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade900,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _saveSalary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _gajiPokokController.dispose();
    _gajiHarianController.dispose();
    _potonganTelatController.dispose();
    _potonganAbsentController.dispose();
    _potonganCutiController.dispose();
    super.dispose();
  }
}