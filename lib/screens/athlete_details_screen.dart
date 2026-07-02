import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/athlete.dart';
import '../services/auth_storage_service.dart';
import './coach_athlete_calendar.dart';
import '../config/api_config.dart';
import '../widgets/assign_workout_bottom_sheet.dart'; // ← same sheet used by dashboard

// ─── Models ───────────────────────────────────────────────────────────────────

class Assignment {
  final String id;
  final String? scheduledDate;
  final String? workoutType;
  final double? distance;
  final int? duration;
  final String? title;
  final String? instructions;
  final String status;

  Assignment({
    required this.id,
    this.scheduledDate,
    this.workoutType,
    this.distance,
    this.duration,
    this.title,
    this.instructions,
    this.status = 'scheduled',
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    double? parsedDistance;
    final rawDist = json['distance'] ?? json['distanceKm'];
    if (rawDist != null) parsedDistance = double.tryParse(rawDist.toString());

    int? parsedDuration;
    final rawDur = json['duration'] ?? json['durationMin'];
    if (rawDur != null) parsedDuration = int.tryParse(rawDur.toString());

    return Assignment(
      id: json['id'] ?? json['_id'] ?? '',
      scheduledDate: json['scheduledDate'] ?? json['date'],
      workoutType: json['workoutType'],
      distance: parsedDistance,
      duration: parsedDuration,
      title: json['title'],
      instructions: json['instructions'],
      status: (json['status'] ?? 'scheduled').toString().toLowerCase(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'scheduledDate': scheduledDate,
    'workoutType': workoutType,
    'distance': distance,
    'duration': duration,
    'title': title,
    'instructions': instructions,
    'status': status,
  };
}

class Activity {
  final String id;
  final String? date;
  final String? createdAt;
  final double? distanceKm;
  final int? durationMin;
  final String? type;
  final String? stravaId;
  final String localDateKey;

  Activity({
    required this.id,
    this.date,
    this.createdAt,
    this.distanceKm,
    this.durationMin,
    this.type,
    this.stravaId,
    required this.localDateKey,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    double? dist;
    final rawDist = json['distanceKm'] ?? json['distance'];
    if (rawDist != null) dist = double.tryParse(rawDist.toString());

    int? dur;
    final rawDur = json['durationMin'] ?? json['duration'];
    if (rawDur != null) dur = int.tryParse(rawDur.toString());

    String? createdAtStr;
    final rawCreated = json['createdAt'];
    if (rawCreated is int) {
      createdAtStr = DateTime.fromMillisecondsSinceEpoch(rawCreated, isUtc: true)
          .toIso8601String();
    } else if (rawCreated is double) {
      createdAtStr = DateTime.fromMillisecondsSinceEpoch(rawCreated.toInt(), isUtc: true)
          .toIso8601String();
    } else {
      createdAtStr = rawCreated?.toString();
    }

    String localKey = '';
    final rawDate = json['date'];
    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      final s = rawDate.toString().trim();
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
        localKey = s;
      } else {
        final parsed = DateTime.tryParse(s);
        if (parsed != null) {
          final local = parsed.toLocal();
          localKey = '${local.year}-'
              '${local.month.toString().padLeft(2, '0')}-'
              '${local.day.toString().padLeft(2, '0')}';
        }
      }
    } else {
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
        localKey = '${local.year}-'
            '${local.month.toString().padLeft(2, '0')}-'
            '${local.day.toString().padLeft(2, '0')}';
      }
    }

    return Activity(
      id: json['id'] ?? json['_id'] ?? '',
      date: json['date']?.toString(),
      createdAt: createdAtStr,
      distanceKm: dist,
      durationMin: dur,
      type: json['type'],
      stravaId: json['stravaId']?.toString(),
      localDateKey: localKey,
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

DateTime? _parseDate(dynamic input) {
  if (input == null) return null;
  if (input is DateTime) return input;
  if (input is int) return DateTime.fromMillisecondsSinceEpoch(input, isUtc: true);
  if (input is double) return DateTime.fromMillisecondsSinceEpoch(input.toInt(), isUtc: true);
  if (input is String) {
    try {
      final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(input);
      if (dateOnly != null) {
        return DateTime.utc(
          int.parse(dateOnly.group(1)!),
          int.parse(dateOnly.group(2)!),
          int.parse(dateOnly.group(3)!),
        );
      }
      return DateTime.parse(input);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String _dayKey(dynamic input) {
  final d = _parseDate(input);
  if (d == null) return '';
  final local = d.toLocal();
  return DateFormat('yyyy-MM-dd').format(local);
}

String? _formatPace(double? distanceKm, int? durationMin) {
  if (distanceKm == null || distanceKm <= 0) return null;
  if (durationMin == null || durationMin <= 0) return null;
  final paceDecimal = durationMin / distanceKm;
  final paceMinutes = paceDecimal.floor();
  final paceSeconds = ((paceDecimal - paceMinutes) * 60).round();
  return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')} /km';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AthleteDetailsScreen extends StatefulWidget {
  final String athleteId;
  final Athlete athlete;

  const AthleteDetailsScreen({
    super.key,
    required this.athleteId,
    required this.athlete,
  });

  @override
  State<AthleteDetailsScreen> createState() => _AthleteDetailsScreenState();
}

class _AthleteDetailsScreenState extends State<AthleteDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;

  List<Assignment> _assignments = [];
  List<Activity> _activities = [];
  bool _loadingAssignments = true;
  bool _loadingActivities = true;
  String? _error;

  bool _popupOpen = false;
  bool _popupEditing = false;
  Assignment? _popupAssignment;
  late TextEditingController _ctrlType, _ctrlDist, _ctrlTime, _ctrlNotes;

  int? _matchedDuration(Assignment a) {
    final day = _dayKey(a.scheduledDate);
    final total = _activities
        .where((act) => act.localDateKey == day)
        .fold(0, (s, act) => s + (act.durationMin ?? 0));
    return total > 0 ? total : null;
  }

  // ─── Colors ─────────────────────────────────────────────────────────────────
  static const Color _blue   = Color(0xFF2575FC);
  static const Color _purple = Color(0xFF6A11CB);
  static const Color _bgGrey = Color(0xFFF0F2F5);
  static const Color _dark   = Color(0xFF2C3E50);
  static const Color _medium = Color(0xFF7F8C8D);
  static const Color _green  = Color(0xFF2ECC71);
  static const Color _orange = Color(0xFFF7941D);
  static const Color _red    = Color(0xFFE74C3C);
  static const Color _cardBg = Colors.white;

  static const LinearGradient _blueGradient = LinearGradient(
    colors: [_blue, _purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _tabIndex = _tabController.index);
        }
      });
    _ctrlType  = TextEditingController();
    _ctrlDist  = TextEditingController();
    _ctrlTime  = TextEditingController();
    _ctrlNotes = TextEditingController();
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ctrlType.dispose();
    _ctrlDist.dispose();
    _ctrlTime.dispose();
    _ctrlNotes.dispose();
    super.dispose();
  }

  // ─── API ────────────────────────────────────────────────────────────────────

  Future<String?> _getToken() async {
    final data = await AuthStorageService.getAuthData();
    return data['authToken'];
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchAssignments(), _fetchActivities()]);
  }

  Future<void> _fetchAssignments() async {
    setState(() => _loadingAssignments = true);
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/assignments/athlete/${widget.athleteId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _assignments = data.map((e) => Assignment.fromJson(e)).toList();
          _assignments.sort((a, b) =>
              (_dayKey(b.scheduledDate)).compareTo(_dayKey(a.scheduledDate)));
        });
      } else {
        setState(() => _error = 'Failed to load assignments (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loadingAssignments = false);
    }
  }

  Future<void> _fetchActivities() async {
    setState(() => _loadingActivities = true);
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/activities/athlete/${widget.athleteId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        final allActivities = data.map((e) => Activity.fromJson(e)).toList();
        final seen   = <String>{};
        final deduped = <Activity>[];
        for (final a in allActivities) {
          final key = (a.stravaId != null && a.stravaId!.isNotEmpty)
              ? 'strava_${a.stravaId}'
              : 'id_${a.id}_${a.date}';
          if (seen.add(key)) deduped.add(a);
        }
        setState(() => _activities = deduped);
      }
    } catch (e) {
      debugPrint('Activities fetch error: $e');
    } finally {
      setState(() => _loadingActivities = false);
    }
  }

  Future<void> _updateAssignment(BuildContext dialogContext) async {
    if (_popupAssignment == null) return;
    try {
      final token = await _getToken();
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/assignments/${_popupAssignment!.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'workoutType': _ctrlType.text,
          'distance':    double.tryParse(_ctrlDist.text),
          'duration':    int.tryParse(_ctrlTime.text),
          'instructions': _ctrlNotes.text,
        }),
      );
      await _fetchAssignments();
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      _toast('Saved', 'Assignment updated', color: _green);
    } catch (e) {
      _toast('Error', e.toString(), color: _red);
    }
    setState(() {
      _popupOpen       = false;
      _popupEditing    = false;
      _popupAssignment = null;
    });
  }

  Future<void> _deleteAssignment(String id) async {
    final confirmed = await _showConfirmDialog('Delete Workout?', 'This cannot be undone.');
    if (!confirmed) return;
    try {
      final token = await _getToken();
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/assignments/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() => _assignments.removeWhere((a) => a.id == id));
        _toast('Deleted', 'Workout removed', color: _green);
      } else {
        _toast('Error', 'Delete failed (${res.statusCode})', color: _red);
      }
    } catch (e) {
      _toast('Error', e.toString(), color: _red);
    }
  }

  // ─── Open the assign sheet (same one used from the dashboard tile) ──────────
  void _openAssignSheet() {
    AssignWorkoutBottomSheet.show(
      context,
      athleteId:   widget.athleteId,
      athleteName: widget.athlete.name,
      onAssigned:  () {
        // Refresh assignments after a new one is created
        _fetchAssignments();
      },
    );
  }

  // ─── Derived data ────────────────────────────────────────────────────────────

  List<Assignment> get _filteredAssignments => _assignments
      .where((a) => a.status == 'scheduled' || a.status == 'completed')
      .toList();

  Set<String> get _activityDays => _activities
      .map((a) => a.localDateKey)
      .where((k) => k.isNotEmpty)
      .toSet();

  bool _isCompleted(Assignment a) {
    if (a.status == 'completed') return true;
    final assigned = a.distance ?? 0;
    final logged   = _matchedKm(a);
    if (assigned <= 0) return _activityDays.contains(_dayKey(a.scheduledDate));
    return logged >= assigned * 0.80;
  }

  double _matchedKm(Assignment a) {
    final day = _dayKey(a.scheduledDate);
    return _activities
        .where((act) => act.localDateKey == day)
        .fold(0.0, (s, act) => s + (act.distanceKm ?? 0));
  }

  int _progressPct(Assignment a) {
    final assigned = a.distance ?? 0;
    final logged   = _matchedKm(a);
    if (assigned <= 0) return logged > 0 ? 100 : 0;
    return ((logged / assigned) * 100).round().clamp(0, 100);
  }

  // ─── UI helpers ──────────────────────────────────────────────────────────────

  void _toast(String title, String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(message),
        ],
      ),
      backgroundColor: color ?? Colors.grey[800],
      duration: const Duration(seconds: 3),
    ));
  }

  Future<bool> _showConfirmDialog(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error))),
        ],
      ),
    ) ??
        false;
  }

  bool _isDeletable(Assignment a) {
    if (a.status == 'completed') return false;
    final day   = _dayKey(a.scheduledDate);
    final today = _dayKey(DateTime.now());
    return day.compareTo(today) >= 0;
  }

  void _openPopup(Assignment a) {
    _popupAssignment = a;
    _ctrlType.text  = a.workoutType ?? '';
    _ctrlDist.text  = a.distance?.toString() ?? '';
    _ctrlTime.text  = a.duration?.toString() ?? '';
    _ctrlNotes.text = a.instructions ?? '';
    setState(() {
      _popupOpen    = true;
      _popupEditing = false;
    });
    showDialog(
      context: context,
      builder: (dialogContext) => _WorkoutDetailDialog(
        assignment:   a,
        ctrlType:     _ctrlType,
        ctrlDist:     _ctrlDist,
        ctrlTime:     _ctrlTime,
        ctrlNotes:    _ctrlNotes,
        isEditing:    _popupEditing,
        onToggleEdit: () => setState(() => _popupEditing = !_popupEditing),
        onSave:       () => _updateAssignment(dialogContext),
        blueGradient: _blueGradient,
        dark:         _dark,
        blue:         _blue,
      ),
    ).then((_) => setState(() {
      _popupOpen       = false;
      _popupEditing    = false;
      _popupAssignment = null;
    }));
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.athlete.name,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: _dark, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _medium),
            onPressed: _fetchData,
          ),
        ],
      ),

      // ── Floating Assign Workout button ──────────────────────────────────────
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _openAssignSheet,
      //   backgroundColor: _blue,
      //   elevation: 3,
      //   icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
      //   label: Text(
      //     'Assign Workout',
      //     style: GoogleFonts.poppins(
      //       color: Colors.white,
      //       fontWeight: FontWeight.w700,
      //       fontSize: 13,
      //     ),
      //   ),
      // ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: SingleChildScrollView(
        // Extra bottom padding so the FAB never covers content
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Athlete header ──────────────────────────────────────────────
            _AthleteHeaderCard(
              athlete: widget.athlete,
              blue:    _blue,
              dark:    _dark,
              medium:  _medium,
              onAssign: _openAssignSheet, // ← also wired to the header button
            ),
            const SizedBox(height: 16),

            // ── Summary row ─────────────────────────────────────────────────
            _SummaryRow(
              assignments: _filteredAssignments,
              activities:  _activities,
              blue:        _blue,
              green:       _green,
              dark:        _dark,
              medium:      _medium,
              isCompleted: _isCompleted,
            ),
            const SizedBox(height: 16),

            // ── Tabs ────────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10)
                ],
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor:            _blue,
                    unselectedLabelColor:  _medium,
                    indicatorColor:        _blue,
                    labelStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                    tabs: const [
                      Tab(text: 'Workouts'),
                      Tab(text: 'Calendar'),
                      Tab(text: 'Profile'),
                    ],
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _tabIndex == 0
                        ? _WorkoutsTab(
                      assignments:     _filteredAssignments,
                      loading:         _loadingAssignments,
                      error:           _error,
                      isCompleted:     _isCompleted,
                      matchedKm:       _matchedKm,
                      progressPct:     _progressPct,
                      isDeletable:     _isDeletable,
                      onViewDetails:   _openPopup,
                      onDelete:        _deleteAssignment,
                      athleteName:     widget.athlete.name,
                      blue:            _blue,
                      green:           _green,
                      orange:          _orange,
                      red:             _red,
                      dark:            _dark,
                      medium:          _medium,
                      blueGradient:    _blueGradient,
                      matchedDuration: _matchedDuration,
                      onAssign:        _openAssignSheet, // ← empty-state button
                    )
                        : _tabIndex == 1
                        ? _CalendarTab(
                      athlete:   widget.athlete,
                      athleteId: widget.athleteId,
                    )
                        : _ProfileTab(
                      athlete: widget.athlete,
                      dark:    _dark,
                      medium:  _medium,
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
}

// ─── Athlete Header Card ──────────────────────────────────────────────────────

class _AthleteHeaderCard extends StatelessWidget {
  final Athlete athlete;
  final Color blue, dark, medium;
  final VoidCallback onAssign;

  const _AthleteHeaderCard({
    required this.athlete,
    required this.blue,
    required this.dark,
    required this.medium,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final initials = athlete.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [blue, const Color(0xFF6A11CB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name / plan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      athlete.name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: dark),
                    ),
                    Text(
                      '${athlete.plan} • ${athlete.experience} level',
                      style: GoogleFonts.poppins(fontSize: 13, color: medium),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Since ${DateFormat('MMM yyyy').format(DateTime.tryParse(athlete.createdAt) ?? DateTime.now())}',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: blue,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Assign Workout button (prominent, full-width in the card) ──────
          // SizedBox(
          //   width: double.infinity,
          //   child: ElevatedButton.icon(
          //     onPressed: onAssign,
          //     icon: const Icon(Icons.add_task_rounded,
          //         size: 18, color: Colors.white),
          //     label: Text(
          //       'Assign Workout',
          //       style: GoogleFonts.poppins(
          //         fontWeight: FontWeight.w700,
          //         fontSize: 14,
          //         color: Colors.white,
          //       ),
          //     ),
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: blue,
          //       padding: const EdgeInsets.symmetric(vertical: 13),
          //       shape: RoundedRectangleBorder(
          //           borderRadius: BorderRadius.circular(10)),
          //       elevation: 0,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

// ─── Summary Row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final List<Assignment> assignments;
  final List<Activity> activities;
  final Color blue, green, dark, medium;
  final bool Function(Assignment) isCompleted;

  const _SummaryRow({
    required this.assignments,
    required this.activities,
    required this.blue,
    required this.green,
    required this.dark,
    required this.medium,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final now       = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekEnd   = weekStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    bool inWeek(String? ds) {
      if (ds == null || ds.isEmpty) return false;
      final d = _parseDate(ds);
      if (d == null) return false;
      final dLocal =
      DateTime(d.toLocal().year, d.toLocal().month, d.toLocal().day);
      return !dLocal.isBefore(weekStart) &&
          !dLocal.isAfter(
              DateTime(weekEnd.year, weekEnd.month, weekEnd.day));
    }

    final weekAssign = assignments.where((a) => inWeek(a.scheduledDate));
    final weekAct    = activities.where((a) => inWeek(a.date ?? a.createdAt));

    final totalKm = weekAssign.fold(0.0, (s, a) => s + (a.distance ?? 0));
    final doneKm  = weekAct.fold(0.0, (s, a) => s + (a.distanceKm ?? 0));

    final completed = assignments.where((a) => isCompleted(a)).length;
    final scheduled = assignments.where((a) => !isCompleted(a)).length;

    return Row(
      children: [
        _SummaryTile(
          'This Week',
          '${doneKm.toStringAsFixed(1)} / ${totalKm.toStringAsFixed(1)} km',
          'Distance',
          blue,
          dark,
          medium,
        ),
        const SizedBox(width: 12),
        _SummaryTile('Completed', '$completed', 'Workouts', green, dark, medium),
        const SizedBox(width: 12),
        _SummaryTile(
            'Scheduled', '$scheduled', 'Upcoming', Colors.orange, dark, medium),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value, sub;
  final Color accent, dark, medium;
  const _SummaryTile(
      this.label, this.value, this.sub, this.accent, this.dark, this.medium);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: medium,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent)),
            Text(sub,
                style: GoogleFonts.poppins(fontSize: 11, color: medium)),
          ],
        ),
      ),
    );
  }
}

// ─── Workouts Tab ─────────────────────────────────────────────────────────────

class _WorkoutsTab extends StatelessWidget {
  final List<Assignment> assignments;
  final bool loading;
  final String? error;
  final bool Function(Assignment) isCompleted;
  final double Function(Assignment) matchedKm;
  final int Function(Assignment) progressPct;
  final bool Function(Assignment) isDeletable;
  final void Function(Assignment) onViewDetails;
  final void Function(String) onDelete;
  final String athleteName;
  final Color blue, green, orange, red, dark, medium;
  final LinearGradient blueGradient;
  final int? Function(Assignment) matchedDuration;
  final VoidCallback onAssign; // ← for empty-state CTA

  const _WorkoutsTab({
    required this.assignments,
    required this.loading,
    required this.error,
    required this.isCompleted,
    required this.matchedKm,
    required this.progressPct,
    required this.isDeletable,
    required this.onViewDetails,
    required this.onDelete,
    required this.athleteName,
    required this.blue,
    required this.green,
    required this.orange,
    required this.red,
    required this.dark,
    required this.medium,
    required this.blueGradient,
    required this.matchedDuration,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ));
    }

    if (error != null) {
      return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: red, size: 40),
                const SizedBox(height: 8),
                Text(error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: red)),
              ],
            ),
          ));
    }

    final scheduledList = assignments.where((a) => !isCompleted(a)).toList();
    final completedList = assignments.where((a) => isCompleted(a)).toList();

    if (assignments.isEmpty) {
      // ── Empty state with assign CTA ─────────────────────────────────
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.directions_run, size: 48, color: medium),
              const SizedBox(height: 12),
              Text(
                'No workouts assigned yet',
                style: GoogleFonts.poppins(
                    color: medium, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.add_task_rounded,
                    size: 16, color: Colors.white),
                label: Text(
                  'Assign First Workout',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        // In _WorkoutsTab build(), replace the header Row with this:

        Row(
          children: [
            const Icon(Icons.directions_run, size: 20),
            const SizedBox(width: 8),
            Text(
              'Workout Schedule',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: dark),
            ),
            const Spacer(), // ← pushes button to the right
            ElevatedButton.icon(
              onPressed: onAssign,
              icon: const Icon(Icons.add_task_rounded,
                  size: 14, color: Colors.white),
              label: Text(
                'Assign',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        Text(
          'Assigned & logged workouts for $athleteName',
          style: GoogleFonts.poppins(fontSize: 12, color: medium),
        ),
        const SizedBox(height: 16),

        // Scheduled section
        if (scheduledList.isNotEmpty) ...[
          _SectionHeader(
              label: 'Scheduled',
              count: scheduledList.length,
              color: blue),
          const SizedBox(height: 8),
          ...scheduledList.map((a) => _AssignmentCard(
            assignment:      a,
            completed:       false,
            matched:         matchedKm(a),
            pct:             progressPct(a),
            deletable:       isDeletable(a),
            onView:          () => onViewDetails(a),
            onDelete:        () => onDelete(a.id),
            blue:            blue,
            green:           green,
            orange:          orange,
            red:             red,
            dark:            dark,
            medium:          medium,
            matchedDuration: matchedDuration(a),
          )),
          const SizedBox(height: 20),
        ],

        // Completed section
        if (completedList.isNotEmpty) ...[
          _SectionHeader(
              label: 'Completed',
              count: completedList.length,
              color: green),
          const SizedBox(height: 8),
          ...completedList.map((a) => _AssignmentCard(
            assignment:      a,
            completed:       true,
            matched:         matchedKm(a),
            pct:             progressPct(a),
            deletable:       false,
            onView:          () => onViewDetails(a),
            onDelete:        () {},
            blue:            blue,
            green:           green,
            orange:          orange,
            red:             red,
            dark:            dark,
            medium:          medium,
            matchedDuration: matchedDuration(a),
          )),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: const Color(0xFF2C3E50))),
        const SizedBox(width: 8),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Assignment Card ──────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final bool completed;
  final double matched;
  final int pct;
  final bool deletable;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final Color blue, green, orange, red, dark, medium;
  final int? matchedDuration;

  const _AssignmentCard({
    required this.assignment,
    required this.completed,
    required this.matched,
    required this.pct,
    required this.deletable,
    required this.onView,
    required this.onDelete,
    required this.blue,
    required this.green,
    required this.orange,
    required this.red,
    required this.dark,
    required this.medium,
    this.matchedDuration,
  });

  @override
  Widget build(BuildContext context) {
    final assigned      = assignment.distance ?? 0.0;
    final Color accent  = completed ? green : blue;
    final Color progressColor =
    pct >= 100 ? green : pct >= 60 ? orange : red;

    final date    = DateTime.tryParse(assignment.scheduledDate ?? '');
    final dateStr = date != null
        ? DateFormat('EEE, MMM d, yyyy').format(date)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completed
              ? green.withOpacity(0.4)
              : blue.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              assignment.workoutType ?? 'Workout',
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: dark),
                            ),
                          ),
                          // _StatusBadge(
                          //     label: completed ? 'Completed' : 'Scheduled',
                          //     color: accent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 13, color: medium),
                          const SizedBox(width: 4),
                          Text(dateStr,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: medium)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 14,
                        children: [
                          if (assignment.distance != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.place_outlined,
                                    size: 13, color: medium),
                                const SizedBox(width: 3),
                                Text(
                                    '${assignment.distance!.toStringAsFixed(1)} km',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: medium)),
                              ],
                            ),
                          if (assignment.duration != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time,
                                    size: 13, color: medium),
                                const SizedBox(width: 3),
                                Text('${assignment.duration} min',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: medium)),
                              ],
                            ),
                          Builder(builder: (_) {
                            final assignedPace = _formatPace(
                                assignment.distance, assignment.duration);
                            final loggedPace = (completed && matched > 0)
                                ? _formatPace(matched,
                                matchedDuration ?? assignment.duration)
                                : null;
                            if (assignedPace == null && loggedPace == null) {
                              return const SizedBox.shrink();
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.speed_outlined,
                                    size: 13, color: medium),
                                const SizedBox(width: 3),
                                if (assignedPace != null)
                                  Text(assignedPace,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: medium)),
                                if (assignedPace != null && loggedPace != null)
                                  Text(' → ',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: medium)),
                                if (loggedPace != null)
                                  Text(loggedPace,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: green,
                                          fontWeight: FontWeight.w600)),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$pct%',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: progressColor)),
                    Text(
                        '${matched.toStringAsFixed(1)} / ${assigned.toStringAsFixed(1)} km',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: medium)),
                  ],
                ),
              ],
            ),
            if (assignment.instructions != null &&
                assignment.instructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(assignment.instructions!,
                  style:
                  GoogleFonts.poppins(fontSize: 12, color: medium)),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value:           (pct / 100).clamp(0.0, 1.0),
                minHeight:       6,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!completed)
                  _ActionButton(
                    label:     'View Details',
                    onTap:     onView,
                    color:     Colors.grey.shade100,
                    textColor: dark,
                  ),
                if (deletable) ...[
                  const SizedBox(width: 8),
                  _ActionButton(
                    label:     'Delete',
                    onTap:     onDelete,
                    color:     red.withOpacity(0.1),
                    textColor: red,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color, textColor;
  const _ActionButton(
      {required this.label,
        required this.onTap,
        required this.color,
        required this.textColor});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor)),
      ),
    );
  }
}

// ─── Workout Detail Dialog ────────────────────────────────────────────────────

class _WorkoutDetailDialog extends StatefulWidget {
  final Assignment assignment;
  final TextEditingController ctrlType, ctrlDist, ctrlTime, ctrlNotes;
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final LinearGradient blueGradient;
  final Color dark, blue;

  const _WorkoutDetailDialog({
    required this.assignment,
    required this.ctrlType,
    required this.ctrlDist,
    required this.ctrlTime,
    required this.ctrlNotes,
    required this.isEditing,
    required this.onToggleEdit,
    required this.onSave,
    required this.blueGradient,
    required this.dark,
    required this.blue,
  });

  @override
  State<_WorkoutDetailDialog> createState() => _WorkoutDetailDialogState();
}

class _WorkoutDetailDialogState extends State<_WorkoutDetailDialog> {
  late bool _editing;

  @override
  void initState() {
    super.initState();
    _editing = widget.isEditing;
  }

  @override
  Widget build(BuildContext context) {
    final date    = DateTime.tryParse(widget.assignment.scheduledDate ?? '');
    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date) : '—';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Workout — $dateStr',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: widget.dark),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                        _editing ? Icons.close : Icons.edit,
                        color: widget.blue),
                    onPressed: () => setState(() => _editing = !_editing),
                  ),
                ],
              ),
              const Divider(height: 24),
              _dialogField('Workout Type', widget.ctrlType,
                  readOnly: !_editing),
              _dialogField('Distance (km)', widget.ctrlDist,
                  readOnly: !_editing,
                  keyboardType: TextInputType.number),
              _dialogField('Duration (min)', widget.ctrlTime,
                  readOnly: !_editing,
                  keyboardType: TextInputType.number),
              _dialogField('Instructions', widget.ctrlNotes,
                  readOnly: !_editing, maxLines: 3),
              const SizedBox(height: 16),
              if (_editing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.blue,
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Save Changes',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Close',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
      String label,
      TextEditingController ctrl, {
        bool readOnly = false,
        TextInputType keyboardType = TextInputType.text,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7F8C8D))),
          const SizedBox(height: 4),
          TextField(
            controller:    ctrl,
            readOnly:      readOnly,
            keyboardType:  keyboardType,
            maxLines:      maxLines,
            decoration: InputDecoration(
              filled:    true,
              fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  BorderSide(color: widget.blue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Calendar Tab ─────────────────────────────────────────────────────────────

class _CalendarTab extends StatelessWidget {
  final Athlete athlete;
  final String athleteId;

  const _CalendarTab({required this.athlete, required this.athleteId});

  @override
  Widget build(BuildContext context) {
    return CoachAthleteCalendar(
      athleteId:   athleteId,
      athleteName: athlete.name,
    );
  }
}

// ─── Profile Tab ──────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final Athlete athlete;
  final Color dark, medium;
  const _ProfileTab(
      {required this.athlete, required this.dark, required this.medium});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoSection('Personal', [
          _row('Email',        athlete.email,                    medium, dark),
          _row('Role',         athlete.role ?? 'Athlete',        medium, dark),
          _row('Date of Birth',athlete.dateOfBirth?.toString() ?? 'N/A', medium, dark),
          _row('City',         athlete.city ?? 'N/A',            medium, dark),
        ]),
        const SizedBox(height: 16),
        _infoSection('Training', [
          _row('Plan',       athlete.plan,       medium, dark),
          _row('Experience', athlete.experience, medium, dark),
        ]),
      ],
    );
  }

  Widget _infoSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: dark)),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _row(String label, String value, Color medium, Color dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 12, color: medium)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: dark)),
          ),
        ],
      ),
    );
  }
}