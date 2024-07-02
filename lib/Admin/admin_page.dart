import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_absensi.dart';
import 'admin_cuti.dart';
import 'admin_overtime.dart';
import 'karyawan_list_page.dart';
import 'admin_visit.dart';

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
    const KaryawanListPage(),
    AdminVisitPage(),
    AdminLeavePage(),
    AdminOvertimePage(),
    const Center(child: Text('Pengaturan Page', style: TextStyle(fontSize: 20))),
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
                Icon(Icons.access_time),
                if (_hasNewLogbookEntry)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
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
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Karyawan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Visit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.beach_access), // Ikon untuk cuti
            label: 'Cuti', // Label untuk cuti
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_alarm), // Ikon untuk Overtime
            label: 'Overtime', // Label untuk Overtime
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
    );
  }
}
