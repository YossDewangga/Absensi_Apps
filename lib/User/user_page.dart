import 'package:absensi_apps/Company%20Super%20Admin/setting_page.dart';
import 'package:absensi_apps/Salary/user_salary.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:absensi_apps/Cuti/leave_page.dart';
import '../Clock In & Clock Out/clock_in_out.dart';
import '../Visit In & Out/visit.dart';

class UserPage extends StatefulWidget {
  UserPage({Key? key}) : super(key: key);

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(); // 01:43 PM WIB, Monday, June 23, 2025
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
    List<String> nameParts = displayName.split(' ');
    String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    String formattedName = '$firstName $lastName'.trim();
    String userId = user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 5,
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(top: 60, left: 20, right: 30, bottom: 20),
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
                    color: Colors.white70,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.person, size: 32, color: Colors.white),
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
        ),
        toolbarHeight: 130,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/image 1.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.05),
              colorBlendMode: BlendMode.darken,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.7),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 30), // Menurunkan teks dengan ruang tambahan
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Text(
                        'Selamat datang, pilih opsi di bawah ini untuk memulai!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          int crossAxisCount = 2;
                          if (kIsWeb && constraints.maxWidth > 600) {
                            crossAxisCount = 3;
                          }
                          double availableHeight = MediaQuery.of(context).size.height - 130 - 30; // App bar (130) + padding (20 dari SizedBox + 10 dari SingleChildScrollView)
                          int itemCount = 4;
                          double itemHeight = availableHeight / ((itemCount / crossAxisCount).ceil() + 1);
                          double aspectRatio = constraints.maxWidth / (crossAxisCount * itemHeight);

                          return LimitedBox(
                            maxHeight: availableHeight,
                            child: GridView.count(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              childAspectRatio: aspectRatio.clamp(1.0, 2.0),
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
                                  icon: Icons.work,
                                  label: 'Visit',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => VisitInAndOutPage()),
                                    );
                                  },
                                ),
                                _buildCard(
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
                                _buildCard(
                                  context: context,
                                  icon: Icons.account_balance_wallet,
                                  label: 'Slip Gaji',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => UserInfoSalary(
                                          userId: userId,
                                          displayName: formattedName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          borderRadius: BorderRadius.circular(15.0),
        ),
        elevation: 6,
        color: Colors.white.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.teal.shade700,
              ),
              SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.teal.shade900,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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