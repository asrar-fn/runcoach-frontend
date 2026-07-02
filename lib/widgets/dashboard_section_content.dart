// lib/widgets/dashboard_section_content.dart
//
// Redesigned, compact internals for each dashboard section. These are the
// widgets that go *inside* a CollapsibleSection's child slot. Same color
// palette as the rest of the app (AppColors, the blue/orange gradient pair)
// but used with more restraint: gradient is reserved for the one section
// that should still feel like "today's headline" (Today's Workout); every
// other section sits calm on white so the page has one clear focal point
// instead of eight competing ones.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../screens/AthleteDashboard.dart' show Activity, DailyGoal;

// NOTE: `dynamic` typing below is used only in a couple of generic spots
// (badge maps, feature maps) where the data is already shaped as a Map by
// the caller. Activity/DailyGoal are imported directly above and used with
// their real types everywhere else, so null-safety still applies normally.

// ─────────────────────────────────────────────────────────────────────────
// Compact stat pill — used everywhere instead of each card inventing its
// own "chip" style. One visual language for "here is a number with a label".
// ─────────────────────────────────────────────────────────────────────────
class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  const StatPill({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: const Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Weekly Streak — compact: 7 dots in a row + one-line summary, no separate
// big gradient card. Still gets its own collapsible section, but the inside
// is much lighter than before.
// ─────────────────────────────────────────────────────────────────────────
class CompactStreakRow extends StatelessWidget {
  final List<Activity> activities;
  const CompactStreakRow({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));

    final days = List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final isFuture = day.isAfter(today);
      final hasActivity = !isFuture &&
          activities.any((a) =>
          a.date != null &&
              a.date!.year == day.year &&
              a.date!.month == day.month &&
              a.date!.day == day.day);
      return (date: day, hasActivity: hasActivity, isFuture: isFuture);
    });

    final completed = days.where((d) => d.hasActivity).length;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    String motivation;
    if (completed >= 6) {
      motivation = "Perfect consistency this week! 🔥";
    } else if (completed >= 4) {
      motivation = "Staying consistent — keep it up 💪";
    } else {
      motivation = "Let's get moving this week 🏃";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final d = days[i];
            final isToday = d.date.year == today.year &&
                d.date.month == today.month &&
                d.date.day == today.day;
            return Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: d.isFuture
                        ? const Color(0xFFF1F2F4)
                        : d.hasActivity
                        ? const Color(0xFF2575FC)
                        : const Color(0xFFF1F2F4),
                    border: isToday ? Border.all(color: const Color(0xFF2575FC), width: 2) : null,
                  ),
                  child: d.isFuture
                      ? null
                      : Icon(
                    d.hasActivity ? Icons.check_rounded : Icons.close_rounded,
                    color: d.hasActivity ? Colors.white : const Color(0xFFBDC3C7),
                    size: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i],
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? const Color(0xFF2575FC) : const Color(0xFF9AA1AC))),
              ],
            );
          }),
        ),
        const SizedBox(height: 12),
        Text(motivation,
            style: GoogleFonts.poppins(
                fontSize: 12.5, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Weekly Goal Tracker — compact bars, white background, CTA only if no goal.
// ─────────────────────────────────────────────────────────────────────────
class CompactGoalTracker extends StatelessWidget {
  final double totalKm;
  final int totalMin;
  final DailyGoal weeklyGoal;
  final VoidCallback onSetGoal;

  const CompactGoalTracker({
    super.key,
    required this.totalKm,
    required this.totalMin,
    required this.weeklyGoal,
    required this.onSetGoal,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDistGoal = weeklyGoal.distanceKm > 0;
    final bool hasTimeGoal = weeklyGoal.durationMin > 0;
    final bool noGoal = !hasDistGoal && !hasTimeGoal;

    if (noGoal) {
      return GestureDetector(
        onTap: onSetGoal,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF2575FC).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2575FC).withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flag_rounded, size: 16, color: Color(0xFF2575FC)),
              const SizedBox(width: 8),
              Text('Set Weekly Goal',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2575FC))),
            ],
          ),
        ),
      );
    }

    final distPct = hasDistGoal ? (totalKm / weeklyGoal.distanceKm).clamp(0.0, 1.0) : 0.0;
    final timePct = hasTimeGoal ? (totalMin / weeklyGoal.durationMin).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDistGoal) ...[
          _goalRow(Icons.directions_run, "Distance",
              "${totalKm.toStringAsFixed(1)} / ${weeklyGoal.distanceKm} km", distPct,
              const Color(0xFF2575FC)),
          if (hasTimeGoal) const SizedBox(height: 12),
        ],
        if (hasTimeGoal)
          _goalRow(Icons.timer_outlined, "Duration", "$totalMin / ${weeklyGoal.durationMin} min",
              timePct, const Color(0xFFE6783A)),
      ],
    );
  }

  Widget _goalRow(IconData icon, String label, String value, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A2E))),
            const Spacer(),
            Text(value,
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(pct >= 1.0 ? const Color(0xFF2ECC71) : color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tools grid — compact 2-line tiles, no heavy per-tile gradients/shadows.
// ─────────────────────────────────────────────────────────────────────────
class CompactToolsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> features;
  const CompactToolsGrid({super.key, required this.features});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 4 : (constraints.maxWidth > 420 ? 3 : 2);
      final itemWidth = (constraints.maxWidth - (cols - 1) * 10) / cols;

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: features.map((feature) {
          return SizedBox(
            width: itemWidth,
            child: Material(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: feature['onTap'] as VoidCallback,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2575FC).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(feature['icon'] as IconData,
                            size: 16, color: const Color(0xFF1976D2)),
                      ),
                      const SizedBox(height: 8),
                      Text(feature['title'] as String,
                          style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A2E)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 1),
                      Text(feature['subtitle'] as String,
                          style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Milestones — compact horizontal scroll of badges instead of a big Wrap
// grid eating vertical space. Earned-count lives in the section summary,
// not duplicated in the body.
// ─────────────────────────────────────────────────────────────────────────
class CompactMilestones extends StatelessWidget {
  final List<Map<String, dynamic>> badges; // {icon, label, earned, color}
  const CompactMilestones({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final badge = badges[i];
          final earned = badge['earned'] as bool;
          final color = badge['color'] as Color;
          return SizedBox(
            width: 64,
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: earned
                        ? LinearGradient(colors: [color, color.withOpacity(0.6)])
                        : null,
                    color: earned ? null : const Color(0xFFEFF1F4),
                  ),
                  child: Icon(
                    earned ? (badge['icon'] as IconData) : Icons.lock_outline,
                    color: earned ? Colors.white : const Color(0xFFBDC3C7),
                    size: 21,
                  ),
                ),
                const SizedBox(height: 6),
                Text(badge['label'] as String,
                    style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: earned ? const Color(0xFF1A1A2E) : const Color(0xFFBDC3C7)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Today's Quote — single line, no card-within-card. Lives inside its own
// collapsed section so it doesn't permanently occupy space.
// ─────────────────────────────────────────────────────────────────────────
class CompactMotivation extends StatelessWidget {
  final String quote;
  const CompactMotivation({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("\u201C", style: TextStyle(fontSize: 28, color: Color(0xFF6A11CB), height: 1)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(quote,
              style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF1A1A2E),
                  height: 1.5)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Advanced metrics placeholder — single compact prompt row instead of two
// separate big gradient cards that both say "connect your watch".
// ─────────────────────────────────────────────────────────────────────────
class CompactWatchPrompt extends StatelessWidget {
  final String message;
  const CompactWatchPrompt({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.watch_outlined, color: Color(0xFF9AA1AC), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF6B7280))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Recent activity row — slightly tightened vs original (no behavior change).
// ─────────────────────────────────────────────────────────────────────────
class CompactActivityRow extends StatelessWidget {
  final String title;
  final String timeLabel;
  final String distanceLabel;
  final String durationLabel;
  final String paceLabel;
  final bool isFromStrava;
  final bool isLast;

  const CompactActivityRow({
    super.key,
    required this.title,
    required this.timeLabel,
    required this.distanceLabel,
    required this.durationLabel,
    required this.paceLabel,
    required this.isFromStrava,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isFromStrava ? const Color(0xFFFC4C02) : const Color(0xFF1976D2);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.directions_run, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(timeLabel,
                        style:
                        GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF9AA1AC))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(distanceLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                  const SizedBox(height: 2),
                  Text("$durationLabel · $paceLabel",
                      style:
                      GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF9AA1AC))),
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: Color(0xFFF1F2F4)),
      ],
    );
  }
}