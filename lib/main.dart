import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:truecaller/home.dart';
import 'package:truecaller/login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkLoginStatus(),
      builder: (context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.data == true) {
            // User is logged in, navigate to HomePage
            return MaterialApp(
              title: 'Truecaller',
              home: HomePage(),
              debugShowCheckedModeBanner: false,
            );
          } else {
            // User is not logged in, navigate to LoginPage
            return MaterialApp(
              title: 'Truecaller',
              home: LoginPage(),
              debugShowCheckedModeBanner: false,
            );
          }
        }
        // Show loading indicator while checking login status
        return MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }

  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? phoneNumber = prefs.getString('userPhoneNumber');
    return phoneNumber != null && phoneNumber.isNotEmpty;
  }
}
