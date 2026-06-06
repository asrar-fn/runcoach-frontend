// lib/widgets/athlete_performance_tile.dart

import 'package:flutter/material.dart';
import '../services/athlete_performance_service.dart';
import '../models/athlete.dart';

// ── Colour constants for white-card context ───────────────────────────────────
const _kPrimaryText   = Color(0xFF1A1A2E); // near-black
const _kSecondaryText = Color(0xFF6B7280); // medium grey
const _kBlueBar       = Color(0xFF2575FC); // Change 3: blue progress bar
const _kBorderColor   = Color(0xFFE5E7EB); // subtle divider

class AthletePerformanceTile extends StatefulWidget {
  final Athlete athlete;
  final AthletePerformanceService performanceService;
  final VoidCallback onTap;
  final VoidCallback onAssign;
  final VoidCallback onMessage;

  const AthletePerformanceTile({
    super.key,
    required this.athlete,
    required this.performanceService,
    required this.onTap,
    required this.onAssign,
    required this.onMessage,
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

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.performanceService.getSummary(widget.athlete.id);
    _expandCtrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut);
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
            // ── Tap target ────────────────────────────────────────────────
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Row A: Avatar | Name/email | Badge ────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar — blue background, white initials
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

                        // Name / email — dark text
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
                                style: tt.bodySmall
                                    ?.copyWith(color: _kSecondaryText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Badge / spinner / error
                        if (loading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1976D2)),
                          )
                        else if (hasError)
                          const Icon(Icons.error_outline,
                              size: 18, color: Colors.redAccent)
                        else if (summary != null)
                            _PerformanceBadge(summary: summary),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Row B: Plan label | Actions ───────────────────────
                    // Change 3: flat "Plan – X" text, no bubble
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
                        SizedBox(
                          height: 32,
                          width: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.assignment_outlined,
                                color: Color(0xFF1976D2), size: 18),
                            tooltip: 'Assign Workout',
                            onPressed: widget.onAssign,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 32,
                          width: 32,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chat_bubble_outline,
                                color: _kSecondaryText, size: 18),
                            tooltip: 'Message Athlete',
                            onPressed: widget.onMessage,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Progress bars ─────────────────────────────────────
                    if (summary != null) ...[
                      _WeeklyProgressBar(summary: summary),
                      const SizedBox(height: 6),
                    ] else ...[
                      _SimplePlanBar(athlete: athlete),
                      const SizedBox(height: 6),
                    ],

                    // ── Stats chips + Insights toggle ─────────────────────
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

            // ── Expandable chart ──────────────────────────────────────────
            SizeTransition(
              sizeFactor:     _expandAnim,
              axisAlignment: -1,
              child: summary != null && summary.bars.isNotEmpty
                  ? _PerformanceChart(summary: summary)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly progress bar — dark labels, BLUE bars (Change 3)
// ─────────────────────────────────────────────────────────────────────────────

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
        // Distance bar — Change 3: solid blue
        Row(
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
                  color:      _kPrimaryText,
                  fontSize:   11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),

        // Time bar — Change 3: blue with slight opacity
        if (summary.weekAssignedMin > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           timeProg,
                    minHeight:       5,
                    backgroundColor: const Color(0xFFE5E7EB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6DA4FC)), // lighter blue for time
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${fmtMin(summary.weekLoggedMin)}/'
                    '${fmtMin(summary.weekAssignedMin)}',
                style: const TextStyle(
                    color:      _kSecondaryText,
                    fontSize:   10,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],

        const SizedBox(height: 2),
        Text(
          'This week',
          style: const TextStyle(color: _kSecondaryText, fontSize: 10),
        ),
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
              // Change 3: blue bar
              valueColor: const AlwaysStoppedAnimation<Color>(_kBlueBar),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${athlete.progressPct}%',
          style: const TextStyle(
              color:      _kPrimaryText,
              fontSize:   11,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row + Insights toggle — dark text on white
// ─────────────────────────────────────────────────────────────────────────────

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
        if (summary.bars.isNotEmpty)
          GestureDetector(
            onTap: onToggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chartExpanded ? 'Hide' : 'Insights',
                  style: const TextStyle(
                      fontSize:   11,
                      color:      Color(0xFF1976D2),
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
        color: isAlert
            ? const Color(0xFFFFEBEB)
            : const Color(0xFFF3F4F6),
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
                text:  '$label ',
                style: const TextStyle(color: _kSecondaryText)),
            TextSpan(
                text:  value,
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

// ─────────────────────────────────────────────────────────────────────────────
// Performance badge
// ─────────────────────────────────────────────────────────────────────────────

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
        bg    = const Color(0xFFE8F5E9);
        fg    = const Color(0xFF2E7D32);
        label = 'Peak Performance';
        icon  = Icons.trending_up_rounded;
        break;
      case PerformanceLevel.good:
        bg    = const Color(0xFFFFF3E0);
        fg    = const Color(0xFFE65100);
        label = 'On Track';
        icon  = Icons.remove_rounded;
        break;
      case PerformanceLevel.needsAttention:
        bg    = const Color(0xFFFFEBEE);
        fg    = const Color(0xFFC62828);
        label = 'Needs Focus';
        icon  = Icons.trending_down_rounded;
        break;
      case PerformanceLevel.noData:
        bg    = const Color(0xFFF3F4F6);
        fg    = _kSecondaryText;
        label = 'No Data';
        icon  = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 12),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize:   11,
                color:      fg,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance chart — already white, kept as-is
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceChart extends StatelessWidget {
  final AthletePerformanceSummary summary;
  const _PerformanceChart({required this.summary});

  static const Color _assignedColor = Color(0xFF1E88E5);
  static const Color _goodColor     = Color(0xFF43A047);
  static const Color _okColor       = Color(0xFFFFB300);
  static const Color _badColor      = Color(0xFFE53935);
  static const Color _timeColor     = Color(0xFF8E24AA);

  Color _actualColor(double pct) {
    if (pct >= 90) return _goodColor;
    if (pct >= 50) return _okColor;
    return _badColor;
  }

  @override
  Widget build(BuildContext context) {
    final tt      = Theme.of(context).textTheme;
    final bars    = summary.bars;
    final hasTime = bars.any((b) => b.assignedMin > 0);

    final maxKm = bars
        .expand((b) => [b.assignedKm, b.actualKm])
        .fold<double>(1, (p, v) => v > p ? v : p);

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
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 14, color: Color(0xFF1565C0)),
                const SizedBox(width: 4),
                Text(
                  'Insights',
                  style: tt.labelMedium?.copyWith(
                    color:       const Color(0xFF1565C0),
                    fontWeight:  FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // Legend
          Wrap(
            spacing: 10,
            children: [
              _LegendDot(color: _assignedColor, label: 'Assigned km'),
              _LegendDot(color: _goodColor,     label: 'Logged km'),
              if (hasTime) _LegendDot(color: _timeColor, label: 'Time %'),
            ],
          ),
          const SizedBox(height: 10),

          // Chart
          LayoutBuilder(
            builder: (context, constraints) {
              const double labelH = 22.0;
              const double chartH = 100.0;

              return SizedBox(
                height: chartH + labelH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: labelH),
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text('km',
                            style: const TextStyle(
                                fontSize: 9,
                                color:    Color(0xFF9E9E9E))),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: bars.map((bar) {
                          final assignH = maxKm > 0
                              ? (bar.assignedKm / maxKm) * chartH
                              : 0.0;
                          final actualH = maxKm > 0
                              ? (bar.actualKm / maxKm) * chartH
                              : 0.0;
                          final timeH = hasTime && bar.assignedMin > 0
                              ? (bar.timePct.clamp(0, 100) / 100) * chartH
                              : 0.0;

                          final actualColor = _actualColor(bar.distancePct);
                          final dateLabel =
                              '${bar.date.day}/${bar.date.month}';
                          final tooltipMsg =
                              '${bar.workoutType.toUpperCase()}\n'
                              'Assigned: ${bar.assignedKm.toStringAsFixed(1)} km'
                              '${bar.assignedMin > 0 ? ' · ${bar.assignedDurationLabel}' : ''}\n'
                              'Logged:   ${bar.actualKm.toStringAsFixed(1)} km'
                              '${bar.actualMin > 0 ? ' · ${bar.actualDurationLabel}' : ''}\n'
                              'Distance: ${bar.distancePct.toStringAsFixed(0)}%'
                              '${bar.assignedMin > 0 ? '  |  Time: ${bar.timePct.toStringAsFixed(0)}%' : ''}\n'
                              '${bar.wasLogged ? '' : '⚠ Not logged'}';

                          return Expanded(
                            child: Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 5),
                              child: Tooltip(
                                message:     tooltipMsg,
                                triggerMode: TooltipTriggerMode.tap,
                                child: Column(
                                  mainAxisSize:      MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: chartH,
                                      child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: _Bar(
                                              height:    assignH,
                                              color:     _assignedColor,
                                              maxHeight: chartH,
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          Expanded(
                                            child: _Bar(
                                              height: actualH,
                                              color:  bar.wasLogged
                                                  ? actualColor
                                                  : Colors.grey
                                                  .withOpacity(0.3),
                                              maxHeight: chartH,
                                            ),
                                          ),
                                          if (hasTime) ...[
                                            const SizedBox(width: 1),
                                            Expanded(
                                              child: _Bar(
                                                height: timeH,
                                                color: bar.wasLogged &&
                                                    bar.assignedMin > 0
                                                    ? _timeColor
                                                    .withOpacity(0.75)
                                                    : Colors.grey
                                                    .withOpacity(0.2),
                                                maxHeight: chartH,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: labelH,
                                      child: Center(
                                        child: Text(
                                          dateLabel,
                                          style: const TextStyle(
                                            fontSize:   10,
                                            color:      Color(0xFF424242),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    'date',
                    style: const TextStyle(
                      fontSize:      9,
                      color:         Color(0xFF9E9E9E),
                      fontWeight:    FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Center(
            child: Text(
              'Avg ${summary.avgCompletionPct.toStringAsFixed(0)}% completion '
                  '· last ${summary.totalAssignments} workout(s) · tap bar for detail',
              style: const TextStyle(fontSize: 10, color: Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated bar
// ─────────────────────────────────────────────────────────────────────────────

class _Bar extends StatefulWidget {
  final double height;
  final Color  color;
  final double maxHeight;
  const _Bar(
      {required this.height, required this.color, required this.maxHeight});

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final h = (widget.height * _anim.value).clamp(0.0, widget.maxHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: h < 2 ? 2 : h,
            decoration: BoxDecoration(
              color:         widget.color,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width:  9,
          height: 9,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize:   10,
                color:      color,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}