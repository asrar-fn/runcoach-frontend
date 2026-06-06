import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_storage_service.dart';

class PlanRecommendation {
  final String currentLevel;      // e.g. "5K Advanced"
  final String recommendedPlan;   // e.g. "10K"
  final String planTier;
  final String confidenceLevel;
  final String reasoning;
  final int readinessScore;
  final List<String> strengthPoints;
  final List<String> improvementAreas;
  final String nextStepTip;
  final String lifestyleNote;

  PlanRecommendation({
    required this.currentLevel,
    required this.recommendedPlan,
    required this.planTier,
    required this.confidenceLevel,
    required this.reasoning,
    required this.readinessScore,
    required this.strengthPoints,
    required this.improvementAreas,
    required this.nextStepTip,
    required this.lifestyleNote,
  });

  factory PlanRecommendation.fromJson(Map<String, dynamic> json) {
    return PlanRecommendation(
      currentLevel:     json['currentLevel']    ?? 'Unknown',
      recommendedPlan:  json['recommendedPlan'] ?? '5K',
      planTier:         json['planTier']        ?? 'Beginner',
      confidenceLevel:  json['confidenceLevel'] ?? 'low',
      reasoning:        json['reasoning']       ?? '',
      readinessScore:   (json['readinessScore'] as num?)?.toInt() ?? 50,
      strengthPoints:   List<String>.from(json['strengthPoints']   ?? []),
      improvementAreas: List<String>.from(json['improvementAreas'] ?? []),
      nextStepTip:      json['nextStepTip']     ?? '',
      lifestyleNote:    json['lifestyleNote']   ?? '',
    );
  }
}

class AiRecommendationService {
  static Future<PlanRecommendation?> fetchRecommendation() async {
    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/ai/recommend-plan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['recommendation'] != null) {
          return PlanRecommendation.fromJson(data['recommendation']);
        }
      }
      return null;
    } catch (e) {
      print('AI recommendation error: $e');
      return null;
    }
  }
}