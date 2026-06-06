// lib/screens/athlete_assignments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/assignment_service.dart';

class AthleteAssignmentsScreen extends StatefulWidget {
  final String athleteId;

  const AthleteAssignmentsScreen({super.key, required this.athleteId});

  @override
  State<AthleteAssignmentsScreen> createState() =>
      _AthleteAssignmentsScreenState();
}

class _AthleteAssignmentsScreenState extends State<AthleteAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  late TabController _tabController;

  // Group assignments by status relative to today
  List<Map<String, dynamic>> get _upcoming => _assignments
      .where((a) => !_isPast(a['scheduledDate']))
      .toList()
    ..sort((a, b) =>
        DateTime.parse(a['scheduledDate'])
            .compareTo(DateTime.parse(b['scheduledDate'])));

  List<Map<String, dynamic>> get _past => _assignments
      .where((a) => _isPast(a['scheduledDate']))
      .toList()
    ..sort((a, b) =>
        DateTime.parse(b['scheduledDate'])
            .compareTo(DateTime.parse(a['scheduledDate'])));

  bool _isPast(String? dateStr) {
    if (dateStr == null) return false;
    return DateTime.parse(dateStr).isBefore(
        DateTime.now().subtract(const Duration(hours: 1)));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAssignments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssignments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final data =
      await AssignmentService.getAssignmentsByAthlete(widget.athleteId);
      setState(() {
        _assignments = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

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
      itemBuilder: (context, index) =>
          _AssignmentCard(assignment: items[index], isPast: !isUpcoming),
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

  const _AssignmentCard({
    required this.assignment,
    required this.isPast,
  });

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final String workoutType = assignment['workoutType'] ?? 'Workout';
    final String title =
        assignment['title'] ?? assignment['workoutType'] ?? 'Workout';
    final String distance = assignment['distance'] ?? '';
    final String duration = assignment['duration'] ?? '';
    final String instructions = assignment['instructions'] ?? '';
    final String targetPace = assignment['targetPace'] ?? '';
    final String? dateStr = assignment['scheduledDate'];
    final typeColor = _typeColor(workoutType, cs);

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
              ? cs.onSurface.withOpacity(0.08)
              : typeColor.withOpacity(0.25),
          width: 1.2,
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
        opacity: isPast ? 0.65 : 1.0,
        child: Column(
          children: [
            // ── Color stripe + header ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.08),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeColor,
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
                          style: tt.bodySmall?.copyWith(color: typeColor),
                        ),
                      ],
                    ),
                  ),
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
                ],
              ),
            ),

            // ── Stats row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
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
            ),

            // ── Instructions ─────────────────────────────────────────
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