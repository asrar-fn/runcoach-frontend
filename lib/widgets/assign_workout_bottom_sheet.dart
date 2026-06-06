// lib/widgets/assign_workout_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/assignment_service.dart';

class AssignWorkoutBottomSheet extends StatefulWidget {
  final String athleteId;
  final String athleteName;
  final VoidCallback? onAssigned; // callback to refresh parent

  const AssignWorkoutBottomSheet({
    super.key,
    required this.athleteId,
    required this.athleteName,
    this.onAssigned,
  });

  /// Static helper to show this sheet
  static Future<void> show(
      BuildContext context, {
        required String athleteId,
        required String athleteName,
        VoidCallback? onAssigned,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignWorkoutBottomSheet(
        athleteId: athleteId,
        athleteName: athleteName,
        onAssigned: onAssigned,
      ),
    );
  }

  @override
  State<AssignWorkoutBottomSheet> createState() =>
      _AssignWorkoutBottomSheetState();
}

class _AssignWorkoutBottomSheetState extends State<AssignWorkoutBottomSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _paceController = TextEditingController();

  String _workoutType = 'Easy Run';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _workoutTypes = [
    'Easy Run',
    'Tempo Run',
    'Interval Training',
    'Long Run',
    'Recovery Run',
    'Hill Repeats',
    'Fartlek',
    'Race Pace',
    'Cross Training',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _distanceController.addListener(_calculatePace);
    _durationController.addListener(_calculatePace);
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _paceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await AssignmentService.createAssignment(
        athleteId: widget.athleteId,
        workoutType: _workoutType,
        title: _titleController.text.trim(),
        distance: _distanceController.text.trim(),
        duration: _durationController.text.trim(),
        scheduledDate: _selectedDate.toIso8601String(),
        instructions: _instructionsController.text.trim(),
        targetPace: _paceController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text('Workout assigned to ${widget.athleteName}!'),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      widget.onAssigned?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _calculatePace() {
    final distance = double.tryParse(_distanceController.text);
    final duration = double.tryParse(_durationController.text);

    if (distance != null && distance > 0 && duration != null && duration > 0) {
      final pace = duration / distance; // min per km

      final minutes = pace.floor();
      final seconds = ((pace - minutes) * 60).round();

      final formattedPace =
          '${minutes}:${seconds.toString().padLeft(2, '0')} /km';

      _paceController.text = formattedPace;
    } else {
      _paceController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: cs.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.assignment_outlined,
                          color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Assign Workout',
                              style: tt.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            'To: ${widget.athleteName}',
                            style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.onSurface.withOpacity(0.5)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Title ─────────────────────────────────────────────────
                _buildLabel('Workout Title *'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _titleController,
                  hint: 'e.g. Morning Tempo Run',
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                // ── Workout Type ──────────────────────────────────────────
                _buildLabel('Workout Type *'),
                const SizedBox(height: 6),
                _buildDropdown(),
                const SizedBox(height: 16),

                // ── Distance + Duration (side by side) ───────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Distance (km) *'),
                          const SizedBox(height: 6),
                          _buildTextField(
                            controller: _distanceController,
                            hint: 'e.g. 10',
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v.trim()) == null) {
                                return 'Invalid number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Duration (min) *'),
                          const SizedBox(height: 6),
                          _buildTextField(
                            controller: _durationController,
                            hint: 'e.g. 60',
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(v.trim()) == null) {
                                return 'Whole number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Target Pace (optional) ────────────────────────────────
                _buildLabel('Target Pace (optional)'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _paceController,
                  hint: 'Auto calculated',
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // ── Scheduled Date ────────────────────────────────────────
                _buildLabel('Scheduled Date *'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: cs.onSurface.withOpacity(0.15), width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: cs.primary, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurface),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            color: cs.onSurface.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Instructions ──────────────────────────────────────────
                _buildLabel('Instructions'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _instructionsController,
                  hint:
                  'e.g. Warm up 10 min, maintain 160–170 bpm, cool down 5 min...',
                  maxLines: 4,
                ),
                const SizedBox(height: 28),

                // ── Submit Button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      disabledBackgroundColor: cs.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.onPrimary,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Assign Workout',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface.withOpacity(0.8),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.4)),
        filled: true,
        fillColor: cs.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurface.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.onSurface.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.onSurface.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _workoutType,
          isExpanded: true,
          dropdownColor: cs.surface,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          icon: Icon(Icons.arrow_drop_down, color: cs.onSurface.withOpacity(0.5)),
          items: _workoutTypes
              .map((t) => DropdownMenuItem(
            value: t,
            child: Text(t),
          ))
              .toList(),
          onChanged: (v) => setState(() => _workoutType = v!),
        ),
      ),
    );
  }
}