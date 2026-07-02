// lib/widgets/athlete_performance_tile.dart

import 'package:flutter/material.dart';
import '../services/athlete_performance_service.dart';
import '../models/athlete.dart';

const _kPrimaryText   = Color(0xFF1A1A2E);
const _kSecondaryText = Color(0xFF6B7280);
const _kBlueBar       = Color(0xFF2575FC);
const _kBorderColor   = Color(0xFFE5E7EB);

class AthletePerformanceTile extends StatefulWidget {
  final Athlete athlete;
  final AthletePerformanceService performanceService;
  final VoidCallback onTap;
  final VoidCallback onAssign;
  final VoidCallback onMessage;
  final int unreadCount;
  final int refreshKey;

  const AthletePerformanceTile({
    super.key,
    required this.athlete,
    required this.performanceService,
    required this.onTap,
    required this.onAssign,
    required this.onMessage,
    this.unreadCount = 0,
    this.refreshKey = 0,
  });

  @override
  State<AthletePerformanceTile> createState() => _AthletePerformanceTileState();
}

class _AthletePerformanceTileState extends State<AthletePerformanceTile>
    with SingleTickerProviderStateMixin {
  late Future<AthletePerformanceSummary> _summaryFuture;
  bool _chartExpanded = false;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  void _loadSummary() {
    _summaryFuture = widget.performanceService.getSummary(widget.athlete.id);
  }

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _expandCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant AthletePerformanceTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(_loadSummary);
    }
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggleChart() {
    setState(() => _chartExpanded = !_chartExpanded);
    _chartExpanded ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final tt      = Theme.of(context).textTheme;
    final athlete = widget.athlete;

    final initials = athlete.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join('');

    return FutureBuilder<AthletePerformanceSummary>(
      future: _summaryFuture,
      builder: (context, snap) {
        final summary  = snap.data;
        final loading  = snap.connectionState == ConnectionState.waiting;
        final hasError = snap.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row A: Avatar | Name/email | Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1976D2),
                          child: Text(
                            initials,
                            style: tt.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                athlete.name,
                                style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimaryText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                athlete.email,
                                style: tt.bodySmall?.copyWith(color: _kSecondaryText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (loading)
                          const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF1976D2)),
                          )
                        else if (hasError)
                          const Icon(Icons.error_outline,
                              size: 18, color: Colors.redAccent)
                        else if (summary != null)
                            _PerformanceBadge(summary: summary),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Row B: Plan label | Actions
                    Row(
                      children: [
                        Text(
                          'Plan – ${athlete.plan}',
                          style: tt.bodySmall?.copyWith(
                            color: _kSecondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        // ── Assign Workout chip button ──────────────────
                        GestureDetector(
                          onTap: widget.onAssign,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_task_rounded,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Assign',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onMessage,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: SizedBox(
                              width: 36, height: 36,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      color: widget.unreadCount > 0
                                          ? const Color(0xFF1976D2)
                                          : _kSecondaryText,
                                      size: 20,
                                    ),
                                  ),
                                  if (widget.unreadCount > 0)
                                    Positioned(
                                      right: -4, top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${widget.unreadCount}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            height: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Progress bars
                    if (summary != null) ...[
                      _WeeklyProgressBar(summary: summary),
                      const SizedBox(height: 6),
                    ] else ...[
                      _SimplePlanBar(athlete: athlete),
                      const SizedBox(height: 6),
                    ],

                    // Stats chips + Insights toggle
                    if (summary != null && summary.totalAssignments > 0)
                      _StatsAndToggleRow(
                        summary:       summary,
                        chartExpanded: _chartExpanded,
                        onToggle:      _toggleChart,
                      ),
                  ],
                ),
              ),
            ),

            // Expandable weekly table
            SizeTransition(
              sizeFactor:    _expandAnim,
              axisAlignment: -1,
              child: summary != null
                  ? _PerformanceChart(summary: summary)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

// ── Weekly progress bar ───────────────────────────────────────────────────────

class _WeeklyProgressBar extends StatelessWidget {
  final AthletePerformanceSummary summary;
  const _WeeklyProgressBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final distProg = summary.weekDistanceProgress;
    final timeProg = summary.weekTimeProgress;

    String fmtMin(double min) {
      if (min <= 0) return '–';
      final h = (min ~/ 60);
      final m = (min % 60).round();
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Logged / Assigned Distance\n'
              '${summary.weekLoggedKm.toStringAsFixed(1)} km / '
              '${summary.weekAssignedKm.toStringAsFixed(1)} km',
          triggerMode: TooltipTriggerMode.tap,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           distProg,
                    minHeight:       7,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kBlueBar),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${summary.weekLoggedKm.toStringAsFixed(1)}/'
                    '${summary.weekAssignedKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: _kPrimaryText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (summary.weekAssignedMin > 0) ...[
          const SizedBox(height: 4),
          Tooltip(
            message: 'Logged / Assigned Time\n'
                '${fmtMin(summary.weekLoggedMin)} / ${fmtMin(summary.weekAssignedMin)}',
            triggerMode: TooltipTriggerMode.tap,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           timeProg,
                      minHeight:       5,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6DA4FC)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${fmtMin(summary.weekLoggedMin)} / ${fmtMin(summary.weekAssignedMin)}',
                  style: const TextStyle(
                      color: _kSecondaryText, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 2),
        const Text('This week',
            style: TextStyle(color: _kSecondaryText, fontSize: 10)),
      ],
    );
  }
}

class _SimplePlanBar extends StatelessWidget {
  final Athlete athlete;
  const _SimplePlanBar({required this.athlete});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           athlete.progressPct / 100,
              minHeight:       7,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(_kBlueBar),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${athlete.progressPct}%',
          style: const TextStyle(
              color: _kPrimaryText, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Stats row + Insights toggle ───────────────────────────────────────────────

class _StatsAndToggleRow extends StatelessWidget {
  final AthletePerformanceSummary summary;
  final bool chartExpanded;
  final VoidCallback onToggle;

  const _StatsAndToggleRow({
    required this.summary,
    required this.chartExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final missed = summary.totalAssignments - summary.matchedCount;

    return Row(
      children: [
        _MiniChip(
          label: 'Avg',
          value: '${summary.avgCompletionPct.toStringAsFixed(0)}%',
        ),
        const SizedBox(width: 6),
        _MiniChip(
          label: 'Done',
          value: '${summary.matchedCount}/${summary.totalAssignments}',
        ),
        if (missed > 0) ...[
          const SizedBox(width: 6),
          _MiniChip(label: 'Miss', value: '$missed', isAlert: true),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onToggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                chartExpanded ? 'Hide' : 'Insights',
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w700),
              ),
              AnimatedRotation(
                turns:    chartExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.expand_more,
                    size: 16, color: Color(0xFF1976D2)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isAlert;
  const _MiniChip({
    required this.label,
    required this.value,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFEBEB) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAlert
              ? const Color(0xFFFF5252).withOpacity(0.5)
              : _kBorderColor,
          width: 0.8,
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 10),
          children: [
            TextSpan(
                text: '$label ',
                style: const TextStyle(color: _kSecondaryText)),
            TextSpan(
                text: value,
                style: TextStyle(
                    color: isAlert
                        ? const Color(0xFFE53935)
                        : _kPrimaryText,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Performance badge ─────────────────────────────────────────────────────────

class _PerformanceBadge extends StatelessWidget {
  final AthletePerformanceSummary summary;
  const _PerformanceBadge({required this.summary});

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    late String label;
    late IconData icon;

    switch (summary.level) {
      case PerformanceLevel.excellent:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'Peak Performance';
        icon  = Icons.trending_up_rounded;
        break;
      case PerformanceLevel.good:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        label = 'On Track';
        icon  = Icons.remove_rounded;
        break;
      case PerformanceLevel.needsAttention:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        label = 'Needs Focus';
        icon  = Icons.trending_down_rounded;
        break;
      case PerformanceLevel.noData:
        bg = const Color(0xFFF3F4F6);
        fg = _kSecondaryText;
        label = 'No Data';
        icon  = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 12),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Performance chart — Weekly Table View ─────────────────────────────────────

class _PerformanceChart extends StatelessWidget {
  final AthletePerformanceSummary summary;
  const _PerformanceChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Monday of the current week
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    // Build one entry per day Mon–Sun
    final List<_DayRowData> rows = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final dayKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final isToday = day.year == now.year &&
          day.month == now.month &&
          day.day == now.day;
      final isFuture =
      day.isAfter(DateTime(now.year, now.month, now.day));

      // Find matching PerformanceBar for this day
      final bar = summary.bars.cast<PerformanceBar?>().firstWhere(
            (b) {
          if (b == null) return false;
          final bd = b.date;
          final bKey =
              '${bd.year}-${bd.month.toString().padLeft(2, '0')}-${bd.day.toString().padLeft(2, '0')}';
          return bKey == dayKey;
        },
        orElse: () => null,
      );

      return _DayRowData(
        day: day,
        isToday: isToday,
        isFuture: isFuture,
        bar: bar,
      );
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: _kBorderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Section header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_view_week_rounded,
                    size: 14, color: Color(0xFF1565C0)),
                const SizedBox(width: 4),
                Text(
                  'Insights – This Week',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // ── Column headers ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                const SizedBox(width: 9), // left accent space
                SizedBox(
                  width: 84,
                  child: _headerLabel('DAY'),
                ),
                Expanded(child: Center(child: _headerLabel('ASSIGNED WORKOUT'))),
                Expanded(
                    child: Center(child: _headerLabel('ACTIVITY LOGGED'))),
              ],
            ),
          ),

          const Divider(height: 6, thickness: 0.8, color: Color(0xFFE5E7EB)),

          // ── Day rows ────────────────────────────────────────────────
          ...rows.map((r) => _DayRowWidget(row: r)),

          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle_rounded,
                    size: 10, color: Color(0xFF1976D2)),
                SizedBox(width: 3),
                Text('Assigned',
                    style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                SizedBox(width: 10),
                Icon(Icons.check_circle_rounded,
                    size: 10, color: Color(0xFF43A047)),
                SizedBox(width: 3),
                Text('Logged',
                    style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
                SizedBox(width: 10),
                Icon(Icons.cancel_outlined,
                    size: 10, color: Color(0xFFEF9A9A)),
                SizedBox(width: 3),
                Text('Missed',
                    style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _headerLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6B7280),
      letterSpacing: 0.4,
    ),
  );
}

// ── Day row data holder ───────────────────────────────────────────────────────

class _DayRowData {
  final DateTime day;
  final bool isToday;
  final bool isFuture;
  final PerformanceBar? bar;

  const _DayRowData({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.bar,
  });

  bool get hasAssignment => bar != null;
  bool get wasLogged     => bar?.wasLogged ?? false;
}

// ── Single day row widget ─────────────────────────────────────────────────────

class _DayRowWidget extends StatelessWidget {
  final _DayRowData row;
  const _DayRowWidget({required this.row});

  static const _dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  Widget build(BuildContext context) {
    final dayName = _dayNames[row.day.weekday - 1];
    final dateStr = '${row.day.day}/${row.day.month}';
    final rowBg   = row.isToday
        ? const Color(0xFFEBF3FF)
        : Colors.transparent;

    // ── Assigned cell ─────────────────────────────────────────────────
    Widget assignedCell;
    if (row.hasAssignment) {
      final b          = row.bar!;
      final typeLabel  = b.workoutType.isNotEmpty
          ? '${b.workoutType[0].toUpperCase()}${b.workoutType.substring(1)}'
          : '';
      final kmStr      = b.assignedKm > 0
          ? '${b.assignedKm.toStringAsFixed(1)} km'
          : '';
      final timeStr    = b.assignedMin > 0
          ? PerformanceBar.fmtMin(b.assignedMin)
          : '';
      final metricLine =
      [kmStr, timeStr].where((s) => s.isNotEmpty).join(' · ');

      assignedCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Color(0xFF1976D2)),
          // if (typeLabel.isNotEmpty)
          //   Padding(
          //     padding: const EdgeInsets.only(top: 1),
          //     child: Text(
          //       typeLabel,
          //       style: const TextStyle(
          //           fontSize: 9,
          //           color: Color(0xFF1976D2),
          //           fontWeight: FontWeight.w700),
          //     ),
          //   ),
          if (metricLine.isNotEmpty)
            Text(
              metricLine,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF5B99E8)),
              textAlign: TextAlign.center,
            ),
        ],
      );
    } else {
      assignedCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('–',
              style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFD1D5DB),
                  fontWeight: FontWeight.w600)),
        ],
      );
    }

    // ── Activity logged cell ──────────────────────────────────────────
    Widget loggedCell;
    if (!row.hasAssignment) {
      // No assignment → nothing expected
      loggedCell = const Text('–',
          style: TextStyle(
              fontSize: 16,
              color: Color(0xFFD1D5DB),
              fontWeight: FontWeight.w600));
    } else if (row.isFuture) {
      // Future assigned day → pending clock
      loggedCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.access_time_rounded,
              size: 16, color: Color(0xFFD1D5DB)),
          Text('Pending',
              style: TextStyle(fontSize: 9, color: Color(0xFFD1D5DB))),
        ],
      );
    } else if (row.wasLogged) {
      // Logged ✓
      final b       = row.bar!;
      final kmStr   = b.actualKm > 0
          ? '${b.actualKm.toStringAsFixed(1)} km'
          : '';
      final timeStr = b.actualMin > 0
          ? PerformanceBar.fmtMin(b.actualMin)
          : '';
      final detail  =
      [kmStr, timeStr].where((s) => s.isNotEmpty).join(' · ');

      loggedCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: Color(0xFF43A047)),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                detail,
                style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF43A047),
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    } else if (row.isToday) {
      // Today, assigned but not yet logged → neutral pending
      loggedCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.radio_button_unchecked_rounded,
              size: 18, color: Color(0xFFABB5BE)),
          Text('Yet to log',
              style: TextStyle(fontSize: 9, color: Color(0xFFABB5BE))),
        ],
      );
    } else {
      // Past assigned, not logged → missed
      loggedCell = Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF9A9A)),
          Text('Missed',
              style: TextStyle(fontSize: 9, color: Color(0xFFEF9A9A))),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Today accent bar
          if (row.isToday)
            Container(
              width: 3,
              height: 32,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(width: 9),

          // Day label column (fixed width)
          SizedBox(
            width: 84,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: row.isToday
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: row.isToday
                        ? const Color(0xFF1976D2)
                        : _kPrimaryText,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),

          // Assigned column
          Expanded(child: Center(child: assignedCell)),

          // Logged column
          Expanded(child: Center(child: loggedCell)),
        ],
      ),
    );
  }
}