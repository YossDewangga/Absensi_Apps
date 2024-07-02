// import 'package:flutter/material.dart';
// import 'package:absensi_apps/Login_Register/login_page.dart';
// import 'package:absensi_apps/Login_Register/register_page.dart';
//
// class LoginOrRegisterPage extends StatefulWidget {
//   const LoginOrRegisterPage({Key? key});
//
//   @override
//   State<LoginOrRegisterPage> createState() => _LoginOrRegisterPageState();
// }
//
// class _LoginOrRegisterPageState extends State<LoginOrRegisterPage> {
//   bool showLoginPage = true;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(),
//       body: showLoginPage
//           ? LoginPage(
//         onTap: togglePages,
//       )
//           : RegisterPage(
//         onTap: togglePages,
//       ),
//     );
//   }
//
//   void togglePages() {
//     setState(() {
//       showLoginPage = !showLoginPage;
//     });
//   }
// }