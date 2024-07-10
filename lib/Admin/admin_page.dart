import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  static final List<Widget> _pages = <Widget>[
    const AdminAbsensiPage(),
    const AdminOvertimePage(),
    AdminApprovalPage(),
    const AdminBreakPage(),
    AdminLeavePage(), // Add AdminLeavePage to the list
    const KaryawanListPage(),
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
    return Scaffold(
      body: Center(
        child: _pages.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Absensi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_alarm),
            label: 'Overtime',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Visit',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.coffee),
            label: 'Break',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.beach_access), // Icon for Cuti
            label: 'Cuti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Karyawan',
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
