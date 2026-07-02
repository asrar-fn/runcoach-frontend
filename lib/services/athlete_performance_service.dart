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

    // BUG FIX 1: Always convert scheduledDate to local time.
    // Without .toLocal(), a UTC date like "2025-06-23T00:00:00Z" stays UTC,
    // which then falls outside the local-time week filter in _PerformanceChart
    // (critical for IST +5:30 and any other UTC+ timezone).
    DateTime parsedScheduledDate = DateTime.now();
    final rawDate = j['scheduledDate']?.toString();
    if (rawDate != null && rawDate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate.trim());
      if (parsed != null) {
        parsedScheduledDate = parsed.toLocal(); // ← .toLocal() added
      }
    }

    return AssignmentRecord(
      id: j['id']?.toString() ?? j['_id']?.toString() ?? '',
      workoutType: (j['workoutType'] ?? 'run').toString().toLowerCase(),
      distanceKm: parseNum(j['distance'] ?? j['distanceKm']),
      durationMin: parseNum(j['duration'] ?? j['durationMin']),
      scheduledDate: parsedScheduledDate,
    );
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return !scheduledDate.isBefore(monday) && !scheduledDate.isAfter(sunday);
  }
}

class ActivityRecord {
  final String id;
  final String type;
  final double distanceKm;
  final double durationMin;
  final DateTime date;
  final String? stravaId;
  final String localDateKey;

  const ActivityRecord({
    required this.id,
    required this.type,
    required this.distanceKm,
    required this.durationMin,
    required this.date,
    this.stravaId,
    required this.localDateKey
  });

  factory ActivityRecord.fromJson(Map<String, dynamic> j) {
    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    DateTime parsedDate = DateTime.now();
    String localKey = '';

    // ── Pre-resolve exact local date string ──────────────────────────────────
    final rawDate = j['date'];
    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      final s = rawDate.toString().trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
        localKey = s;
        parsedDate = DateTime.tryParse(s) ?? DateTime.now();
      } else {
        final parsed = DateTime.tryParse(s);
        if (parsed != null) {
          final local = parsed.toLocal();
          parsedDate = local;
          localKey = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        }
      }
    } else {
      // Strava fallback
      final rawCreated = j['createdAt'];
      DateTime? local;
      if (rawCreated is int) {
        local = DateTime.fromMillisecondsSinceEpoch(rawCreated, isUtc: true).toLocal();
      } else if (rawCreated is double) {
        local = DateTime.fromMillisecondsSinceEpoch(rawCreated.toInt(), isUtc: true).toLocal();
      } else if (rawCreated != null) {
        final parsed = DateTime.tryParse(rawCreated.toString());
        if (parsed != null) local = parsed.toLocal();
      }

      if (local != null) {
        parsedDate = local;
        localKey = '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      }
    }

    // Fallback if formatting failed
    if (localKey.isEmpty) {
      localKey = '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
    }

    return ActivityRecord(
      id: j['id']?.toString() ?? j['_id']?.toString() ?? '',
      type: (j['type'] ?? 'run').toString().toLowerCase(),
      distanceKm: parseNum(j['distanceKm'] ?? j['distance']),
      durationMin: parseNum(j['durationMin'] ?? j['duration']),
      date: parsedDate,
      stravaId: j['stravaId']?.toString(),
        localDateKey: localKey,
    );
  }

  bool get isThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return !date.isBefore(monday) && !date.isAfter(sunday);
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

  double get overallPct {
    if (assignedMin <= 0) return distancePct;
    if (assignedKm <= 0) return timePct;
    return (distancePct + timePct) / 2;
  }

  String get assignedDurationLabel => fmtMin(assignedMin);
  String get actualDurationLabel   => fmtMin(actualMin);

  static String fmtMin(double min) {
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
  /// Count of bars for past days + today only (excludes future assignments).
  /// Used as the denominator for the Done X/Y chip.
  final int totalAssignments;
  /// Count of strictly-past days (before today) where no activity was logged.
  /// Today and future dates never contribute to missedCount.
  final int missedCount;
  final double weekAssignedKm;
  final double weekLoggedKm;
  final double weekAssignedMin;
  final double weekLoggedMin;

  const AthletePerformanceSummary({
    required this.bars,
    required this.avgCompletionPct,
    required this.matchedCount,
    required this.totalAssignments,
    required this.missedCount,
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
      weekAssignedKm <= 0
          ? 0
          : (weekLoggedKm / weekAssignedKm).clamp(0.0, 1.0);

  double get weekTimeProgress =>
      weekAssignedMin <= 0
          ? 0
          : (weekLoggedMin / weekAssignedMin).clamp(0.0, 1.0);

  static AthletePerformanceSummary empty() =>
      const AthletePerformanceSummary(
        bars: [],
        avgCompletionPct: 0,
        matchedCount: 0,
        totalAssignments: 0,
        missedCount: 0,
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
    final raw = (jsonDecode(res.body) as List)
        .map((j) => ActivityRecord.fromJson(j))
        .toList();

    return _deduplicate(raw);
  }

  /// BUG FIX 2: Removed duplicate stravaId check and duplicate fingerprint
  /// check that were silently discarding valid activities.
  List<ActivityRecord> _deduplicate(List<ActivityRecord> activities) {
    final seenStravaIds = <String>{};
    final seenFingerprints = <String>{};
    final result = <ActivityRecord>[];

    for (final act in activities) {
      // Deduplicate by stravaId
      if (act.stravaId != null && act.stravaId!.isNotEmpty) {
        if (seenStravaIds.contains(act.stravaId)) continue;
        seenStravaIds.add(act.stravaId!);
      }

      // Deduplicate by content fingerprint using the exact localDateKey
      final fp = '${act.localDateKey}|${act.distanceKm}|${act.durationMin}';
      if (seenFingerprints.contains(fp)) continue;
      seenFingerprints.add(fp);

      result.add(act);
    }
    return result;
  }

  AthletePerformanceSummary compute(
      List<AssignmentRecord> assignments,
      List<ActivityRecord> activities, {
        int windowDays = 0,
        int maxBars = 8,
      }) {
    // ── Step 1: This-week totals from all deduplicated activities ────────────
    double weekLoggedKm = 0;
    double weekLoggedMin = 0;
    for (final act in activities) {
      if (act.isThisWeek) {
        weekLoggedKm += act.distanceKm;
        weekLoggedMin += act.durationMin;
      }
    }

    // ── Step 2: This-week assigned totals ────────────────────────────────────
    double weekAssignedKm = 0;
    double weekAssignedMin = 0;
    for (final a in assignments) {
      if (a.isThisWeek) {
        weekAssignedKm += a.distanceKm;
        weekAssignedMin += a.durationMin;
      }
    }

    if (assignments.isEmpty) {
      return AthletePerformanceSummary(
        bars: [],
        avgCompletionPct: 0,
        matchedCount: 0,
        totalAssignments: 0,
        missedCount: 0,
        weekAssignedKm: weekAssignedKm,
        weekLoggedKm: weekLoggedKm,
        weekAssignedMin: weekAssignedMin,
        weekLoggedMin: weekLoggedMin,
      );
    }

    // ── Step 3: Per-assignment bars (grouped by date) ────────────────────────
    final sorted = [...assignments]
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    final recent = sorted.take(maxBars * 3).toList();

    final assignmentsByDay = <String, List<AssignmentRecord>>{};
    for (final a in recent) {
      final key = _dayKey(a.scheduledDate);
      assignmentsByDay.putIfAbsent(key, () => []).add(a);
    }

    final uniqueDatesSorted = assignmentsByDay.keys.toList()..sort();
    final recentDates = uniqueDatesSorted.length > maxBars
        ? uniqueDatesSorted.sublist(uniqueDatesSorted.length - maxBars)
        : uniqueDatesSorted;

    final activitiesByDay = <String, List<ActivityRecord>>{};
    for (final act in activities) {
      final key = act.localDateKey;
      activitiesByDay.putIfAbsent(key, () => []).add(act);
    }

    final usedIds = <String>{};
    final bars = <PerformanceBar>[];

    // matchedCount  → Done chip numerator   (past + today, logged)
    // totalPastOrToday → Done chip denominator (past + today only, no future)
    // missedCount   → Miss chip             (strictly past, not logged)
    // matchedForAvg → avgCompletionPct denominator
    int matchedCount = 0;
    int totalPastOrToday = 0;
    int missedCount = 0;
    int matchedForAvg = 0;
    double totalPct = 0;

    for (final dateKey in recentDates) {
      final dayAssignments = assignmentsByDay[dateKey]!;
      final firstAssignment = dayAssignments.first;

      final isFuture = _isFuture(firstAssignment.scheduledDate);
      final isStrictlyPast = _isStrictlyPast(firstAssignment.scheduledDate);
      // isToday = !isFuture && !isStrictlyPast

      double totalAssignedKm = 0;
      double totalAssignedMin = 0;
      final String workoutType = firstAssignment.workoutType;
      for (final a in dayAssignments) {
        if (a.distanceKm > 0 || a.durationMin > 0) {
          totalAssignedKm += a.distanceKm;
          totalAssignedMin += a.durationMin;
        }
      }

      if (totalAssignedKm <= 0 && totalAssignedMin <= 0) continue;

      // ── Future date: show assigned bar only, skip all counters ──────────
      if (isFuture) {
        bars.add(PerformanceBar(
          date: firstAssignment.scheduledDate,
          workoutType: workoutType,
          assignedKm: totalAssignedKm,
          actualKm: 0,
          assignedMin: totalAssignedMin,
          actualMin: 0,
          wasLogged: false,
        ));
        continue; // does NOT increment totalPastOrToday or missedCount
      }

      // ── Past or today: attempt activity matching ─────────────────────────
      totalPastOrToday++; // denominator for Done X/Y chip

      final candidates = activitiesByDay[dateKey] ?? [];
      final matches = candidates
          .where((act) => !usedIds.contains(act.id))
          .toList();

      double actualKm = 0;
      double actualMin = 0;
      bool wasLogged = false;

      if (matches.isNotEmpty) {
        for (final m in matches) {
          actualKm += m.distanceKm;
          actualMin += m.durationMin;
          usedIds.add(m.id);
        }
        wasLogged = true;
        matchedCount++;
      } else if (isStrictlyPast) {
        // Only strictly-past unlogged days count as missed.
        // Today with no log yet is NOT a miss.
        missedCount++;
      }

      final pct = totalAssignedKm > 0
          ? (actualKm / totalAssignedKm * 100).clamp(0, 200)
          : totalAssignedMin > 0
          ? (actualMin / totalAssignedMin * 100).clamp(0, 200)
          : 0.0;

      if (isStrictlyPast) {
        // Past day: always counts toward average (0% if not logged)
        totalPct += pct;
        matchedForAvg++;
      } else {
        // Today: counts toward average only if already logged
        if (wasLogged) {
          totalPct += pct;
          matchedForAvg++;
        }
      }

      bars.add(PerformanceBar(
        date: firstAssignment.scheduledDate,
        workoutType: workoutType,
        assignedKm: totalAssignedKm,
        actualKm: actualKm,
        assignedMin: totalAssignedMin,
        actualMin: actualMin,
        wasLogged: wasLogged,
      ));
    }

    final count = matchedForAvg > 0 ? matchedForAvg : 1;

    return AthletePerformanceSummary(
      bars: bars,
      avgCompletionPct: totalPct / count,
      matchedCount: matchedCount,
      totalAssignments: totalPastOrToday, // excludes future bars
      missedCount: missedCount,
      weekAssignedKm: weekAssignedKm,
      weekLoggedKm: weekLoggedKm,
      weekAssignedMin: weekAssignedMin,
      weekLoggedMin: weekLoggedMin,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isFuture(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final assignedDate = DateTime(date.year, date.month, date.day);
    return assignedDate.isAfter(todayDate);
  }

  bool _isStrictlyPast(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final assignedDate = DateTime(date.year, date.month, date.day);
    return assignedDate.isBefore(todayDate);
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