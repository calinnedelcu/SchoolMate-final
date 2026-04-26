import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GateScanResultPageArguments {
  final bool isAllowed;
  final String? userId;
  final String? fullName;
  final String? classId;
  final String? reason;
  final String? scanType;
  final String? studentId; // Added for the ID Badge
  final bool hasActiveLeave; // Added for dynamic leave request status
  final String? errorMessage;

  GateScanResultPageArguments({
    required this.isAllowed,
    this.userId,
    this.fullName,
    this.classId,
    this.reason,
    this.studentId,
    this.scanType,
    this.hasActiveLeave = false, // Default to false
    this.errorMessage,
  });
}

class GateScanResultPage extends StatelessWidget {
  const GateScanResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as GateScanResultPageArguments;
    final String initials = (args.fullName ?? "??")
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    const Color primaryBlue = Color(0xFF2D4AB7);
    const Color darkNavy = Color(0xFF0D1B3E);
    const Color statusGold = Color(0xFFB58E24);
    const Color statusGreen = Color(0xFF4CAF50);
    const Color errorRed = Color(0xFFD32F2F);
    const Color errorBg = Color(0xFFFFEBEE);
    const Color bgColor = Color(0xFFF5F7FA);
    const Color labelGray = Color(0xFF94A3B8);
    const Color dividerGray = Color(0xFFE2E8F0); // Dotted Line

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Navigation & Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: primaryBlue),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "SCAN RESULT",
                    style: TextStyle(
                      color: labelGray,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            "M",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "MyStudentApp",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: darkNavy),
                        ),
                        const SizedBox(width: 4),
                        Container(width: 1, height: 10, color: Colors.grey[300]),
                        const SizedBox(width: 4),
                        const Text(
                          "GATE",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: labelGray),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // B. Student Profile Card
                    _buildCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  args.fullName ?? "Unknown Student",
                                  style: const TextStyle(color: darkNavy, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "CLASS ${args.classId ?? '—'}",
                                  style: const TextStyle(color: statusGold, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "ID: ${args.userId ?? '---'}",
                                    style: const TextStyle(color: labelGray, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12), // 12px gap between cards

                    _buildCard(
                      child: Builder(
                        builder: (context) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("LEAVE REQUEST", style: TextStyle(color: labelGray, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                              const SizedBox(height: 12),
                              if (args.hasActiveLeave)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: statusGreen, size: 24),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "LEAVE REQUEST APPROVED",
                                      style: TextStyle(color: statusGreen, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    const Icon(Icons.cancel, color: errorRed, size: 24),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "NO ACTIVE REQUEST",
                                      style: TextStyle(color: errorRed, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              if (args.hasActiveLeave)
                                const Text(
                                  "This student has an approved leave for today.",
                                  style: TextStyle(color: statusGreen, fontSize: 12),
                                )
                              else
                                const Text(
                                  "This student has no leave request for today.",
                                  style: TextStyle(color: labelGray, fontSize: 12),
                                ),
                            ],
                          );
                        }
                      ),
                    ),
                    const SizedBox(height: 12), // 12px gap between cards

                    _buildCard(
                      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: args.classId != null && args.classId!.isNotEmpty
                            ? FirebaseFirestore.instance.collection('timetables').doc(args.classId).get()
                            : Future.value(null),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Text('Error loading schedule: ${snapshot.error}');
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Text('No schedule available for this class.');
                          }
            
                          final timetableData = snapshot.data!.data();
                          if (timetableData == null) {
                            return const Text('No schedule available for this class.');
                          }
            
                          final String initialStartTimeStr = timetableData['startTime'] ?? '08:00';
                          final List<dynamic> slotsRaw = timetableData['slots'] ?? [];
            
                          final now = DateTime.now();
                          DateTime currentSlotTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            int.parse(initialStartTimeStr.split(':')[0]),
                            int.parse(initialStartTimeStr.split(':')[1]),
                          );
            
                          final List<Widget> scheduleWidgets = [];
                          int lessonCount = 0;
            
                          for (var i = 0; i < slotsRaw.length; i++) {
                            final slot = slotsRaw[i] as Map<String, dynamic>;
                            final int duration = slot['duration'] ?? 0;
                            final String type = slot['type'] ?? 'unknown';
            
                            if (type == 'lesson') {
                              lessonCount++;
                              final lessonStartTime = currentSlotTime;
                              final lessonEndTime = currentSlotTime.add(Duration(minutes: duration));
            
                              final String formattedStartTime =
                                  '${lessonStartTime.hour.toString().padLeft(2, '0')}:${lessonStartTime.minute.toString().padLeft(2, '0')}';
                              final String formattedEndTime =
                                  '${lessonEndTime.hour.toString().padLeft(2, '0')}:${lessonEndTime.minute.toString().padLeft(2, '0')}';
            
                              final bool isNowSlot = now.isAfter(lessonStartTime) && now.isBefore(lessonEndTime);
                              final bool isCompletedSlot = now.isAfter(lessonEndTime);
                              final bool isFutureSlot = now.isBefore(lessonStartTime);
            
                              scheduleWidgets.add(
                                _buildScheduleItem(
                                  '$formattedStartTime - $formattedEndTime',
                                  'Lesson $lessonCount',
                                  isCompleted: isCompletedSlot,
                                  isNow: isNowSlot,
                                  isFuture: isFutureSlot,
                                ),
                              );
            
                              if (i < slotsRaw.length - 1) {
                                scheduleWidgets.add(_buildDottedDivider());
                              }
                            }
                            currentSlotTime = currentSlotTime.add(Duration(minutes: duration));
                          }
            
                          if (scheduleWidgets.isEmpty) {
                            return const Text('No lessons scheduled for today.');
                          }
            
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TODAY'S SCHEDULE", style: TextStyle(color: labelGray, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                              const SizedBox(height: 4),
                              ...scheduleWidgets,
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Footer & Primary Action
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (!args.isAllowed)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: errorBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: errorRed, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel, color: errorRed, size: 32),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "REQUEST PENDING — NOT APPROVED",
                                style: TextStyle(color: errorRed, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                "Leave not yet approved by form master.",
                                style: const TextStyle(color: errorRed, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Back to scanner",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08), // Increased opacity for more visibility
            blurRadius: 25, // Increased blur for a softer, wider shadow
            offset: const Offset(0, 8), // Increased vertical offset for more perceived lift
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildScheduleItem(String time, String subject, {bool isCompleted = false, bool isNow = false, bool isFuture = false}) {
    const Color primaryBlue = Color(0xFF2D4AB7);
    const Color darkNavy = Color(0xFF0D1B3E);
    const Color statusGreen = Color(0xFF4CAF50);
    const Color nowYellow = Color(0xFFFFD700);
    const Color labelGray = Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              time,
              style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              subject,
              style: TextStyle(
                color: isFuture ? labelGray : darkNavy,
                fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: nowYellow,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text("NOW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: darkNavy)),
            ),
          if (isCompleted)
            const Icon(Icons.check, color: statusGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildDottedDivider() {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: DottedLinePainter(),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 3, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}