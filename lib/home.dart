import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _userName;
  List<CallLogEntry> _callLogs = [];
  Map<String, String> _foundNumbersData = {};
  Set<String> _fetchingNumbers = Set();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchCallLogs();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName');
    });
  }

  Future<void> _fetchCallLogs() async {
    if (await Permission.contacts.request().isGranted &&
        await Permission.phone.request().isGranted) {
      try {
        Iterable<CallLogEntry> entries = await CallLog.get();

        // Take the first 50 call logs or less if there are fewer than 50
        _callLogs = entries.take(50).toList();

        // Fetch user names for unknown callers within these 50 call logs
        await _fetchUnknownCallerNames(_callLogs);
      } catch (e) {
        print('Failed to fetch call logs: $e');
        // Handle error fetching call logs
      }
    } else {
      print('Permissions not granted');
      // Handle permission not granted
    }
  }

  Future<void> _fetchUnknownCallerNames(List<CallLogEntry> entries) async {
    List<String> unknownNumbers = entries
        .where((entry) => entry.name == null || entry.name == '')
        .map((entry) => _cleanPhoneNumber(entry.number ?? ''))
        .toList();

    for (String number in unknownNumbers) {
      if (number.isNotEmpty && !_foundNumbersData.containsKey(number)) {
        _fetchingNumbers.add(number); // Track numbers being fetched
        await _getUserByPhone(number);
        _fetchingNumbers.remove(number); // Remove from fetching set
      }
    }
  }

  String _cleanPhoneNumber(String phoneNumber) {
    // Remove leading '+' and '91' from the phone number
    phoneNumber = phoneNumber.replaceAll(RegExp(r'^\+91'), ''); // Remove '+91'
    return phoneNumber.replaceAll(RegExp(r'\D'), ''); // Remove non-numeric characters
  }

  Future<void> _getUserByPhone(String phoneNumber) async {
    final cleanedPhoneNumber = _cleanPhoneNumber(phoneNumber);
    final url = 'https://truecaller-api-tbyb.onrender.com/api/getUserByPhone';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'phone': cleanedPhoneNumber}),
      );

      if (response.statusCode == 200) {
        // Check if response body is not empty
        if (response.body.isNotEmpty) {
          dynamic userData = jsonDecode(response.body);
          String? callerName = userData['name'];
          if (callerName != null) {
            setState(() {
              _foundNumbersData[cleanedPhoneNumber] = callerName;
            });
            return; // Exit function if successful
          }
        } else {
          print('No data found for phone number: $cleanedPhoneNumber');
          // Set name to 'Unknown' if no data found
          setState(() {
            _foundNumbersData[cleanedPhoneNumber] = 'Unknown';
          });
        }
      } else {
        print('Failed to fetch user data - HTTP ${response.statusCode}');
        // Set name to 'Unknown' on error
        setState(() {
          _foundNumbersData[cleanedPhoneNumber] = 'Unknown';
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      // Set name to 'Unknown' on error
      setState(() {
        _foundNumbersData[cleanedPhoneNumber] = 'Unknown';
      });
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored data
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Truecaller',
          style: TextStyle(color: Colors.white, fontFamily: 'popins'),
        ),
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 0.0), // Top padding only
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome,',
              style: TextStyle(fontFamily: 'popins', fontSize: 24.0),
            ),
            Text(
              _userName ?? '',
              style: TextStyle(
                fontFamily: 'popins',
                fontSize: 26.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Recent Calls:',
              style: TextStyle(fontFamily: 'popins', fontSize: 20.0),
            ),
            SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent, // Set a transparent color
                ),
                child: ListView.builder(
                  itemCount: _callLogs.length,
                  itemBuilder: (context, index) {
                    CallLogEntry entry = _callLogs[index];
                    String callerName = entry.name ?? 'Unknown';
                    String formattedNumber = _cleanPhoneNumber(entry.number ?? '');
                    String displayName = _foundNumbersData[formattedNumber] ?? callerName;

                    // Determine if the number is found in backend data and is not 'Unknown'
                    bool isFoundAndNotUnknown = _foundNumbersData.containsKey(formattedNumber) && _foundNumbersData[formattedNumber] != 'Unknown';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0), // Bottom padding for each item
                      child: Material(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0), // Adjust border radius as needed
                        ),
                        color: isFoundAndNotUnknown ? Colors.blue.shade50 : Colors.transparent,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0), // Adjust border radius as needed
                          ),
                          leading: Icon(Icons.phone),
                          title: Text(displayName),
                          subtitle: Text(
                            '${entry.number} - ${_getCallType(entry.callType)}',
                          ),
                          trailing: _fetchingNumbers.contains(formattedNumber) ? CircularProgressIndicator() : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCallType(CallType? type) {
    if (type == null) {
      return 'Unknown';
    }

    switch (type) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.blocked:
        return 'Blocked';
      case CallType.voiceMail:
        return 'Voicemail';
      default:
        return 'Unknown';
    }
  }
}
