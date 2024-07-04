import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_absensi.dart';
import 'admin_break.dart';
import 'admin_cuti.dart';
import 'admin_overtime.dart';
import 'karyawan_list_page.dart';
import 'admin_visit.dart';
import 'setting_page.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  bool _hasNewLogbookEntry = false;

  static final List<Widget> _pages = <Widget>[
    const AdminAbsensiPage(),
    AdminOvertimePage(),
    AdminVisitPage(),
    AdminBreakPage(), // Tambahkan halaman AdminBreakPage
    const KaryawanListPage(),
    const SettingsPage(), // Gunakan halaman pengaturan yang baru
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        // Reset the notification indicator when the logbook page is selected
        _hasNewLogbookEntry = false;
      }
    });
  }

  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _pages.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.access_time),
                if (_hasNewLogbookEntry)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Absensi',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.access_alarm), // Ikon untuk Overtime
            label: 'Overtime', // Label untuk Overtime
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Visit',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.coffee), // Ikon untuk Break
            label: 'Break', // Label untuk Break
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Karyawan',
          ),
          const BottomNavigationBarItem(
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
    );
  }
}
