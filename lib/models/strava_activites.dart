class StravaActivity {
  final String name;
  final double distanceKm;
  final int durationMin;
  final DateTime date;
  final double? averageSpeed;   // m/s — we'll convert to pace
  final double? elevationGain;  // metres
  final int? heartRateAvg;

  const StravaActivity({
    required this.name,
    required this.distanceKm,
    required this.durationMin,
    required this.date,
    this.averageSpeed,
    this.elevationGain,
    this.heartRateAvg,
  });

  factory StravaActivity.fromJson(Map<String, dynamic> json) {
    return StravaActivity(
      name:          json['name'] ?? 'Run',
      distanceKm:    (json['distanceKm'] ?? 0).toDouble(),
      durationMin:   (json['durationMin'] ?? 0).toInt(),
      date: DateTime.parse(json['date']).toLocal(),
      averageSpeed:  json['averageSpeed']?.toDouble(),
      elevationGain: json['elevationGain']?.toDouble(),
      heartRateAvg:  json['heartRateAvg']?.toInt(),
    );
  }

  /// Pace as "M:SS min/km"
  String get paceString {
    if (distanceKm <= 0 || durationMin <= 0) return '--:--';
    final totalSec = (durationMin * 60) / distanceKm;
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}