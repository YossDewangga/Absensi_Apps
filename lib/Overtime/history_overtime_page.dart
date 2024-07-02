import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryOvertimePage extends StatelessWidget {
  const HistoryOvertimePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Lembur'),
      ),
      body: FutureBuilder<User?>(
        future: FirebaseAuth.instance.authStateChanges().first,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}'));
          }

          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return Center(child: Text('Tidak ada pengguna yang login'));
          }

          final User user = userSnapshot.data!;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('overtime_records')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('Belum ada data lembur'));
              }

              return ListView(
                children: snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text('Overtime In: ${_formatTimestamp(data['overtime_in_time'])}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overtime Out: ${_formatTimestamp(data['overtime_out_time'])}'),
                          Text('Total Overtime: ${_calculateTotalOvertime(data['overtime_in_time'], data['overtime_out_time'])}'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    var dateTime = timestamp.toDate();
    return "${dateTime.day}-${dateTime.month}-${dateTime.year} ${dateTime.hour}:${dateTime.minute}:${dateTime.second}";
  }

  String _calculateTotalOvertime(Timestamp? inTime, Timestamp? outTime) {
    if (inTime == null || outTime == null) return 'N/A';
    var inDateTime = inTime.toDate();
    var outDateTime = outTime.toDate();
    var duration = outDateTime.difference(inDateTime);
    return '${duration.inHours}:${duration.inMinutes % 60}:${duration.inSeconds % 60}';
  }
}
