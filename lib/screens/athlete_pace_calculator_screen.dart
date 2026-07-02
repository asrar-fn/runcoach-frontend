import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_storage_service.dart';
import './AthleteDashboard.dart';
import '../config/api_config.dart';

class AthletePaceCalculatorScreen extends StatefulWidget {
  final String athleteId;

  const AthletePaceCalculatorScreen({super.key, required this.athleteId});

  @override
  State<AthletePaceCalculatorScreen> createState() =>
      _AthletePaceCalculatorScreenState();
}

class _AthletePaceCalculatorScreenState
    extends State<AthletePaceCalculatorScreen> {
  List<dynamic> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchActivityData();
  }

  Future<void> _fetchActivityData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/activities/athlete/${widget.athleteId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _activities = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load activities: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error connecting to server: $e";
        _isLoading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _calculatePace(dynamic distance, dynamic duration) {
    try {
      final d = (distance is num) ? distance.toDouble() : double.parse(distance.toString());
      final t = (duration is num) ? duration.toDouble() : double.parse(duration.toString());
      if (d <= 0 || t <= 0) return '--:--';
      final totalSec = (t * 60) / d;
      final mins = totalSec ~/ 60;
      final secs = (totalSec % 60).round();
      return '$mins:${secs.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _calculatePaceFromInputs(String distStr, String timeStr) {
    final d = double.tryParse(distStr);
    final t = double.tryParse(timeStr);
    if (d == null || t == null || d <= 0 || t <= 0) return '--:--';
    final totalSec = (t * 60) / d;
    final mins = totalSec ~/ 60;
    int secs = (totalSec % 60).round();
    if (secs == 60) { return '${mins + 1}:00'; }
    return '$mins:${secs.toString().padLeft(2, '0')} min/km';
  }

  String _runType(DateTime? date) {
    if (date == null) return 'Run';
    final h = date.hour;
    if (h >= 4 && h < 10) return 'Morning Run';
    if (h >= 10 && h < 15) return 'Afternoon Run';
    if (h >= 15 && h < 19) return 'Evening Run';
    return 'Night Run';
  }

  bool _isFromStrava(dynamic activity) =>
      (activity['source'] ?? '') == 'strava' || (activity['stravaId'] != null);

  String _getTitle(dynamic a) {
    final fromStrava = _isFromStrava(a);
    final notes = a['notes']?.toString() ?? '';
    if (fromStrava && notes.isNotEmpty) return notes;
    final dateRaw = a['date'] ?? a['createdAt'];
    final date = dateRaw != null ? DateTime.tryParse(dateRaw)?.toLocal() : null;
    return _runType(date);
  }

  // ── Delete confirmation dialog ────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, dynamic activity) async {
    // ✅ Try all possible ID fields, convert to String
    final id = (activity['id'] ?? activity['_id'])?.toString();

    // ✅ Guard: if still null, show a clear error and stop
    if (id == null || id.isEmpty || id == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: activity ID missing. Try syncing again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final title = _getTitle(activity);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Activity',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(
          'Are you sure you want to delete "$title"? This cannot be undone.',
          style: GoogleFonts.poppins(color: AppColors.textMedium, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textMedium)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Delete via AppState so dashboard also updates
    final appState = Provider.of<AppState>(context, listen: false);
    final success = await appState.deleteActivity(id);

    if (success) {
      setState(() => _activities.removeWhere((a) => (a['id'] ?? a['_id']) == id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity deleted', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete. Try again.', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Edit dialog (mirrors the manual upload form) ──────────────────────────────

  void _openEditDialog(BuildContext context, dynamic activity) {
    final id = (activity['_id'] ?? activity['id'])?.toString();
    if (id == null || id.isEmpty) return; // guard
    final distRaw = activity['distanceKm'] ?? activity['distance'] ?? 0;
    final durRaw = activity['durationMin'] ?? activity['duration'] ?? 0;
    final dateRaw = activity['date'] ?? activity['createdAt'];
    DateTime selectedDate = dateRaw != null
        ? (DateTime.tryParse(dateRaw)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute);

    final distController = TextEditingController(
        text: (distRaw is num) ? distRaw.toDouble().toStringAsFixed(2) : distRaw.toString());
    final durController = TextEditingController(
        text: (durRaw is num) ? durRaw.toInt().toString() : durRaw.toString());

    bool distanceError = false;
    bool durationError = false;
    bool isSaving = false;

    bool isPastDate(DateTime date) {
      final now = DateTime.now();
      return date.year != now.year || date.month != now.month || date.day != now.day;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Activity',
                            style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMedium),
                          onPressed: () {
                            distController.dispose();
                            durController.dispose();
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                      ],
                    ),

                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                      style: GoogleFonts.poppins(color: AppColors.textMedium, fontSize: 13),
                    ),
                    const Divider(height: 32),

                    // ── Distance + Duration row ──────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Distance (km)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: distController,
                                onChanged: (_) => setDialogState(() {
                                  if (distanceError) distanceError = false;
                                }),
                                keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: '0.0',
                                  hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade400, fontSize: 14),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  errorText: distanceError ? 'Distance is required' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Duration (min)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: durController,
                                onChanged: (_) => setDialogState(() {
                                  if (durationError) durationError = false;
                                }),
                                keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                                style: GoogleFonts.poppins(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: GoogleFonts.poppins(
                                      color: Colors.grey.shade400, fontSize: 14),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  errorText: durationError ? 'Duration is required' : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Live pace preview ────────────────────────────────────────
                    StatefulBuilder(
                      builder: (_, setPaceState) {
                        // Re-evaluates on every keystroke via ValueListenableBuilder below
                        return Container();
                      },
                    ),
                    ValueListenableBuilder2(
                      first: distController,
                      second: durController,
                      builder: (_, __, ___, ____) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primaryBlue.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Calculated Pace:',
                                  style: GoogleFonts.poppins(
                                      color: AppColors.textMedium,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                _calculatePaceFromInputs(
                                    distController.text, durController.text),
                                style: GoogleFonts.poppins(
                                    color: AppColors.primaryBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Time picker (only for past dates) ───────────────────────
                    if (isPastDate(selectedDate)) ...[
                      Text('Time of Activity',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: dialogContext,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setDialogState(() => selectedTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedTime.format(dialogContext)),
                              const Icon(Icons.access_time),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Date picker ──────────────────────────────────────────────
                    Text('Date of Activity',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat.yMMMd().format(selectedDate),
                              style: GoogleFonts.poppins(color: AppColors.textDark),
                            ),
                            const Icon(Icons.calendar_month,
                                color: AppColors.primaryBlue, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Save button ──────────────────────────────────────────────
                    GradientButton(
                      disabled: isSaving,
                      onPressed: () async {
                        final distText = distController.text.trim();
                        final durText = durController.text.trim();
                        final dist = double.tryParse(distText) ?? 0;
                        final dur = int.tryParse(durText) ?? 0;

                        final hasDistError = distText.isEmpty || dist <= 0;
                        final hasDurError = durText.isEmpty || dur <= 0;

                        if (hasDistError || hasDurError) {
                          setDialogState(() {
                            distanceError = hasDistError;
                            durationError = hasDurError;
                          });
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        // Build the final datetime
                        final DateTime activityDate = isPastDate(selectedDate)
                            ? DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        )
                            : DateTime.now();

                        final appState =
                        Provider.of<AppState>(context, listen: false);
                        final success = await appState.updateActivity(
                            id, dist, dur, activityDate);

                        setDialogState(() => isSaving = false);

                        if (!mounted) return;
                        Navigator.of(dialogContext).pop();

                        if (success) {
                          // Refresh local list to match updated state
                          setState(() {
                            final idx = _activities.indexWhere(
                                    (a) => (a['id'] ?? a['_id']) == id);
                            if (idx != -1) {
                              _activities[idx] = {
                                ..._activities[idx],
                                'distanceKm': dist,
                                'durationMin': dur,
                                'date': activityDate.toIso8601String(),
                              };
                            }
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Activity updated!',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: AppColors.accentGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update. Try again.',
                                  style: GoogleFonts.poppins()),
                              backgroundColor: Colors.red.shade700,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      gradient: glossyGradientDark,
                      borderRadius: 12,
                      child: isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                          : Text('Save Changes',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Activity History',
          style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : _errorMessage != null
          ? Center(
          child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.red)))
          : _activities.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_run, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No activities yet',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium)),
          const SizedBox(height: 6),
          Text('Log a run or connect Strava to get started.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: _activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = _activities[index];
        final dist = a['distanceKm'] ?? a['distance'] ?? 0;
        final dur = a['durationMin'] ?? a['duration'] ?? 0;
        final dateRaw = a['date'] ?? a['createdAt'];
        final DateTime? date =
        dateRaw != null ? DateTime.tryParse(dateRaw)?.toLocal() : null;
        final bool fromStrava = _isFromStrava(a);
        final String pace = _calculatePace(dist, dur);
        final String title = _getTitle(a);

        return _ActivityCard(
          title: title,
          date: date,
          distanceKm: (dist is num) ? dist.toDouble() : 0,
          durationMin: (dur is num) ? dur.toInt() : 0,
          pace: pace,
          fromStrava: fromStrava,
          // Strava activities: edit disabled, delete allowed
          onEdit: fromStrava ? null : () => _openEditDialog(context, a),
          onDelete: () => _confirmDelete(context, a),
        );
      },
    );
  }
}

// ── Helper: listens to two TextEditingControllers ────────────────────────────
class ValueListenableBuilder2<A, B> extends StatefulWidget {
  final TextEditingController first;
  final TextEditingController second;
  final Widget Function(BuildContext, TextEditingController,
      TextEditingController, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  @override
  State<ValueListenableBuilder2> createState() =>
      _ValueListenableBuilder2State();
}

class _ValueListenableBuilder2State extends State<ValueListenableBuilder2> {
  @override
  void initState() {
    super.initState();
    widget.first.addListener(_rebuild);
    widget.second.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.first.removeListener(_rebuild);
    widget.second.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.first, widget.second, null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Activity card — now has edit / delete action buttons
// ═══════════════════════════════════════════════════════════════════════════════
class _ActivityCard extends StatelessWidget {
  final String title;
  final DateTime? date;
  final double distanceKm;
  final int durationMin;
  final String pace;
  final bool fromStrava;
  final VoidCallback? onEdit;    // null = disabled (Strava activities)
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.title,
    required this.date,
    required this.distanceKm,
    required this.durationMin,
    required this.pace,
    required this.fromStrava,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor =
    fromStrava ? const Color(0xFFFC4C02) : AppColors.primaryBlue;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withOpacity(0.7),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Main content row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + badge
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.directions_run, size: 22, color: accentColor),
                    ),
                    const SizedBox(height: 6),
                    _SourceBadge(
                      label: fromStrava ? 'Strava' : 'Manual',
                      icon: fromStrava
                          ? Icons.directions_run
                          : Icons.edit_outlined,
                      color: accentColor,
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Title + date + chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      Text(
                        date != null
                            ? DateFormat('MMM d, yyyy · h:mm a').format(date!)
                            : '—',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textMedium),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatChip(
                              icon: Icons.straighten,
                              label: '${distanceKm.toStringAsFixed(2)} km',
                              color: accentColor),
                          _StatChip(
                              icon: Icons.timer_outlined,
                              label: '$durationMin min',
                              color: AppColors.primaryBlue),
                          _StatChip(
                              icon: Icons.speed,
                              label: '$pace /km',
                              color: const Color(0xFF2ECC71)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider + action buttons ─────────────────────────────────────────
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Edit — disabled and greyed out for Strava activities
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: onEdit != null
                          ? AppColors.primaryBlue
                          : Colors.grey.shade400,
                    ),
                    label: Text(
                      onEdit != null ? 'Edit' : 'Edit (Strava)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onEdit != null
                            ? AppColors.primaryBlue
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.grey.shade200),
                // Delete — always available
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.accentRed),
                    label: Text('Delete',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentRed)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small source badge ────────────────────────────────────────────────────────
class _SourceBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SourceBadge(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Small stat chip ───────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}