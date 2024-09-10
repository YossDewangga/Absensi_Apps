import 'package:absensi_apps/Logbook/daily_activity.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:absensi_apps/Admin/setting_page.dart';
import 'package:absensi_apps/Break/start_&_end_break.dart';
import 'package:absensi_apps/Cuti/leave_page.dart';
import '../Clock In & Clock Out/clock_in_out.dart';
import '../Visit In & Out/visit.dart';
import 'dart:ui';

class UserPage extends StatefulWidget {
  UserPage({Key? key}) : super(key: key);

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final user = FirebaseAuth.instance.currentUser;

    String greeting = '';
    if (now.hour < 12) {
      greeting = 'Good Morning,';
    } else if (now.hour < 17) {
      greeting = 'Good Afternoon,';
    } else {
      greeting = 'Good Evening,';
    }

    String displayName = user?.displayName ?? 'User';
    List<String> nameParts = displayName.split('');
    String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join('') : '';
    String formattedName = '$firstName$lastName';

    return Scaffold(
      body: Stack(
        children: [
          // Gambar sebagai latar belakang utama
          Positioned.fill(
            child: Image.asset(
              'assets/images/image 1.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.1),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.only(top: 60, left: 20, right: 30, bottom: 0), // Ubah left dan right
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(30),
                          ),
                          color: Colors.teal.shade700.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 5,
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                wordSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formattedName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.person, size: 30, color: Colors.white),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ProfilePage()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              children: [
                                _buildCard(
                                  context: context,
                                  icon: Icons.access_time,
                                  label: 'Absensi',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ClockPage()),
                                    );
                                  },
                                ),
                                _buildCard(
                                  context: context,
                                  icon: Icons.book,
                                  label: 'Daily Activity',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => LogbookPage()),
                                    );
                                  },
                                ),
                                _buildCard(
                                  context: context,
                                  icon: Icons.free_breakfast,
                                  label: 'Break',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => BreakStartEndPage()),
                                    );
                                  },
                                ),
                                _buildCard(
                                  context: context,
                                  icon: Icons.work,
                                  label: 'Visit',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => VisitInAndOutPage()),
                                    );
                                  },
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 170, // Atur lebar sesuai kebutuhan
                                  height: 170, // Atur tinggi sesuai kebutuhan
                                  child: _buildCard(
                                    context: context,
                                    icon: Icons.airplane_ticket,
                                    label: 'Cuti',
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => LeaveApplicationPage()),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20), // Tambahkan jarak kosong di bagian bawah
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        elevation: 3,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: Colors.teal.shade700, // Warna ikon
              ),
              SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: Colors.teal.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
