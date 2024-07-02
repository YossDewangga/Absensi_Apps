// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:absensi_apps/Login_Register/login_or_register_page.dart';
//
// class AuthPage extends StatelessWidget {
//   const AuthPage({Key? key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: StreamBuilder<User?>(
//         stream: FirebaseAuth.instance.authStateChanges(),
//         builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Text('Error: ${snapshot.error}');
//           } else {
//             final user = snapshot.data;
//             if (user != null) {
//               return FutureBuilder<DocumentSnapshot>(
//                 future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
//                 builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   } else if (snapshot.hasError) {
//                     return Text('Error loading user data: ${snapshot.error}');
//                   } else {
//                     final userData = snapshot.data;
//                     if (userData != null && userData.exists) {
//                       final role = userData['role'];
//                       if (role != null) {
//                         if (role == 'Admin') {
//                           // Navigate to AdminPage if user is an admin
//                           return const Placeholder(); // Replace with your AdminPage widget
//                         } else if (role == 'Karyawan') {
//                           // Navigate to UserPage if user is a user
//                           return const Placeholder(); // Replace with your UserPage widget
//                         } else {
//                           // Navigate to UnknownRolePage if user has an unknown role
//                           return const Placeholder(); // Replace with your UnknownRolePage widget
//                         }
//                       } else {
//                         // User doesn't have a role yet, stay on registration page
//                         return const LoginOrRegisterPage();
//                       }
//                     } else {
//                       // Data for user doesn't exist, stay on registration page
//                       return const LoginOrRegisterPage();
//                     }
//                   }
//                 },
//               );
//             } else {
//               // User is not logged in, stay on registration page
//               return const LoginOrRegisterPage();
//             }
//           }
//         },
//       ),
//     );
//   }
// }
