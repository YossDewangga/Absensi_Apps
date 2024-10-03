import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_absensi.dart';
import 'admin_activity.dart';
import 'admin_break.dart';
import 'admin_cuti.dart';
import 'History Karyawan/karyawan_list_page.dart';
import 'admin_visit.dart';
import 'setting_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const AdminAbsensiPage(), // Halaman Absensi tetap ada
    const KaryawanListPage(),
    AdminLeavePage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      _showAbsensiOptions(context); // Menampilkan bottom sheet untuk Absensi
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
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
    // Add your listeners here if needed
  }

  @override
  Widget build(BuildContext context) {
    // Menggunakan MediaQuery untuk mendapatkan ukuran layar
    var screenSize = MediaQuery.of(context).size;
    bool isWideScreen = screenSize.width > 600; // Menentukan jika layar lebih lebar (seperti di web)

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation
        return false;
      },
      child: Scaffold(
        body: Center(
          child: isWideScreen
              ? Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (int index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.access_time),
                    label: Text('Absensi'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people),
                    label: Text('Karyawan'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.beach_access),
                    label: Text('Cuti'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings),
                    label: Text('Pengaturan'),
                  ),
                ],
                selectedLabelTextStyle: TextStyle(
                  color: Colors.blue,
                ),
                unselectedLabelTextStyle: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: _pages[_selectedIndex],
              ),
            ],
          )
              : _pages[_selectedIndex], // Tetap menggunakan layout biasa untuk layar kecil (mobile)
        ),
        bottomNavigationBar: isWideScreen
            ? null // Tidak menggunakan bottom navigation di layar lebar (web)
            : BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              label: 'Absensi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Karyawan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.beach_access), // Icon for Cuti
              label: 'Cuti',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Pengaturan',
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
