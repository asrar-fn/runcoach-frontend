import 'package:flutter/material.dart';

class HRZoneCalculatorScreen extends StatelessWidget {
  final DateTime? dateOfBirth;

  const HRZoneCalculatorScreen({
    super.key,
    required this.dateOfBirth,
  });

  int calculateAge(DateTime dob) {
    DateTime today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    // Fallback if data is missing
    if (dateOfBirth == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("HR Zone Calculator")),
        body: const Center(
          child: Text("Please set your Date of Birth in Settings."),
        ),
      );
    }

    // 1. Calculate Age and Max Heart Rate (MHR)
    final int age = calculateAge(dateOfBirth!);
    final int hrMax = 220 - age;

    // 2. Helper Function for MHR Percentages
    int getBpm(double percentage) {
      return (hrMax * percentage).round();
    }

    // 3. Define Zone Data using Standard Formula
    final List<Map<String, dynamic>> zones = [
      {
        "zone": "Zone 1",
        "title": "Recovery",
        "pct": "50-60%",
        "range": "${getBpm(0.50)} - ${getBpm(0.60)} bpm",
        "feeling": "Very Easy",
        "color": Colors.grey,
        "description": "Ideal for warm-ups and active recovery."
      },
      {
        "zone": "Zone 2",
        "title": "Fat Burn",
        "pct": "60-70%",
        "range": "${getBpm(0.60)} - ${getBpm(0.70)} bpm",
        "feeling": "Comfortable",
        "color": Colors.blue,
        "description": "Endurance and fat metabolism. You can talk easily."
      },
      {
        "zone": "Zone 3",
        "title": "Aerobic",
        "pct": "70-80%",
        "range": "${getBpm(0.70)} - ${getBpm(0.80)} bpm",
        "feeling": "Moderate",
        "color": Colors.green,
        "description": "Improves cardiovascular fitness and capacity."
      },
      {
        "zone": "Zone 4",
        "title": "Anaerobic",
        "pct": "80-90%",
        "range": "${getBpm(0.80)} - ${getBpm(0.90)} bpm",
        "feeling": "Hard",
        "color": Colors.orange,
        "description": "Improves speed endurance and performance."
      },
      {
        "zone": "Zone 5",
        "title": "Max Effort",
        "pct": "90-100%",
        "range": "${getBpm(0.90)} - $hrMax bpm",
        "feeling": "Peak Output",
        "color": Colors.red,
        "description": "Short bursts, top speed, and power."
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Heart Rate Zones", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card (Showing Max HR)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2575FC), Color(0xFF6A11CB)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text("Estimated Max Heart Rate", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text("$hrMax BPM", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMiniStat("Age", "$age"),
                      const SizedBox(width: 40),
                      _buildMiniStat("Formula", "220 - Age"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text("Training Zones (MHR)", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // Zone List
            ...zones.map((z) => _buildZoneCard(z)).toList(),

            const SizedBox(height: 20),
            const Text(
              "* These zones are calculated using the Standard MHR Formula (220 - Age). This is a general guide; individual limits may vary.",
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> z) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Left Color Bar
          Positioned.fill(
            child: Row(
              children: [
                Container(
                  width: 12,
                  decoration: BoxDecoration(
                    color: z['color'],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      z['zone'],
                      style: TextStyle(color: z['color'], fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      z['pct'],
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  z['title'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  z['range'],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                Text(
                  z['description'],
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Feeling Badge
          Positioned(
            right: 20,
            top: 45, // Adjusted to fit near the BPM range
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: z['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                z['feeling'],
                style: TextStyle(color: z['color'], fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}