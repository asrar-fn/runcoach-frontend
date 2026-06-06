import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import './AthleteDashboard.dart';

class SetGoalsCalendarScreen extends StatefulWidget {
  const SetGoalsCalendarScreen({super.key});

  @override
  State<SetGoalsCalendarScreen> createState() => _SetGoalsCalendarScreenState();
}

class _SetGoalsCalendarScreenState extends State<SetGoalsCalendarScreen> {
  DateTime _selectedWeek = DateTime.now();
  final _distController = TextEditingController();
  final _timeController = TextEditingController();
  String _goalType = 'distance';
  bool _initialized = false;

  static const _gradient = LinearGradient(
    colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  void dispose() {
    _distController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _loadGoalForWeek(AppState appState) {
    final monday = getStartOfWeek(_selectedWeek);
    final existingGoal = appState.dailyGoals.firstWhere(
          (g) => getStartOfWeek(g.date) == monday,
      orElse: () => DailyGoal(date: monday),
    );

    _distController.text = existingGoal.distanceKm > 0 ? existingGoal.distanceKm.toString() : '';
    _timeController.text = existingGoal.durationMin > 0 ? existingGoal.durationMin.toString() : '';

    if (existingGoal.distanceKm > 0 && existingGoal.durationMin > 0) {
      _goalType = 'both';
    } else if (existingGoal.durationMin > 0) {
      _goalType = 'time';
    } else {
      _goalType = 'distance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final monday = getStartOfWeek(_selectedWeek);
    final sunday = monday.add(const Duration(days: 6));

    // Load once after first build when appState is ready
    if (!_initialized && appState.dailyGoals.isNotEmpty) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _loadGoalForWeek(appState));
      });
    }

    final showDist = _goalType == 'distance' || _goalType == 'both';
    final showTime = _goalType == 'time' || _goalType == 'both';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Weekly Goal Setter",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF2C3E50)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekSelector(monday, sunday, appState),
            const SizedBox(height: 24),

            Text("What do you want to track?",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: const Color(0xFF2C3E50))),
            const SizedBox(height: 12),
            _buildGoalTypePicker(),
            const SizedBox(height: 24),

            if (showDist) ...[
              _buildInputCard(
                icon: Icons.directions_run,
                label: "Weekly Distance Goal",
                unit: "km",
                controller: _distController,
                hint: "e.g. 50",
                color: const Color(0xFF1976D2),
              ),
              const SizedBox(height: 16),
            ],
            if (showTime) ...[
              _buildInputCard(
                icon: Icons.timer_outlined,
                label: "Weekly Duration Goal",
                unit: "min",
                controller: _timeController,
                hint: "e.g. 300",
                color: const Color(0xFFE6783A),
              ),
              const SizedBox(height: 16),
            ],

            if (showDist) ...[
              Text("Quick Distance Presets",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              _buildPresets(['20', '30', '40', '50', '60', '80'], _distController, ' km'),
              const SizedBox(height: 16),
            ],
            if (showTime) ...[
              Text("Quick Duration Presets",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              _buildPresets(['120', '180', '240', '300', '360', '420'], _timeController, ' min'),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final dist = showDist ? (double.tryParse(_distController.text) ?? 0) : 0.0;
                  final time = showTime ? (int.tryParse(_timeController.text) ?? 0) : 0;

                  if (showDist && dist <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a valid distance")));
                    return;
                  }
                  if (showTime && time <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a valid duration")));
                    return;
                  }

                  appState.saveWeeklyGoal(dist, time, _selectedWeek);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("✅ Weekly goal saved!",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      backgroundColor: const Color(0xFF1976D2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.pop(context);
                },
                child: Text("Save Weekly Goal",
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalTypePicker() {
    final options = [
      {'value': 'distance', 'label': 'Distance', 'icon': Icons.directions_run, 'sub': 'e.g. 60 km/week'},
      {'value': 'time', 'label': 'Time', 'icon': Icons.timer_outlined, 'sub': 'e.g. 5 hrs/week'},
      {'value': 'both', 'label': 'Both', 'icon': Icons.track_changes, 'sub': 'Distance + Time'},
    ];

    return Row(
      children: options.map((opt) {
        final isSelected = _goalType == opt['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              // ✅ Only setState here — no postFrameCallback overwriting this
              setState(() {
                _goalType = opt['value'] as String;
                _distController.clear();
                _timeController.clear();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: opt['value'] != 'both' ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3))]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(opt['icon'] as IconData,
                      color: isSelected ? Colors.white : Colors.grey.shade500, size: 22),
                  const SizedBox(height: 6),
                  Text(opt['label'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF2C3E50))),
                  Text(opt['sub'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey.shade500),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekSelector(DateTime monday, DateTime sunday, AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF1976D2)),
            onPressed: () {
              setState(() {
                _selectedWeek = _selectedWeek.subtract(const Duration(days: 7));
                _loadGoalForWeek(appState);
              });
            },
          ),
          Column(
            children: [
              Text("Week of",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
              Text(
                "${DateFormat('MMM d').format(monday)} – ${DateFormat('MMM d').format(sunday)}",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF2C3E50)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF1976D2)),
            onPressed: () {
              setState(() {
                _selectedWeek = _selectedWeek.add(const Duration(days: 7));
                _loadGoalForWeek(appState);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required String unit,
    required TextEditingController controller,
    required String hint,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50))),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 22, color: Colors.grey.shade300),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffix: Text(unit,
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: Colors.grey.shade500)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets(List<String> values, TextEditingController ctrl, String unitLabel) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isActive = ctrl.text == v;
        return GestureDetector(
          onTap: () => setState(() => ctrl.text = v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1976D2) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isActive ? const Color(0xFF1976D2) : Colors.grey.shade300),
            ),
            child: Text(
              "$v$unitLabel",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF2C3E50),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}