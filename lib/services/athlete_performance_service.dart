// lib/services/athlete_performance_service.dart
//
// Fetches assignments + activities, matches by date (±1 day) + type, and computes:
//   • per-workout distance AND time completion
//   • this-week distance + time progress (for the live progress bars)
//   • overall performance level (Excellent / On Track / Low / No Data)

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Raw API models
// ─────────────────────────────────────────────────────────────────────────────

class AssignmentRecord {
  final String id;
  final String workoutType;
  final double distanceKm;
  final double durationMin;
  final DateTime scheduledDate;

  const AssignmentRecord({
    required this.id,
    required this.workoutType,
    required this.distanceKm,
    required this.durationMin,
    required this.scheduledDate,
  });

  factory AssignmentRecord.fromJson(Map<String, dynamic> j) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      final s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(s) ?? 0;
    }

    return AssignmentRecord(
      id: j['id']?.toString() ?? '',
      workoutType: (j['workoutType'] ?? 'run').toString().toLowerCase(),
      distanceKm: parseNum(j['distance']),
      durationMin: parseNum(j['duration']),
      scheduledDate:
      DateTime.tryParse(j['scheduledDate'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final sunday =
    monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return !scheduledDate.isBefore(monday) && !scheduledDate.isAfter(sunday);
  }
}

class ActivityRecord {
  final String id;
  final String type;
  final double distanceKm;
  final double durationMin;
  final DateTime date;

  const ActivityRecord({
    required this.id,
    required this.type,
    required this.distanceKm,
    required this.durationMin,
    required this.date,
  });

  factory ActivityRecord.fromJson(Map<String, dynamic> j) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ActivityRecord(
      id: j['id']?.toString() ?? '',
      type: (j['type'] ?? 'run').toString().toLowerCase(),
      distanceKm: parseNum(j['distanceKm']),
      durationMin: parseNum(j['durationMin']),
      date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Computed models
// ─────────────────────────────────────────────────────────────────────────────

class PerformanceBar {
  final DateTime date;
  final String workoutType;
  final double assignedKm;
  final double actualKm;
  final double assignedMin;
  final double actualMin;
  final bool wasLogged;

  const PerformanceBar({
    required this.date,
    required this.workoutType,
    required this.assignedKm,
    required this.actualKm,
    required this.assignedMin,
    required this.actualMin,
    required this.wasLogged,
  });

  double get distancePct =>
      assignedKm <= 0 ? 0 : (actualKm / assignedKm * 100).clamp(0, 200);

  double get timePct =>
      assignedMin <= 0 ? 0 : (actualMin / assignedMin * 100).clamp(0, 200);

  /// Combined score: average of distance% and time% (when time is assigned)
  double get overallPct {
    if (assignedMin <= 0) return distancePct;
    if (assignedKm <= 0) return timePct;
    return (distancePct + timePct) / 2;
  }

  String get assignedDurationLabel => _fmtMin(assignedMin);
  String get actualDurationLabel => _fmtMin(actualMin);

  static String _fmtMin(double min) {
    if (min <= 0) return '–';
    final h = (min ~/ 60);
    final m = (min % 60).round();
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

enum PerformanceLevel { excellent, good, needsAttention, noData }

class AthletePerformanceSummary {
  final List<PerformanceBar> bars;
  final double avgCompletionPct;
  final int matchedCount;
  final int totalAssignments;

  // This-week progress
  final double weekAssignedKm;
  final double weekLoggedKm;
  final double weekAssignedMin;
  final double weekLoggedMin;

  const AthletePerformanceSummary({
    required this.bars,
    required this.avgCompletionPct,
    required this.matchedCount,
    required this.totalAssignments,
    required this.weekAssignedKm,
    required this.weekLoggedKm,
    required this.weekAssignedMin,
    required this.weekLoggedMin,
  });

  PerformanceLevel get level {
    if (totalAssignments == 0) return PerformanceLevel.noData;
    if (avgCompletionPct >= 90) return PerformanceLevel.excellent;
    if (avgCompletionPct >= 50) return PerformanceLevel.good;
    return PerformanceLevel.needsAttention;
  }

  double get weekDistanceProgress =>
      weekAssignedKm <= 0 ? 0 : (weekLoggedKm / weekAssignedKm).clamp(0.0, 1.0);

  double get weekTimeProgress =>
      weekAssignedMin <= 0 ? 0 : (weekLoggedMin / weekAssignedMin).clamp(0.0, 1.0);

  static AthletePerformanceSummary empty() => const AthletePerformanceSummary(
    bars: [],
    avgCompletionPct: 0,
    matchedCount: 0,
    totalAssignments: 0,
    weekAssignedKm: 0,
    weekLoggedKm: 0,
    weekAssignedMin: 0,
    weekLoggedMin: 0,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AthletePerformanceService {
  final String baseUrl;
  final String authToken;

  const AthletePerformanceService({
    required this.baseUrl,
    required this.authToken,
  });

  static Future<AthletePerformanceService> fromStorage({
    required String baseUrl,
  }) async {
    final authData = await AuthStorageService.getAuthData();
    return AthletePerformanceService(
      baseUrl: baseUrl,
      authToken: authData['authToken'] ?? '',
    );
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $authToken',
  };

  Future<List<AssignmentRecord>> fetchAssignments(String athleteId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/assignments/athlete/$athleteId'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Assignments fetch failed (${res.statusCode})');
    }
    return (jsonDecode(res.body) as List)
        .map((j) => AssignmentRecord.fromJson(j))
        .toList();
  }

  Future<List<ActivityRecord>> fetchActivities(String athleteId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/activities/athlete/$athleteId'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Activities fetch failed (${res.statusCode})');
    }
    return (jsonDecode(res.body) as List)
        .map((j) => ActivityRecord.fromJson(j))
        .toList();
  }

  AthletePerformanceSummary compute(
      List<AssignmentRecord> assignments,
      List<ActivityRecord> activities, {
        int windowDays = 1,
        int maxBars = 8,
      }) {
    if (assignments.isEmpty) return AthletePerformanceSummary.empty();

    final sorted = [...assignments]
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    final recent = sorted.take(maxBars).toList().reversed.toList();

    final usedIds = <String>{};
    final bars = <PerformanceBar>[];
    int matched = 0;
    double totalPct = 0;
    double weekAssignedKm = 0, weekLoggedKm = 0;
    double weekAssignedMin = 0, weekLoggedMin = 0;

    for (final a in recent) {
      if (a.distanceKm <= 0 && a.durationMin <= 0) continue;

      final match = _findBestMatch(a, activities, usedIds, windowDays);
      double actualKm = 0, actualMin = 0;
      bool wasLogged = false;

      if (match != null) {
        actualKm = match.distanceKm;
        actualMin = match.durationMin;
        usedIds.add(match.id);
        matched++;
        wasLogged = true;
      }

      // Score: distance-based, or time-based if no distance
      final pct = a.distanceKm > 0
          ? (actualKm / a.distanceKm * 100).clamp(0, 200)
          : a.durationMin > 0
          ? (actualMin / a.durationMin * 100).clamp(0, 200)
          : 0.0;
      totalPct += pct;

      if (a.isThisWeek) {
        weekAssignedKm += a.distanceKm;
        weekAssignedMin += a.durationMin;
        if (wasLogged) {
          weekLoggedKm += actualKm;
          weekLoggedMin += actualMin;
        }
      }

      bars.add(PerformanceBar(
        date: a.scheduledDate,
        workoutType: a.workoutType,
        assignedKm: a.distanceKm,
        actualKm: actualKm,
        assignedMin: a.durationMin,
        actualMin: actualMin,
        wasLogged: wasLogged,
      ));
    }

    final count = bars.isNotEmpty ? bars.length : 1;
    return AthletePerformanceSummary(
      bars: bars,
      avgCompletionPct: totalPct / count,
      matchedCount: matched,
      totalAssignments: bars.length,
      weekAssignedKm: weekAssignedKm,
      weekLoggedKm: weekLoggedKm,
      weekAssignedMin: weekAssignedMin,
      weekLoggedMin: weekLoggedMin,
    );
  }

  ActivityRecord? _findBestMatch(
      AssignmentRecord a,
      List<ActivityRecord> activities,
      Set<String> usedIds,
      int windowDays,
      ) {
    ActivityRecord? best;
    int bestDiff = windowDays + 1;
    for (final act in activities) {
      if (usedIds.contains(act.id)) continue;
      final typeOk = act.type.contains(a.workoutType) ||
          a.workoutType.contains(act.type) ||
          a.workoutType == 'run';
      if (!typeOk) continue;
      final diff = a.scheduledDate.difference(act.date).inDays.abs();
      if (diff <= windowDays && diff < bestDiff) {
        best = act;
        bestDiff = diff;
      }
    }
    return best;
  }

  Future<AthletePerformanceSummary> getSummary(String athleteId) async {
    final results = await Future.wait([
      fetchAssignments(athleteId),
      fetchActivities(athleteId),
    ]);
    return compute(
      results[0] as List<AssignmentRecord>,
      results[1] as List<ActivityRecord>,
    );
  }
}