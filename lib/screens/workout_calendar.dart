import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import './AthleteDashboard.dart';

class Workout {
  final String id;
  final String date; // local YYYY-MM-DD
  final String type;
  final String title;
  final String? duration;
  final String? distance;
  final bool completed;
  final DateTime? uploadedAt; // NEW

  Workout({
    required this.id,
    required this.date,
    required this.type,
    required this.title,
    this.duration,
    this.distance,
    this.completed = false,
    this.uploadedAt,
  });
}

// --- Workout type mapping for icons/labels ---
final Map<String, Map<String, String>> workoutTypes = {
  "easy": {"color": "green", "label": "Easy Run", "icon": "🚶", "distance": "5km"},
  "tempo": {"color": "yellow", "label": "Tempo Run", "icon": "🏃", "distance": "8km"},
  "interval": {"color": "orange", "label": "Intervals", "icon": "⚡", "distance": "6km"},
  "long": {"color": "blue", "label": "Long Run", "icon": "🏃‍♂️", "distance": "15km"},
  "rest": {"color": "grey", "label": "Rest Day", "icon": "😴", "distance": ""},
  "custom": {"color": "purple", "label": "Workout", "icon": "🏃", "distance": ""},
};

// -----------------------------
// Date helpers — LOCAL timezone safe
// -----------------------------
DateTime? parseToLocalDateTime(dynamic input) {
  if (input == null) return null;
  if (input is DateTime) return input;
  if (input is! String) return null;

  final s = input.trim();
  final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  if (dateOnlyMatch != null) {
    final y = int.parse(dateOnlyMatch.group(1)!);
    final m = int.parse(dateOnlyMatch.group(2)!);
    final d = int.parse(dateOnlyMatch.group(3)!);
    return DateTime(y, m, d);
  }

  try {
    return DateTime.parse(s).toLocal();
  } catch (e) {
    return null;
  }
}

String? localDayKey(dynamic input) {
  final d = parseToLocalDateTime(input);
  if (d == null) return null;
  return DateFormat('yyyy-MM-dd').format(d);
}

// -----------------------------
// Fallback data generator
// -----------------------------
List<Workout> generateDailyWorkouts() {
  final workouts = <Workout>[];
  final today = DateTime.now();
  final startDate = DateTime(today.year, today.month, 1);

  final types = ["easy", "tempo", "interval", "long", "rest"];
  final Map<String, List<String>> titlesMap = {
    "easy": ["Easy 5K", "Recovery Run", "Easy Pace Run"],
    "tempo": ["Tempo 8K", "Threshold Run", "Tempo Intervals"],
    "interval": ["5x1K Intervals", "Track Workout", "Speed Intervals"],
    "long": ["Long Run 15K", "Endurance Run", "Long Steady Run"],
    "rest": ["Rest Day", "Recovery Day", "Active Rest"],
  };

  for (int i = 0; i < 35; i++) {
    final d = DateTime(startDate.year, startDate.month, startDate.day + i);
    final dateStr = localDayKey(d)!;
    final type = types[i % types.length];
    final titles = titlesMap[type]!;
    final title = titles[i % titles.length];
    final duration = type == "rest" ? "" : ["30 min", "45 min", "60 min", "90 min"][i % 4];
    workouts.add(Workout(
      id: 'g-${i + 1}',
      date: dateStr,
      type: type,
      title: title,
      duration: duration,
      distance: workoutTypes[type]?["distance"] ?? "",
      completed: d.isBefore(today),
    ));
  }
  return workouts;
}

// -----------------------------
// Map assignments + activities -> Workout[]
// -----------------------------
List<Workout> mapDataToWorkouts({
  required String? plan,
  required List<Assignment> assignments,
  required List<Activity> activities,
  required List<DailyGoal> goals,
}) {
  final bool isAdvanced = plan != null && plan.toLowerCase() != 'free';
  final List<Workout> result = [];

  final activitySet = <String>{};
  for (var a in activities) {
    final k = localDayKey(a.date);
    if (k != null) activitySet.add(k);
  }

  if (isAdvanced) {
    for (var a in assignments) {
      final dateKey = localDayKey(a.scheduledDate) ?? localDayKey(DateTime.now())!;
      final typeKey = (a.workoutType ?? "").toLowerCase();
      final wt = workoutTypes.containsKey(typeKey) ? typeKey : "custom";

      result.add(Workout(
        id: a.id ?? 'assign-${assignments.indexOf(a)}',
        date: dateKey,
        type: wt,
        title: a.workoutType ?? "Coached Workout",
        duration: a.durationMin != null ? "${a.durationMin} min" : null,
        distance: a.distanceKm != null ? "${a.distanceKm}km" : null,
        completed: activitySet.contains(dateKey),
      ));
    }
  // } else {
  //   for (var g in goals) {
  //     final dateKey = localDayKey(g.date)!;
  //     result.add(Workout(
  //       id: 'goal-${g.date.millisecondsSinceEpoch}',
  //       date: dateKey,
  //       type: 'custom',
  //       title: "Daily Goal",
  //       duration: g.durationMin > 0 ? "${g.durationMin} min" : null,
  //       distance: g.distanceKm > 0 ? "${g.distanceKm}km" : null,
  //       completed: activitySet.contains(dateKey),
  //     ));
  //   }
  }

  for (var a in activities) {
    final dateKey = localDayKey(a.date);
    if (dateKey == null) continue;

    final alreadyExists = result.any((w) => w.date == dateKey);
    if (!alreadyExists) {
      result.add(Workout(
        id: 'activity-${a.id ?? dateKey}',
        date: dateKey,
        type: a.type?.toLowerCase() ?? 'custom',
        title: _getActivityLabel(a),
        duration: a.durationMin != null ? "${a.durationMin} min" : null,
        distance: a.distanceKm != null ? "${a.distanceKm}km" : null,
        completed: true,
        uploadedAt: a.createdAt ?? a.date,
      ));
    } else {
      final index = result.indexWhere((w) => w.date == dateKey);
      if (index != -1) {
        result[index] = Workout(
          id: result[index].id,
          date: result[index].date,
          type: result[index].type,
          title: result[index].title,
          duration: result[index].duration,
          distance: result[index].distance,
          completed: true,
          uploadedAt: a.createdAt ?? a.date,
        );
      }
    }
  }

  return result;
}

String _getActivityLabel(Activity a) {
  if (a.date == null) return "Activity";
  if (a.type?.toLowerCase() != 'run') return a.type ?? "Activity";
  final hour = a.date!.hour;
  if (hour >= 4 && hour < 10) return "Morning Run";
  if (hour >= 10 && hour < 15) return "Afternoon Run";
  if (hour >= 15 && hour < 19) return "Evening Run";
  return "Night Run";
}

// -----------------------------
// Component
// -----------------------------
class WorkoutCalendar extends StatefulWidget {
  final String? plan;
  final List<Assignment>? assignments;
  final List<Activity>? activities;
  final List<DailyGoal>? goals;

  const WorkoutCalendar({
    Key? key,
    this.plan,
    this.assignments,
    this.activities,
    this.goals,
  }) : super(key: key);

  @override
  _WorkoutCalendarState createState() => _WorkoutCalendarState();
}

class _WorkoutCalendarState extends State<WorkoutCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _currentDate;
  String? _selectedDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _selectedDate = localDayKey(DateTime.now());
    _tabController = TabController(length: 2, vsync: this);
    // Rebuild when tab changes so navigation arrows work correctly
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Workout> get _workouts {
    return mapDataToWorkouts(
      plan: widget.plan,
      assignments: widget.assignments ?? [],
      activities: widget.activities ?? [],
      goals: widget.goals ?? [],
    );
  }

  /// Returns the 7 days of the ISO week that contains [date].
  /// Week starts on Sunday.
  List<DateTime> _getWeekDays(DateTime date) {
    // weekday: Mon=1 … Sun=7; we want Sun=0
    final int dayOfWeek = date.weekday % 7; // Sun→0, Mon→1, …, Sat→6
    final sunday = date.subtract(Duration(days: dayOfWeek));
    return List.generate(
      7,
          (i) => DateTime(sunday.year, sunday.month, sunday.day + i),
    );
  }

  List<DateTime> _getMonthDays(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    // Sunday-based offset
    final int startOffset = firstDayOfMonth.weekday % 7;
    final startOfCalendar =
    firstDayOfMonth.subtract(Duration(days: startOffset));

    return List.generate(
      42,
          (i) => DateTime(
          startOfCalendar.year, startOfCalendar.month, startOfCalendar.day + i),
    );
  }

  void _navigateWeek(String direction) {
    setState(() {
      _currentDate = _currentDate
          .add(Duration(days: direction == "next" ? 7 : -7));
    });
  }

  void _navigateMonth(String direction) {
    setState(() {
      _currentDate = DateTime(
          _currentDate.year,
          _currentDate.month + (direction == "next" ? 1 : -1),
          1);
    });
  }

  List<Workout> _getWorkoutsForDate(DateTime date) {
    final key = localDayKey(date);
    if (key == null) return [];
    return _workouts.where((w) => w.date == key).toList();
  }


  @override
  Widget build(BuildContext context) {
    final todaysKey = localDayKey(DateTime.now())!;
    final List<Workout> selectedWorkouts =
    _workouts.where((w) => w.date == _selectedDate).toList();

    final String displayDate = _selectedDate == todaysKey
        ? "Today's Workouts"
        : "Workouts for ${DateFormat('MMM d, yyyy').format(DateTime.parse(_selectedDate!))}";

    String _pace(double dist, int time) {
      if (dist <= 0 || time <= 0) return "-";
      double secPerKm = (time * 60) / dist;
      int min = secPerKm ~/ 60;
      int sec = (secPerKm % 60).round();
      return "$min:${sec.toString().padLeft(2, '0')} min/km";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // // ── Header ──────────────────────────────────────────────
              // Text(
              //   "Training Calendar",
              //   style: Theme.of(context)
              //       .textTheme
              //       .headlineMedium!
              //       .copyWith(fontWeight: FontWeight.bold),
              // ),
              Text(
                "Plan and track your workouts",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7)),
              ),
              const SizedBox(height: 20),

              // ── Today's / Selected Workout Card ──────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (selectedWorkouts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                              "No workouts or activities recorded for this day."),
                        )
                      else
                        Column(
                          children: selectedWorkouts.map((workout) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        workoutTypes[workout.type]?["icon"] ??
                                            "🏃",
                                        style:
                                        const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          workout.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      if (workout.completed)
                                        const Icon(Icons.check_circle,
                                            color: Colors.green),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // ── Workout detail row (responsive) ─────
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 4,
                                    children: [
                                      _buildWorkoutDetail(
                                        icon: Icons.access_time,
                                        label: workout.duration ?? "-",
                                      ),
                                      _buildWorkoutDetail(
                                        icon: Icons.map,
                                        label: workout.distance ?? "-",
                                      ),
                                      _buildWorkoutDetail(
                                        icon: Icons.bolt,
                                        label: workout.completed
                                            ? "Completed"
                                            : "Planned",
                                      ),
                                      if (workout.uploadedAt != null)
                                        _buildWorkoutDetail(
                                          icon: Icons.schedule,
                                          label: DateFormat('hh:mm a').format(workout.uploadedAt!),
                                        ),
                                      _buildWorkoutDetail(
                                        icon: Icons.speed,
                                        label: _pace(
                                          double.tryParse(workout.distance?.replaceAll("km", "") ?? "0") ?? 0,
                                          int.tryParse(workout.duration?.replaceAll(" min", "") ?? "0") ?? 0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (selectedWorkouts.length > 1 &&
                                      workout != selectedWorkouts.last)
                                    const Divider(),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Tab bar + Navigation row ─────────────────────────────
              Row(
                children: [
                  // Tab switcher
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final double indicatorWidth =
                            (constraints.maxWidth / 2) - 4;
                        return Stack(
                          children: [
                            AnimatedAlign(
                              duration:
                              const Duration(milliseconds: 300),
                              alignment: _tabController.index == 0
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Container(
                                width: indicatorWidth,
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF2575FC),
                                    Color(0xFFF7941D)
                                  ]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            TabBar(
                              controller: _tabController,
                              indicatorColor: Colors.transparent,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.black,
                              labelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              tabs: const [
                                Tab(text: "Week"),
                                Tab(text: "Month"),
                              ],
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Navigation arrows + label
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_left, color: Colors.black),
                    onPressed: () => _tabController.index == 0
                        ? _navigateWeek("prev")
                        : _navigateMonth("prev"),
                  ),
                  SizedBox(
                    width: 72,
                    child: Center(
                      child: Text(
                        _tabController.index == 0
                            ? DateFormat('MMM d')
                            .format(_getWeekDays(_currentDate)[0])
                            : DateFormat('MMM yyyy')
                            .format(_currentDate),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_right,
                        color: Colors.black),
                    onPressed: () => _tabController.index == 0
                        ? _navigateWeek("next")
                        : _navigateMonth("next"),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Calendar ─────────────────────────────────────────────
              // Use LayoutBuilder to make heights screen-size aware
              LayoutBuilder(builder: (context, constraints) {
                return SizedBox(
                  // Week view needs less height than month view
                  height: _tabController.index == 0
                      ? _weekViewHeight(constraints.maxWidth)
                      : _monthViewHeight(constraints.maxWidth),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWeekView(todaysKey, constraints.maxWidth),
                      _buildMonthView(todaysKey, constraints.maxWidth),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Height helpers ──────────────────────────────────────────────────────────

  /// Each cell in the week view is square-ish; 1 row + header
  double _weekViewHeight(double availableWidth) {
    final cellWidth = (availableWidth - 16) / 7; // 8px padding on each side
    // cell height = cellWidth / 0.55 aspect ratio (taller than wide for content)
    final cellHeight = cellWidth / 0.55;
    return cellHeight + 40 + 16; // row + header + padding
  }

  /// 6 rows + header
  double _monthViewHeight(double availableWidth) {
    final cellWidth = (availableWidth - 16) / 7;
    final cellHeight = cellWidth / 0.85;
    return (cellHeight * 6) + 40 + 16;
  }

  // ── Detail chip ─────────────────────────────────────────────────────────────
  Widget _buildWorkoutDetail(
      {required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.6)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  // ── Week view ───────────────────────────────────────────────────────────────
  Widget _buildWeekView(String todaysKey, double availableWidth) {
    final days = _getWeekDays(_currentDate);
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Card(
      elevation: 1,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Weekday headers
            Row(
              children: dayLabels
                  .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ))
                  .toList(),
            ),
            const Divider(height: 8, thickness: 0.5),
            // Single week row — each cell fills remaining space
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(7, (index) {
                  final date = days[index];
                  return Expanded(
                    child: _buildDayCell(
                      date: date,
                      todaysKey: todaysKey,
                      isCurrentMonth: true,
                      compact: true,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month view ──────────────────────────────────────────────────────────────
  Widget _buildMonthView(String todaysKey, double availableWidth) {
    final daysInMonth = _getMonthDays(_currentDate);
    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Card(
      elevation: 1,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Weekday headers
            Row(
              children: dayLabels
                  .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ))
                  .toList(),
            ),
            const Divider(height: 8, thickness: 0.5),
            // 6 rows of 7 days
            Expanded(
              child: Column(
                children: List.generate(6, (rowIndex) {
                  return Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(7, (colIndex) {
                        final date =
                        daysInMonth[rowIndex * 7 + colIndex];
                        return Expanded(
                          child: _buildDayCell(
                            date: date,
                            todaysKey: todaysKey,
                            isCurrentMonth:
                            date.month == _currentDate.month,
                            compact: false,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared day cell ─────────────────────────────────────────────────────────
  Widget _buildDayCell({
    required DateTime date,
    required String todaysKey,
    required bool isCurrentMonth,
    required bool compact,
  }) {
    final workoutsForDate = _getWorkoutsForDate(date);
    final hasActivity = workoutsForDate.any((w) => w.completed);
    final isSelected = localDayKey(date) == _selectedDate;
    final isToday = localDayKey(date) == todaysKey;

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = localDayKey(date)),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : isToday
                ? const Color(0xFF2575FC)
                : Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.1),
            width: isSelected || isToday ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date number + activity dot ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Green dot for completed activity
                // if (hasActivity)
                //   Container(
                //     width: 5,
                //     height: 5,
                //     decoration: const BoxDecoration(
                //       color: Colors.green,
                //       shape: BoxShape.circle,
                //     ),
                //   )
                // else
                //   const SizedBox(width: 5),

                // Day number
                Text(
                  date.day.toString(),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.blue
                        : isToday
                        ? const Color(0xFF2575FC)
                        : isCurrentMonth
                        ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.35),
                  ),
                ),
              ],
            ),

            // ── Workout indicator ────────────────────────────────
            if (workoutsForDate.isNotEmpty) ...[
              const SizedBox(height: 2),
              // Show first workout icon only (keeps cell compact)
              _buildMiniWorkoutBadge(workoutsForDate.first),
              if (workoutsForDate.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '+${workoutsForDate.length - 1}',
                    style:
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 8,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// A tiny badge showing just the emoji icon — never overflows
  Widget _buildMiniWorkoutBadge(Workout workout) {
    final meta =
        workoutTypes[workout.type] ?? workoutTypes["custom"]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: workout.completed
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: workout.completed
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(meta["icon"]!, style: const TextStyle(fontSize: 9)),
          if (workout.completed) ...[
            const SizedBox(width: 2),
            const Icon(Icons.check_circle,
                size: 8, color: Colors.green),
          ],
        ],
      ),
    );
  }
}

// Helper extension
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}