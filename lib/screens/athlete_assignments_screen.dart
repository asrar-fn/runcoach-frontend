// lib/screens/athlete_assignments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/assignment_service.dart';
import '../services/auth_storage_service.dart';
import '../config/api_config.dart';

class AthleteAssignmentsScreen extends StatefulWidget {
  final String athleteId;

  /// Optionally pass activities from AppState to avoid an extra network call.
  /// If null, the screen fetches them itself.
  final List<Map<String, dynamic>>? activities;

  const AthleteAssignmentsScreen({
    super.key,
    required this.athleteId,
    this.activities,
  });

  @override
  State<AthleteAssignmentsScreen> createState() =>
      _AthleteAssignmentsScreenState();
}

class _AthleteAssignmentsScreenState extends State<AthleteAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _assignments = [];
  // Internal activities list — populated either from widget.activities or fetched
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;

  // ── helpers ────────────────────────────────────────────────────────────────

  bool _isPast(String? dateStr) {
    if (dateStr == null) return false;
    final d = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final scheduledLocalDate = DateTime(d.year, d.month, d.day);
    final todayLocalDate = DateTime(now.year, now.month, now.day);

    // Strictly before today → always past
    if (scheduledLocalDate.isBefore(todayLocalDate)) return true;

    // Scheduled for TODAY → treat as past only if an activity was already
    // logged on this day (so the card moves to the Past tab as Completed).
    if (scheduledLocalDate == todayLocalDate) {
      return _activityForDate(dateStr) != null;
    }

    // Future date → upcoming
    return false;
  }

  /// Extract the local calendar date (yyyy-MM-dd) from a raw date string.
  String _localDateKey(String raw) {
    final d = DateTime.parse(raw).toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// Returns ALL activities logged on the same LOCAL calendar day as [dateStr].
  /// Compares local date strings (yyyy-MM-dd) so UTC midnight stored in the DB
  /// doesn't shift the day when the device is in IST (UTC+5:30).
  List<Map<String, dynamic>> _activitiesForDate(String? dateStr) {
    if (dateStr == null) return [];
    final assignedKey = _localDateKey(dateStr);
    return _activities.where((act) {
      final raw = act['date'] ?? act['createdAt'];
      if (raw == null) return false;
      return _localDateKey(raw.toString()) == assignedKey;
    }).toList();
  }

  // Convenience: returns first match or null (used by _isPast)
  Map<String, dynamic>? _activityForDate(String? dateStr) {
    final list = _activitiesForDate(dateStr);
    return list.isEmpty ? null : list.first;
  }

  // ── grouped lists ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _upcoming => _assignments
      .where((a) => !_isPast(a['scheduledDate']))
      .toList()
    ..sort((a, b) => DateTime.parse(a['scheduledDate']).toLocal()
        .compareTo(DateTime.parse(b['scheduledDate']).toLocal()));

  List<Map<String, dynamic>> get _past => _assignments
      .where((a) => _isPast(a['scheduledDate']))
      .toList()
    ..sort((a, b) => DateTime.parse(b['scheduledDate']).toLocal()
        .compareTo(DateTime.parse(a['scheduledDate']).toLocal()));

  // ── lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Seed with parent-provided activities immediately (avoids flicker)
    if (widget.activities != null) {
      _activities = List.from(widget.activities!);
    }
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Fetches assignments AND activities in parallel so matching always works.
  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Run both fetches concurrently
      await Future.wait([
        _fetchAssignments(),
        _fetchActivitiesInternal(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAssignments() async {
    final data =
    await AssignmentService.getAssignmentsByAthlete(widget.athleteId);
    if (mounted) setState(() => _assignments = data);
  }

  /// Fetches the athlete's activities directly from the API.
  /// Falls back to [widget.activities] if the request fails.
  Future<void> _fetchActivitiesInternal() async {
    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/activities/athlete/${widget.athleteId}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final fetched =
        data.map((e) => Map<String, dynamic>.from(e)).toList();
        if (mounted) setState(() => _activities = fetched);
      }
    } catch (_) {
      // Keep whatever was seeded from widget.activities
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.background,
      appBar: AppBar(
        title: Text('Scheduled Workouts',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: cs.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.5),
          indicatorColor: cs.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upcoming_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Upcoming (${_upcoming.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('Past (${_past.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? _buildError()
          : _assignments.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
        onRefresh: _fetchAssignments,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAssignmentList(_upcoming, isUpcoming: true),
            _buildAssignmentList(_past, isUpcoming: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentList(List<Map<String, dynamic>> items,
      {required bool isUpcoming}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming ? Icons.event_available : Icons.history,
              size: 56,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            Text(
              isUpcoming ? 'No upcoming workouts' : 'No past workouts',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final assignment = items[index];
        final isPast = !isUpcoming;
        final loggedActivities = isPast
            ? _activitiesForDate(assignment['scheduledDate'])
            : <Map<String, dynamic>>[];

        return _AssignmentCard(
          assignment: assignment,
          isPast: isPast,
          loggedActivities: loggedActivities,
        );
      },
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center,
              size: 72, color: cs.onSurface.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text('No workouts assigned yet',
              style: tt.titleMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.4))),
          const SizedBox(height: 8),
          Text('Your coach will assign workouts here',
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurface.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: cs.error, size: 48),
          const SizedBox(height: 12),
          Text(_errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchAssignments,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Individual Assignment Card ───────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final bool isPast;

  /// All activities logged on the same day as this assignment.
  final List<Map<String, dynamic>> loggedActivities;

  const _AssignmentCard({
    required this.assignment,
    required this.isPast,
    this.loggedActivities = const [],
  });

  // ── derived state ──────────────────────────────────────────────────────────

  bool get _isCompleted => isPast && loggedActivities.isNotEmpty;
  bool get _isMissed => isPast && loggedActivities.isEmpty;

  Color _typeColor(String type, ColorScheme cs) {
    switch (type.toLowerCase()) {
      case 'tempo run':
        return const Color(0xFFE53935);
      case 'interval training':
        return const Color(0xFFE65100);
      case 'long run':
        return const Color(0xFF1565C0);
      case 'easy run':
        return const Color(0xFF2E7D32);
      case 'recovery run':
        return const Color(0xFF00695C);
      case 'hill repeats':
        return const Color(0xFF6A1B9A);
      case 'race pace':
        return const Color(0xFFC62828);
      default:
        return cs.primary;
    }
  }

  String? _formatPace(double? distanceKm, int? durationMin) {
    if (distanceKm == null || distanceKm <= 0) return null;
    if (durationMin == null || durationMin <= 0) return null;
    final paceDecimal = durationMin / distanceKm;
    final paceMinutes = paceDecimal.floor();
    final paceSeconds = ((paceDecimal - paceMinutes) * 60).round();
    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')} /km';
  }

  /// Parse a value that might be a String or a num.
  double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());
  int? _toInt(dynamic v) =>
      v == null ? null : int.tryParse(v.toString());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final String workoutType = assignment['workoutType'] ?? 'Workout';
    final String title =
        assignment['title'] ?? assignment['workoutType'] ?? 'Workout';
    final String distance = assignment['distance']?.toString() ?? '';
    final String duration = assignment['duration']?.toString() ?? '';
    final String instructions = assignment['instructions'] ?? '';
    final String targetPace = _formatPace(
      _toDouble(assignment['distance']),
      _toInt(assignment['duration']),
    ) ??
        (assignment['targetPace'] ?? '');
    final String? dateStr = assignment['scheduledDate'];
    final typeColor = _typeColor(workoutType, cs);

    // ── status colours ───────────────────────────────────────────────────────
    final Color statusColor = _isCompleted
        ? const Color(0xFF2E7D32)
        : _isMissed
        ? const Color(0xFFC62828)
        : typeColor;

    String formattedDate = '';
    if (dateStr != null) {
      try {
        formattedDate =
            DateFormat('EEE, MMM d').format(DateTime.parse(dateStr));
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPast
              ? statusColor.withOpacity(0.3)
              : typeColor.withOpacity(0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: _isMissed ? 0.75 : 1.0,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          workoutType,
                          style:
                          tt.bodySmall?.copyWith(color: typeColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Date pill
                  if (formattedDate.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        formattedDate,
                        style: tt.labelSmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // Status badge (completed / missed) — only for past
                  if (isPast) ...[
                    const SizedBox(width: 6),
                    _StatusBadge(
                      isCompleted: _isCompleted,
                      color: statusColor,
                    ),
                  ],
                ],
              ),
            ),

            // ── Assigned stats row ───────────────────────────────────────────
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label
                  if (isPast)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Assigned',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.45),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      if (distance.isNotEmpty) ...[
                        _StatChip(
                          icon: Icons.straighten,
                          label: '$distance km',
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (duration.isNotEmpty) ...[
                        _StatChip(
                          icon: Icons.timer_outlined,
                          label: '$duration min',
                          color: cs.secondary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (targetPace.isNotEmpty)
                        _StatChip(
                          icon: Icons.speed,
                          label: targetPace,
                          color: const Color(0xFF6A1B9A),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Logged stats (completed only — one row per activity) ─────────
            if (_isCompleted) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                child: Divider(height: 1, color: cs.onSurface.withOpacity(0.08)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loggedActivities.length == 1
                          ? 'Logged by athlete'
                          : 'Logged by athlete (${loggedActivities.length} activities)',
                      style: tt.labelSmall?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // One row per logged activity
                    ...loggedActivities.asMap().entries.map((entry) {
                      final i = entry.key;
                      final act = entry.value;
                      final double? dist = _toDouble(
                          act['distanceKm'] ?? act['distance']);
                      final int? dur = _toInt(
                          act['durationMin'] ?? act['duration']);
                      final String? pace = _formatPace(dist, dur);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (loggedActivities.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Activity ${i + 1}',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurface.withOpacity(0.45),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              if (dist != null) ...[
                                _StatChip(
                                  icon: Icons.straighten,
                                  label: '${dist.toStringAsFixed(2)} km',
                                  color: const Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (dur != null) ...[
                                _StatChip(
                                  icon: Icons.timer_outlined,
                                  label: '$dur min',
                                  color: const Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (pace != null)
                                _StatChip(
                                  icon: Icons.speed,
                                  label: pace,
                                  color: const Color(0xFF2E7D32),
                                ),
                            ],
                          ),
                          if (i < loggedActivities.length - 1)
                            const SizedBox(height: 8),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],

            // ── Missed banner ────────────────────────────────────────────────
            if (_isMissed)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFC62828).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined,
                        size: 16, color: Color(0xFFC62828)),
                    const SizedBox(width: 8),
                    Text(
                      'Workout missed — no activity logged on this day',
                      style: tt.bodySmall?.copyWith(
                        color: const Color(0xFFC62828),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Instructions ─────────────────────────────────────────────────
            if (instructions.isNotEmpty)
              Padding(
                padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded,
                          size: 15,
                          color: cs.onSurface.withOpacity(0.4)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          instructions,
                          style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.6)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge widget ──────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isCompleted;
  final Color color;

  const _StatusBadge({required this.isCompleted, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted ? 'Completed' : 'Missed',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}