import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

class AdvisoryArchiveScreen extends StatelessWidget {
  final String currentTopicName;

  const AdvisoryArchiveScreen({super.key, required this.currentTopicName});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 2,
          foregroundColor: Colors.black87,
          title: Text(
            "Archive",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('advisories')
            .where('isArchived', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          final docs = allDocs.where((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            final source = data['source']?.toString();
            final topic = data['topic']?.toString();

            if (source == 'manual') return true;
            if (currentTopicName.isNotEmpty && topic == currentTopicName) return true;
            return false;
          }).toList();

          // Client-side sort to avoid requiring a composite index
          final sortedDocs = List<DocumentSnapshot>.from(docs);
          sortedDocs.sort((a, b) {
            final ta = a['createdAt'] as Timestamp?;
            final tb = b['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta); // Descending
          });

          if (sortedDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No archived advisories yet.",
                    style: GoogleFonts.montserrat(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Grouping logic
          final Map<String, List<DocumentSnapshot>> grouped = {};
          for (var doc in sortedDocs) {
            final ts = doc['createdAt'] as Timestamp?;
            if (ts != null) {
              final dateStr = DateFormat('EEEE, MMMM d, y').format(ts.toDate());
              if (!grouped.containsKey(dateStr)) {
                grouped[dateStr] = [];
              }
              grouped[dateStr]!.add(doc);
            }
          }

          final dates = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final items = grouped[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                    child: Text(
                      date,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                  ...items.map((item) {
                    final data = item.data() as Map<String, dynamic>;
                    final message = data['message'] ?? '';
                    final ts = data['createdAt'] as Timestamp?;
                    final timeStr = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(Icons.access_time, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}
}
