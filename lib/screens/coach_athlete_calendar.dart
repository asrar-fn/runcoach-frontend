import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/auth_storage_service.dart';

// ─── Local models (no cross-file imports needed) ──────────────────────────────

class _CalAssignment {
  final String id;
  final DateTime? scheduledDate;
  final String? workoutType;
  final double? distanceKm;
  final int? durationMin;
  final String? instructions;
  final String status;

  _CalAssignment({
    required this.id,
    this.scheduledDate,
    this.workoutType,
    this.distanceKm,
    this.durationMin,
    this.instructions,
    this.status = 'scheduled',
  });

  factory _CalAssignment.fromJson(Map<String, dynamic> json) {
    double? dist;
    final rawDist = json['distance'] ?? json['distanceKm'];
    if (rawDist != null) dist = double.tryParse(rawDist.toString());

    int? dur;
    final rawDur = json['duration'] ?? json['durationMin'];
    if (rawDur != null) dur = int.tryParse(rawDur.toString());

    DateTime? date;
    final rawDate = json['scheduledDate'] ?? json['date'];
    if (rawDate != null) date = _safeLocalDate(rawDate.toString());

    return _CalAssignment(
      id: json['id'] ?? json['_id'] ?? '',
      scheduledDate: date,
      workoutType: json['workoutType'],
      distanceKm: dist,
      durationMin: dur,
      instructions: json['instructions'],
      status: (json['status'] ?? 'scheduled').toString().toLowerCase(),
    );
  }
}

class _CalActivity {
  final String id;
  final DateTime? date;
  final double? distanceKm;
  final int? durationMin;
  final String? type;

  _CalActivity({
    required this.id,
    this.date,
    this.distanceKm,
    this.durationMin,
    this.type,
  });

  factory _CalActivity.fromJson(Map<String, dynamic> json) {
    double? dist;
    final rawDist = json['distanceKm'] ?? json['distance'];
    if (rawDist != null) dist = double.tryParse(rawDist.toString());

    int? dur;
    final rawDur = json['durationMin'] ?? json['duration'];
    if (rawDur != null) dur = int.tryParse(rawDur.toString());

    return _CalActivity(
      id: json['id'] ?? json['_id'] ?? '',
      date: _safeLocalDate(json['date'] ?? json['createdAt']),
      distanceKm: dist,
      durationMin: dur,
      type: json['type'],
    );
  }
}

DateTime? _safeLocalDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  // Date-only string → parse as local
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (dateOnly != null) {
    return DateTime(
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
    );
  }
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return null;
  }
}

String _dayKey(DateTime? d) {
  if (d == null) return '';
  return DateFormat('yyyy-MM-dd').format(d);
}

// ─── Workout type metadata ────────────────────────────────────────────────────

const _workoutMeta = {
  'easy':     {'icon': '🚶', 'label': 'Easy Run'},
  'tempo':    {'icon': '🏃', 'label': 'Tempo Run'},
  'interval': {'icon': '⚡', 'label': 'Intervals'},
  'long':     {'icon': '🏃‍♂️', 'label': 'Long Run'},
  'rest':     {'icon': '😴', 'label': 'Rest Day'},
  'custom':   {'icon': '🏃', 'label': 'Workout'},
};

Map<String, String> _meta(String? type) {
  final key = (type ?? '').toLowerCase();
  return (_workoutMeta[key] ?? _workoutMeta['custom'])!
  as Map<String, String>;
}

// ─── Main Widget ──────────────────────────────────────────────────────────────

class CoachAthleteCalendar extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const CoachAthleteCalendar({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  @override
  State<CoachAthleteCalendar> createState() => _CoachAthleteCalendarState();
}

class _CoachAthleteCalendarState extends State<CoachAthleteCalendar>
    with SingleTickerProviderStateMixin {

  // ── Tab controller (Week / Month) — owned here, no conflicts
  late TabController _viewTab;

  // ── Data
  List<_CalAssignment> _assignments = [];
  List<_CalActivity> _activities = [];
  bool _loading = true;
  String? _error;

  // ── Calendar navigation
  DateTime _currentDate = DateTime.now();
  String _selectedDay = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── Colors
  static const _blue   = Color(0xFF2575FC);
  static const _green  = Color(0xFF2ECC71);
  static const _orange = Color(0xFFF7941D);
  static const _dark   = Color(0xFF2C3E50);
  static const _medium = Color(0xFF7F8C8D);

  @override
  void initState() {
    super.initState();
    _viewTab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    _fetchData();
  }

  @override
  void dispose() {
    _viewTab.dispose();
    super.dispose();
  }

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetchData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'] ?? '';

      final results = await Future.wait([
        http.get(
          Uri.parse('http://localhost:5000/api/assignments/athlete/${widget.athleteId}'),
          headers: {'Authorization': 'Bearer $token'},
        ),
        http.get(
          Uri.parse('http://localhost:5000/api/activities/athlete/${widget.athleteId}'),
          headers: {'Authorization': 'Bearer $token'},
        ),
      ]);

      if (results[0].statusCode == 200) {
        final List data = jsonDecode(results[0].body);
        _assignments = data.map((e) => _CalAssignment.fromJson(e)).toList();
      }
      if (results[1].statusCode == 200) {
        final List data = jsonDecode(results[1].body);
        _activities = data.map((e) => _CalActivity.fromJson(e)).toList();
      }
    } catch (e) {
      _error = 'Failed to load calendar: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─── Derived helpers ──────────────────────────────────────────────────────

  Set<String> get _activityDays =>
      _activities.map((a) => _dayKey(a.date)).where((k) => k.isNotEmpty).toSet();

  bool _isCompleted(_CalAssignment a) =>
      a.status == 'completed' || _activityDays.contains(_dayKey(a.scheduledDate));

  List<_CalAssignment> _assignmentsForDay(DateTime day) {
    final key = _dayKey(day);
    return _assignments.where((a) => _dayKey(a.scheduledDate) == key).toList();
  }

  List<_CalActivity> _activitiesForDay(DateTime day) {
    final key = _dayKey(day);
    return _activities.where((a) => _dayKey(a.date) == key).toList();
  }

  // ─── Week / Month navigation ──────────────────────────────────────────────

  List<DateTime> _weekDays(DateTime ref) {
    final offset = ref.weekday % 7; // Sun=0
    final sunday = ref.subtract(Duration(days: offset));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  List<DateTime> _monthDays(DateTime ref) {
    final first = DateTime(ref.year, ref.month, 1);
    final offset = first.weekday % 7;
    final start = first.subtract(Duration(days: offset));
    return List.generate(42, (i) => start.add(Duration(days: i)));
  }

  void _navigate(int dir) => setState(() {
    if (_viewTab.index == 0) {
      _currentDate = _currentDate.add(Duration(days: dir * 7));
    } else {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + dir, 1);
    }
  });

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: _blue),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red)),
            const SizedBox(height: 12),
            TextButton(onPressed: _fetchData, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final today = _dayKey(DateTime.now());
    final selectedDate = DateFormat('yyyy-MM-dd').parse(_selectedDay);
    final selAssignments = _assignmentsForDay(selectedDate);
    final selActivities  = _activitiesForDay(selectedDate);

    final displayLabel = _selectedDay == today
        ? "Today's Workouts"
        : "Workouts for ${DateFormat('MMM d, yyyy').format(selectedDate)}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Selected day detail card ────────────────────────────────────────
        _DayDetailCard(
          label: displayLabel,
          assignments: selAssignments,
          activities: selActivities,
          dark: _dark,
          medium: _medium,
          blue: _blue,
          green: _green,
        ),
        const SizedBox(height: 16),

        // ── Tab + navigation row ────────────────────────────────────────────
        Row(
          children: [
            // Week / Month toggle
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LayoutBuilder(builder: (ctx, c) {
                  final w = (c.maxWidth / 2) - 4;
                  return Stack(children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      alignment: _viewTab.index == 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        width: w,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_blue, Color(0xFF6A11CB)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _viewTab,
                      indicatorColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.black87,
                      labelStyle: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      tabs: const [Tab(text: 'Week'), Tab(text: 'Month')],
                    ),
                  ]);
                }),
              ),
            ),
            const SizedBox(width: 8),
            // Prev
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_left, color: _dark),
              onPressed: () => _navigate(-1),
            ),
            // Label
            SizedBox(
              width: 76,
              child: Center(
                child: Text(
                  _viewTab.index == 0
                      ? DateFormat('MMM d').format(_weekDays(_currentDate).first)
                      : DateFormat('MMM yyyy').format(_currentDate),
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _dark),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Next
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_right, color: _dark),
              onPressed: () => _navigate(1),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Calendar grid ───────────────────────────────────────────────────
        LayoutBuilder(builder: (ctx, constraints) {
          return _viewTab.index == 0
              ? _buildWeekGrid(constraints.maxWidth, today)
              : _buildMonthGrid(constraints.maxWidth, today);
        }),
      ],
    );
  }

  // ─── Week grid ─────────────────────────────────────────────────────────────

  Widget _buildWeekGrid(double width, String today) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final days = _weekDays(_currentDate);
    final cellW = (width - 16) / 7;
    final cellH = cellW / 0.55;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        // Header
        Row(children: labels
            .map((l) => SizedBox(
          width: cellW,
          child: Center(
            child: Text(l,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _medium)),
          ),
        ))
            .toList()),
        const Divider(height: 8, thickness: 0.5),
        // Single row
        SizedBox(
          height: cellH,
          child: Row(
            children: days.map((d) =>
                SizedBox(width: cellW, height: cellH,
                    child: _DayCell(
                      date: d,
                      today: today,
                      selected: _selectedDay,
                      assignments: _assignmentsForDay(d),
                      activities: _activitiesForDay(d),
                      isCurrentMonth: true,
                      onTap: () => setState(() => _selectedDay = _dayKey(d)),
                      blue: _blue,
                      green: _green,
                      medium: _medium,
                      isCompleted: _isCompleted,
                    ))).toList(),
          ),
        ),
      ]),
    );
  }

  // ─── Month grid ────────────────────────────────────────────────────────────

  Widget _buildMonthGrid(double width, String today) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final days = _monthDays(_currentDate);
    final cellW = (width - 16) / 7;
    final cellH = cellW / 0.85;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(children: [
        // Header
        Row(children: labels
            .map((l) => SizedBox(
          width: cellW,
          child: Center(
            child: Text(l,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _medium)),
          ),
        ))
            .toList()),
        const Divider(height: 8, thickness: 0.5),
        // 6 rows
        ...List.generate(6, (row) => SizedBox(
          height: cellH,
          child: Row(
            children: List.generate(7, (col) {
              final d = days[row * 7 + col];
              return SizedBox(
                width: cellW,
                height: cellH,
                child: _DayCell(
                  date: d,
                  today: today,
                  selected: _selectedDay,
                  assignments: _assignmentsForDay(d),
                  activities: _activitiesForDay(d),
                  isCurrentMonth: d.month == _currentDate.month,
                  onTap: () => setState(() => _selectedDay = _dayKey(d)),
                  blue: _blue,
                  green: _green,
                  medium: _medium,
                  isCompleted: _isCompleted,
                ),
              );
            }),
          ),
        )),
      ]),
    );
  }
}

// ─── Day Cell ─────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime date;
  final String today;
  final String selected;
  final List<_CalAssignment> assignments;
  final List<_CalActivity> activities;
  final bool isCurrentMonth;
  final VoidCallback onTap;
  final Color blue, green, medium;
  final bool Function(_CalAssignment) isCompleted;

  const _DayCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.assignments,
    required this.activities,
    required this.isCurrentMonth,
    required this.onTap,
    required this.blue,
    required this.green,
    required this.medium,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final key = _dayKey(date);
    final isToday    = key == today;
    final isSelected = key == selected;
    final hasActivity = activities.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? blue : isToday ? blue : Colors.grey.shade200,
            width: isSelected || isToday ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number
            Text(
              '${date.day}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? blue
                    : isToday
                    ? blue
                    : isCurrentMonth
                    ? const Color(0xFF2C3E50)
                    : Colors.grey.shade400,
              ),
            ),
            // Assignment badge
            if (assignments.isNotEmpty) ...[
              const SizedBox(height: 2),
              _MiniWorkoutBadge(
                assignment: assignments.first,
                completed: isCompleted(assignments.first),
                green: green,
              ),
              if (assignments.length > 1)
                Text('+${assignments.length - 1}',
                    style: GoogleFonts.poppins(
                        fontSize: 8, color: Colors.grey.shade500)),
            ] else if (hasActivity) ...[
              // Activity logged but no assignment (free runs)
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: green.withOpacity(0.4), width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🏃', style: const TextStyle(fontSize: 9)),
                  const SizedBox(width: 2),
                  const Icon(Icons.check_circle, size: 8, color: Color(0xFF2ECC71)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Mini workout badge ───────────────────────────────────────────────────────

class _MiniWorkoutBadge extends StatelessWidget {
  final _CalAssignment assignment;
  final bool completed;
  final Color green;

  const _MiniWorkoutBadge({
    required this.assignment,
    required this.completed,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _meta(assignment.workoutType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: completed
            ? green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: completed
              ? green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(meta['icon']!, style: const TextStyle(fontSize: 9)),
        if (completed) ...[
          const SizedBox(width: 2),
          Icon(Icons.check_circle, size: 8, color: green),
        ],
      ]),
    );
  }
}

// ─── Day detail card ──────────────────────────────────────────────────────────

class _DayDetailCard extends StatelessWidget {
  final String label;
  final List<_CalAssignment> assignments;
  final List<_CalActivity> activities;
  final Color dark, medium, blue, green;

  const _DayDetailCard({
    required this.label,
    required this.assignments,
    required this.activities,
    required this.dark,
    required this.medium,
    required this.blue,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = assignments.isNotEmpty || activities.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w700, color: dark)),
          const SizedBox(height: 12),
          if (!hasContent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No workouts or activities for this day.',
                  style: GoogleFonts.poppins(fontSize: 12, color: medium)),
            ),

          // ── Assignments
          ...assignments.map((a) => _AssignmentRow(
            assignment: a,
            activities: activities,
            blue: blue,
            green: green,
            medium: medium,
            dark: dark,
          )),

          // ── Unmatched activities (no assignment that day)
          if (assignments.isEmpty && activities.isNotEmpty)
            ...activities.map((act) => _ActivityRow(
              activity: act,
              green: green,
              medium: medium,
              dark: dark,
            )),
        ],
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  final _CalAssignment assignment;
  final List<_CalActivity> activities;
  final Color blue, green, medium, dark;

  const _AssignmentRow({
    required this.assignment,
    required this.activities,
    required this.blue,
    required this.green,
    required this.medium,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final dayKey = _dayKey(assignment.scheduledDate);
    final matched = activities
        .where((a) => _dayKey(a.date) == dayKey)
        .fold(0.0, (s, a) => s + (a.distanceKm ?? 0));
    final assigned = assignment.distanceKm ?? 0;
    final pct = assigned > 0
        ? ((matched / assigned) * 100).round().clamp(0, 100)
        : (matched > 0 ? 100 : 0);
    final completed = pct >= 100 ||
        assignment.status == 'completed' ||
        activities.any((a) => _dayKey(a.date) == dayKey);
    final progressColor = pct >= 100
        ? green
        : pct >= 60
        ? const Color(0xFFF7941D)
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? green.withOpacity(0.05) : blue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: completed ? green.withOpacity(0.3) : blue.withOpacity(0.2),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_meta(assignment.workoutType)['icon']!,
              style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              assignment.workoutType ?? 'Workout',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: dark),
            ),
          ),
          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (completed ? green : blue).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              completed ? 'Completed' : 'Scheduled',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: completed ? green : blue),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        // Stats row
        Wrap(spacing: 16, children: [
          if (assignment.distanceKm != null)
            _Chip(
                icon: Icons.place_outlined,
                label: '${assignment.distanceKm!.toStringAsFixed(1)} km',
                color: medium),
          if (assignment.durationMin != null)
            _Chip(
                icon: Icons.access_time,
                label: '${assignment.durationMin} min',
                color: medium),
          if (matched > 0)
            _Chip(
                icon: Icons.check,
                label: '${matched.toStringAsFixed(1)} km logged',
                color: green),
        ]),
        // Progress bar
        if (assigned > 0) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('$pct%',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: progressColor)),
          ]),
        ],
        // Instructions
        if (assignment.instructions != null &&
            assignment.instructions!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(assignment.instructions!,
              style: GoogleFonts.poppins(fontSize: 11, color: medium)),
        ],
      ]),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final _CalActivity activity;
  final Color green, medium, dark;

  const _ActivityRow({
    required this.activity,
    required this.green,
    required this.medium,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    String paceStr = '—';
    final dist = activity.distanceKm ?? 0;
    final dur = activity.durationMin ?? 0;
    if (dist > 0 && dur > 0) {
      final secs = (dur * 60) / dist;
      final m = secs ~/ 60;
      final s = (secs % 60).round();
      paceStr = '$m:${s.toString().padLeft(2, '0')} /km';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: green.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.directions_run, color: green, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(activity.type ?? 'Activity',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: dark)),
            Wrap(spacing: 12, children: [
              if (dist > 0)
                _Chip(
                    icon: Icons.place_outlined,
                    label: '${dist.toStringAsFixed(1)} km',
                    color: medium),
              if (dur > 0)
                _Chip(
                    icon: Icons.access_time,
                    label: '$dur min',
                    color: medium),
              _Chip(icon: Icons.speed, label: paceStr, color: medium),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('Logged',
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w600, color: green)),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color)),
    ]);
  }
}