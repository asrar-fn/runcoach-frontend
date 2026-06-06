// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/models/activity.dart   (replace your existing Activity class)
// ─────────────────────────────────────────────────────────────────────────────

class Activity {
  final String? id;
  final String? type;
  final double? distanceKm;
  final int? durationMin;
  final DateTime? date;
  final DateTime? createdAt;
  final String source;       // "manual" | "strava"
  final String? stravaId;    // non-null when source == "strava"
  final String? notes;       // Strava run name stored here

  Activity({
    this.id,
    this.type,
    this.distanceKm,
    this.durationMin,
    this.date,
    this.createdAt,
    this.source = "manual",
    this.stravaId,
    this.notes,
  });

  bool get isFromStrava => source == "strava";

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? json['_id'],
      type: json['type'],
      distanceKm: (json['distanceKm'] ?? json['distance'])?.toDouble(),
      durationMin: (json['durationMin'] ?? json['duration'])?.toInt(),
      date: _safeDate(json['date'] ?? json['createdAt']),
      source: json['source'] ?? 'manual',
      stravaId: json['stravaId'],
      notes: json['notes'],
    );
  }
}

DateTime? _safeDate(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}