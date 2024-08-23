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
          Positioned(
            top: 300,
            left: -155,
            child: Image.asset(
              'assets/images/Tridaya.png',
              width: 700,
              height: 400,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.6),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(top: 70, left: 15, right: 30, bottom: 15),
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
                          _buildManualGlassCard(
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
                          _buildManualGlassCard(
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
                          _buildManualGlassCard(
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
                          _buildManualGlassCard(
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
                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment.center,
                        child: _buildManualGlassCard(
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualGlassCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 150, // Samakan tinggi dengan card lainnya
        width: 150, // Samakan lebar dengan card lainnya
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Stack(
            children: [
              // Efek blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Atur tingkat blur
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1), // Atur tingkat transparansi
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1), // Warna border
                      ),
                    ),
                  ),
                ),
              ),
              Center(
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
            ],
          ),
        ),
      ),
    );
  }
}
