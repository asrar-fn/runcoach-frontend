import 'package:flutter/material.dart';
import 'dart:math' as Math;
import 'package:lottie/lottie.dart';

class RacePredictorLogic {
  static double predictTime(double t1Minutes, double d1Km, double d2Km) {
    if (d1Km <= 0 || d2Km <= 0 || t1Minutes <= 0) return 0.0;
    return t1Minutes * Math.pow((d2Km / d1Km), 1.06);
  }

  static String formatDuration(double totalMinutes) {
    if (totalMinutes.isNaN || totalMinutes.isInfinite || totalMinutes <= 0) return "--:--:--";
    final int hours = (totalMinutes / 60).floor();
    final int minutes = (totalMinutes % 60).floor();
    final int seconds = ((totalMinutes * 60) % 60).round();
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }
}

class AthleteScreenRacePredictor extends StatelessWidget {
  final double distance;
  final int duration;

  const AthleteScreenRacePredictor({
    super.key,
    required this.distance,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 1. Full Screen Mesh Gradient Background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F4FF), // Very soft blue
              Colors.white,
              Color(0xFFFDF0FF), // Very soft pinkish tint
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 2. Header with Back Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Performance Insights",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Integrated Hero Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Conquer Your",
                            style: TextStyle(
                                fontSize: 24,
                                color: Colors.black.withOpacity(0.6),
                                fontWeight: FontWeight.w300),
                          ),
                          const Text(
                            "Next Goal.",
                            style: TextStyle(
                              fontSize: 38,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D62ED),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Based on your recent $distance km activity.",
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    // Expanded(
                    //   flex: 2,
                    //   // child: Lottie.network(
                    //   //   'https://assets10.lottiefiles.com/packages/lf20_96mscz64.json',
                    //   //   height: 120,
                    //   //   fit: BoxFit.contain,
                    //   // ),
                    // ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. The Full Screen Grid of Shining Circles
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distributes them vertically
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildGlowCircle("5K", 5.0, const Color(0xFFFF9F0A))),
                          Expanded(child: _buildGlowCircle("10K", 10.0, const Color(0xFF30D158))),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildGlowCircle("21K", 21.1, const Color(0xFF0A84FF))),
                          Expanded(child: _buildGlowCircle("42.2K", 42.2, const Color(0xFFBF5AF2))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlowCircle(String label, double targetDist, Color color) {
    final predictedMinutes = RacePredictorLogic.predictTime(
      duration.toDouble(),
      distance,
      targetDist,
    );

    double progress = (distance / targetDist).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Glow Effect
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            // The Progress Ring
            SizedBox(
              width: 130,
              height: 130,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                strokeCap: StrokeCap.round, // Modern rounded ends
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            // Inner Content
            Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color.withOpacity(0.8),
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  RacePredictorLogic.formatDuration(predictedMinutes),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Modern Shining Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Text(
            "Predicted Time",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}