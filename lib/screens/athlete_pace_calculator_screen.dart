import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_storage_service.dart';
import './AthleteDashboard.dart';
import '../config/api_config.dart'; // adjust path as needed

class AthletePaceCalculatorScreen extends StatefulWidget {
  final String athleteId;

  const AthletePaceCalculatorScreen({super.key, required this.athleteId});

  @override
  State<AthletePaceCalculatorScreen> createState() =>
      _AthletePaceCalculatorScreenState();
}

class _AthletePaceCalculatorScreenState
    extends State<AthletePaceCalculatorScreen> {
  List<dynamic> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchActivityData();
  }

  Future<void> _fetchActivityData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/activities/athlete/${widget.athleteId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _activities = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
          "Failed to load activities: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error connecting to server: $e";
        _isLoading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Returns "mm:ss" pace string
  String _calculatePace(dynamic distance, dynamic duration) {
    try {
      final d = (distance is num)
          ? distance.toDouble()
          : double.parse(distance.toString());
      final t = (duration is num)
          ? duration.toDouble()
          : double.parse(duration.toString());
      if (d <= 0 || t <= 0) return '--:--';
      final totalSec = (t * 60) / d;
      final mins = totalSec ~/ 60;
      final secs = (totalSec % 60).round();
      return '$mins:${secs.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  /// Morning / Afternoon / Evening / Night based on hour
  String _runType(DateTime? date) {
    if (date == null) return 'Run';
    final h = date.hour;
    if (h >= 4 && h < 10) return 'Morning Run';
    if (h >= 10 && h < 15) return 'Afternoon Run';
    if (h >= 15 && h < 19) return 'Evening Run';
    return 'Night Run';
  }

  bool _isFromStrava(dynamic activity) =>
      (activity['source'] ?? '') == 'strava' ||
          (activity['stravaId'] != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Activity History',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _errorMessage != null
          ? Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.red)))
          : _activities.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No activities yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Log a run or connect Strava to get started.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  // ── Activity list ─────────────────────────────────────────────────────────────
  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: _activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = _activities[index];
        final dist = a['distanceKm'] ?? a['distance'] ?? 0;
        final dur = a['durationMin'] ?? a['duration'] ?? 0;
        final dateRaw = a['date'] ?? a['createdAt'];
        final DateTime? date = dateRaw != null
            ? DateTime.tryParse(dateRaw)?.toLocal()
            : null;
        final bool fromStrava = _isFromStrava(a);
        final String pace = _calculatePace(dist, dur);
        final String runType = _runType(date);

        // Use Strava run name if available, else derive from time-of-day
        final String title = (fromStrava &&
            (a['notes']?.toString().isNotEmpty ?? false))
            ? a['notes']
            : runType;

        return _ActivityCard(
          title: title,
          date: date,
          distanceKm: (dist is num) ? dist.toDouble() : 0,
          durationMin: (dur is num) ? dur.toInt() : 0,
          pace: pace,
          fromStrava: fromStrava,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Activity card widget
// ═══════════════════════════════════════════════════════════════════════════════
class _ActivityCard extends StatelessWidget {
  final String title;
  final DateTime? date;
  final double distanceKm;
  final int durationMin;
  final String pace;
  final bool fromStrava;

  const _ActivityCard({
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.durationMin,
    required this.pace,
    required this.fromStrava,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
    fromStrava ? const Color(0xFFFC4C02) : AppColors.primaryBlue;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withOpacity(0.7),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Left: run icon ──────────────────────────────────────────────
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_run,
                size: 22,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),

            // ── Middle: title + date + run-type pill ────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      // Strava or Manual badge
                      if (fromStrava)
                        _SourceBadge(
                          label: 'Strava',
                          icon: Icons.directions_run,
                          color: const Color(0xFFFC4C02),
                        )
                      else
                        _SourceBadge(
                          label: 'Manual',
                          icon: Icons.edit_outlined,
                          color: AppColors.primaryBlue,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Date + time
                  Text(
                    date != null
                        ? DateFormat('MMM d, yyyy · h:mm a').format(date!)
                        : '—',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 10),

                  // ── Stat chips row ──────────────────────────────────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Distance
                      _StatChip(
                        icon: Icons.straighten,
                        label:
                        '${distanceKm.toStringAsFixed(2)} km',
                        color: accentColor,
                      ),
                      // Duration
                      _StatChip(
                        icon: Icons.timer_outlined,
                        label: '$durationMin min',
                        color: AppColors.primaryBlue,
                      ),
                      // Pace
                      _StatChip(
                        icon: Icons.speed,
                        label: '$pace /km',
                        color: const Color(0xFF2ECC71),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small source badge (Strava / Manual) ─────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SourceBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small stat chip ───────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}