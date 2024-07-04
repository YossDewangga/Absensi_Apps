import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BreakHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Break History'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .collection('break_logs')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text('No break history found.'));
            }

            var breakLogs = snapshot.data!.docs;

            return ListView.builder(
              itemCount: breakLogs.length,
              itemBuilder: (context, index) {
                var log = breakLogs[index];
                var data = log.data() as Map<String, dynamic>;
                var startBreak = data['start_break'] != null ? (data['start_break'] as Timestamp).toDate() : null;
                var endBreak = data['end_break'] != null ? (data['end_break'] as Timestamp).toDate() : null;
                var breakDuration = data['break_duration'] ?? 'Unknown duration';

                return ListTile(
                  title: Text('Break on ${startBreak != null ? _formatDate(startBreak) : 'Unknown'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start: ${startBreak != null ? _formatTime(startBreak) : 'Unknown'}'),
                      Text('End: ${endBreak != null ? _formatTime(endBreak) : 'Unknown'}'),
                      Text('Duration: $breakDuration'),
                    ],
                  ),
                  trailing: Icon(Icons.more_vert),
                  onTap: () {
                    // Implement detail view if needed
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
