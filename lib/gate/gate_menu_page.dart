import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:school_mate/core/session.dart';

class GateMenuPage extends StatelessWidget {
  const GateMenuPage({super.key});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF5F7FA);
    const Color primaryBlue = Color(0xFF3B66D6);
    const Color darkText = Color(0xFF1A202C);

    final hour = DateTime.now().hour;
    String greetingText;
    if (hour < 12) {
      greetingText = "GOOD MORNING";
    } else if (hour < 18) {
      greetingText = "GOOD AFTERNOON";
    } else {
      greetingText = "GOOD EVENING";
    }

    final String sessionName = (AppSession.fullName ?? "").trim();
    final String displayName = sessionName.isEmpty ? "Security User" : sessionName;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              "MyStudentApp",
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          _buildGatePill(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(darkText, primaryBlue, greetingText, displayName),
            const SizedBox(height: 24),
            _buildHeroScanner(context, primaryBlue),
            const SizedBox(height: 32),
            Text(
              "RECENT",
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('accessEvents')
                  .orderBy('timestamp', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}", style: TextStyle(color: Colors.red[300]));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text("No recent activity found.", 
                      style: TextStyle(color: Colors.grey[500], fontSize: 14));
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final timeStr = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
                    final String studentName = data['fullName'] ?? 'Unknown';
                    final String classCode = data['classId'] ?? '--';
                    
                    // Enhanced status check to include entry, exit, and success as positive results
                    final String status = (data['status'] ?? '').toString().toLowerCase();
                    final Color statusColor = (status == 'entry' || status == 'success' || status == 'exit') 
                        ? Colors.green : Colors.red;

                    return _buildRecentActivityItem(studentName, timeStr, classCode, statusColor);
                  }).toList(),
                );
              },
            ),
            // Logout option remains accessible via the profile card or as a subtle button
            Center(
              child: TextButton(
                onPressed: _logout,
                child: Text("Logout", style: TextStyle(color: Colors.grey[400])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGatePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, size: 16, color: Color(0xFF3B66D6)),
          const SizedBox(width: 6),
          const Text(
            "MyStudentApp",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          Container(
            height: 12,
            width: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const Text(
            "GATE",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3B66D6)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Color darkText, Color primaryBlue, String greeting, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Matches style guide 20px-24px
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.person_rounded, color: primaryBlue, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const Text(
                  "Security Personnel",
                  style: TextStyle(
                    color: Color(0xFF3B66D6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroScanner(BuildContext context, Color primaryBlue) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/gateScan'),
      child: Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          color: primaryBlue,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.3),
              blurRadius: 25,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: CircleAvatar(radius: 80, backgroundColor: Colors.white.withValues(alpha: 0.1)),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withValues(alpha: 0.05)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Scan QR",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFFFCC00), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Text(
                    "Tap anywhere to start the camera",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityItem(String name, String time, String classCode, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A202C)),
            ),
          ),
          Text(
            classCode,
            style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(color: Color(0xFF3B66D6), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}