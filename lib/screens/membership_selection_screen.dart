// lib/screens/membership_selection_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart'; // adjust path as needed
import '../services/auth_storage_service.dart';
import 'dummy_payment_screen.dart';
import 'select_plan_screen.dart';

class MembershipSelectionScreen extends StatelessWidget {
  const MembershipSelectionScreen({super.key});

  // ── Update plan in DB (Advanced plan - no coach)
  Future<void> _updatePlanInDB(String plan) async {
    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'];
    final userId = authData['userId'] ?? authData['athleteId'];

    await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/update-plan'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'plan': plan}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Upgrade Your Plan',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Text(
              'Choose your training style',
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick the plan that matches your running goal.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 32),

            // ── Advanced Plan Card
            _UpgradeCard(
              title: 'Advanced Plan',
              price: '₹500 / year',
              description:
              'Unlock detailed analytics, VO2 max estimation, HR trend cards, achievement badges, and daily motivation — everything you need to train smarter.',
              icon: Icons.bolt_rounded,
              features: const [
                'VO2 Max Estimation',
                'Heart Rate Trends',
                'Achievement Badges',
                'Daily Motivation',
                'Advanced Analytics',
              ],
              gradient: const [Color(0xFF1565C0), Color(0xFFE65100)],
              onTap: () {
                // Go directly to payment — no coach selection needed
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DummyPaymentScreen(
                      planName: 'Advanced Plan',
                      price: '₹500',
                      onPaymentSuccess: () => _updatePlanInDB('Advanced'),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Coach Plan Card
            _UpgradeCard(
              title: 'Train with a Coach',
              price: 'Price varies per Coach',
              description:
              'Get a fully customised training plan from an expert running coach — 5K to Ultra Marathon. Includes messaging, scheduled workouts, and progress tracking.',
              icon: FontAwesomeIcons.chalkboardUser,
              features: const [
                'Personalised Training Plan',
                'Direct Coach Messaging',
                'Scheduled Workouts',
                'Progress Tracking',
                '5K → Ultra Plans',
              ],
              gradient: const [Color(0xFF1565C0), Color(0xFFE65100)],
              onTap: () {
                // Coach flow: select distance plan → select coach → payment
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelectPlanScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Upgrade Card ─────────────────────────────────────────────────────────────

class _UpgradeCard extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final List<String> features;
  final String? badge;

  const _UpgradeCard({
    required this.title,
    required this.price,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
    required this.features,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + title row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text(price,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 28),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 14),

                // Description
                Text(description,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.5)),

                const SizedBox(height: 16),

                // Feature pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: features
                      .map((f) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 5),
                        Text(f,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),

        // Badge
        if (badge != null)
          Positioned(
            top: -10,
            right: 20,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Text(
                badge!,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1),
              ),
            ),
          ),
      ],
    );
  }
}