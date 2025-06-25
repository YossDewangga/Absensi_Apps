import 'package:absensi_apps/Admin/admin_list_gaji.dart';
import 'package:absensi_apps/Company%20Super%20Admin/salary_karyawan.dart';
import 'package:absensi_apps/Admin/History%20Karyawan/karyawan_list_page.dart';
import 'package:absensi_apps/Company%20Super%20Admin/admin_absensi.dart';
import 'package:absensi_apps/Admin/admin_activity.dart';
import 'package:absensi_apps/Admin/admin_break.dart';
import 'package:absensi_apps/Company%20Super%20Admin/admin_cuti.dart';
import 'package:absensi_apps/Company%20Super%20Admin/admin_visit.dart';
import 'package:absensi_apps/Company%20Super%20Admin/setting_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


class CompanySuperAdmin extends StatefulWidget {
  const CompanySuperAdmin({super.key});

  @override
  _CompanySuperAdminState createState() => _CompanySuperAdminState();
}

class _CompanySuperAdminState extends State<CompanySuperAdmin> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const AdminAbsensiPage(),
    const AdminApprovalPage(),
    const KaryawanListPage(),
    AdminLeavePage(),
    const ListGajiKaryawanPage(), // Halaman gaji
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  void _showAbsensiOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Absensi'),
              onTap: () {
                Navigator.pop(context); // Tutup bottom sheet
                setState(() {
                  _selectedIndex = 0; // Pilih halaman Absensi Utama
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Visit'),
              onTap: () {
                Navigator.pop(context); // Tutup bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminApprovalPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_alarm),
              title: const Text('Activity'),
              onTap: () {
                Navigator.pop(context); // Tutup bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminActivityPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.coffee),
              title: const Text('Break'),
              onTap: () {
                Navigator.pop(context); // Tutup bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminBreakPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _listenForNewLogs();
  }

  void _listenForNewLogs() {
    // Tambahkan listener di sini jika diperlukan
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Mencegah navigasi kembali
        return false;
      },
      child: Scaffold(
        body: Center(
          child: _pages[_selectedIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              label: 'Absensi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.car_rental),
              label: 'Visit',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Karyawan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.beach_access),
              label: 'Cuti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: 'Gaji',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Setting',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}