  // lib/models/athlete.dart
  class Athlete {
    final String id;
    final String name;
    final String email;
    final String plan;
    final int progressPct;
    final double assignedDistKm;
    final double completedDistKm;
    final String experience;
    final String createdAt;
    final String dateOfBirth;
    final String city;
    final String? role; // <--- ADD THIS LINE
    final String? workRoutine;
    final String? sleepHours;
    final String? stressLevel;
    final String? eatingHabits;
    final List<String>? energyFactors;

    Athlete({
      required this.id,
      required this.name,
      required this.email,
      required this.plan,
      required this.progressPct,
      required this.assignedDistKm,
      required this.completedDistKm,
      required this.experience,
      required this.createdAt,
      required this.dateOfBirth,
      required this.city,
      this.role, // <--- ADD THIS LINE
      this.workRoutine,
      this.sleepHours,
      this.stressLevel,
      this.eatingHabits,
      this.energyFactors,
    });

    factory Athlete.fromJson(Map<String, dynamic> json) {
      // You'll need to adapt this based on the exact structure of your user object from the backend
      // This is a *sample* adaptation.
      // Assuming 'plan' is available directly or derived.
      // Assuming 'progressPct', 'assignedDistKm', 'completedDistKm' need to be calculated or are part of a sub-object.
      // For now, let's use some dummy logic for progress if not directly provided by the backend.

      // Example: Backend might return 'trainingPlan' instead of 'plan'
      final String planName = json['plan'] ?? 'No Plan Assigned';

      // Example: How to calculate progress from backend data if it gives 'totalDistance' and 'completedDistance'
      double totalDistance = (json['assignedDistKm'] as num?)?.toDouble() ?? 100.0; // Default for demo
      double completedDistance = (json['completedDistKm'] as num?)?.toDouble() ?? 0.0; // Default for demo
      int calculatedProgressPct = totalDistance > 0 ? ((completedDistance / totalDistance) * 100).toInt() : 0;

      return Athlete(
        id: json['id'],
        name: json['name'] ?? '${json['firstName']} ${json['lastName']}', // Combine first/last if name isn't direct
        email: json['email'],
        plan: planName,
        progressPct: json['progressPct'] ?? calculatedProgressPct, // Use backend's or calculate
        assignedDistKm: (json['assignedDistKm'] as num?)?.toDouble() ?? totalDistance,
        completedDistKm: (json['completedDistKm'] as num?)?.toDouble() ?? completedDistance,
        experience: json['experienceLevel'] ?? 'Not specified',
        createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
        dateOfBirth: json['dateOfBirth'] ?? 'Not specified',
        city: json['city'] ?? 'Unknown',
        role: json['role'], // <--- ADD THIS LINE: Map 'role' from JSON
        workRoutine: json['workRoutine'],
        sleepHours: json['sleepHours'],
        stressLevel: json['stressLevel'],
        eatingHabits: json['eatingHabits'],
        energyFactors: json['energyFactors'] != null
            ? List<String>.from(json['energyFactors'])
            : null,
      );
    }
  }