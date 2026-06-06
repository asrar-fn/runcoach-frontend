import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/AthleteDashboard.dart' show AppState, AppColors;
import '../screens/membership_selection_screen.dart';

const _kGradient = LinearGradient(
  colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ── Plan levels in journey order (left = beginner, right = advanced) ─────────
const List<Map<String, dynamic>> _kPlanLevels = [
  {'label': '5K',  'tier': 'Beginner',  'minScore': 0},
  {'label': '5K',  'tier': 'Advanced',  'minScore': 18},
  {'label': '10K', 'tier': 'Beginner',  'minScore': 35},
  {'label': '10K', 'tier': 'Advanced',  'minScore': 50},
  {'label': '21K', 'tier': 'Beginner',  'minScore': 63},
  {'label': '21K', 'tier': 'Advanced',  'minScore': 74},
  {'label': '42K', 'tier': 'Beginner',  'minScore': 83},
  {'label': '42K', 'tier': 'Advanced',  'minScore': 91},
  {'label': '50K', 'tier': 'Beginner',  'minScore': 96},
  {'label': '50K', 'tier': 'Advanced',  'minScore': 100},
];

// Returns 0.0–1.0 position for a plan name on the track
double _planPosition(String planLabel, String planTier) {
  for (int i = 0; i < _kPlanLevels.length; i++) {
    if (_kPlanLevels[i]['label'] == planLabel &&
        _kPlanLevels[i]['tier'] == planTier) {
      return i / (_kPlanLevels.length - 1).toDouble();
    }
  }
  return 0.0;
}

// Returns 0.0–1.0 from readiness score using the minScore buckets
double _scoreToPct(int score) {
  for (int i = _kPlanLevels.length - 1; i >= 0; i--) {
    if (score >= (_kPlanLevels[i]['minScore'] as int)) {
      final startScore = _kPlanLevels[i]['minScore'] as int;
      final endScore = i < _kPlanLevels.length - 1
          ? _kPlanLevels[i + 1]['minScore'] as int
          : 100;
      final segmentFrac =
          (score - startScore) / (endScore - startScore).toDouble();
      final startPct = i / (_kPlanLevels.length - 1).toDouble();
      final endPct = i < _kPlanLevels.length - 1
          ? (i + 1) / (_kPlanLevels.length - 1).toDouble()
          : 1.0;
      return startPct + segmentFrac * (endPct - startPct);
    }
  }
  return 0.0;
}

class UnifiedAIAnalysisCard extends StatelessWidget {
  final VoidCallback? onUpgradeTap;
  const UnifiedAIAnalysisCard({super.key, this.onUpgradeTap});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isLoading = appState.isLoadingStravaAnalysis;
    final analysis = appState.stravaAnalysis;
    final rec = analysis?['recommendation'];

    final usingStrava = appState.stravaConnected &&
        appState.stravaActivities.isNotEmpty;
    final sourceLabel = usingStrava
        ? '${appState.stravaActivities.length} Strava runs'
        : '${appState.activities.length} logged runs';
    final sourceIcon =
    usingStrava ? Icons.directions_run : Icons.upload_file;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200.withOpacity(0.8),
              blurRadius: 15,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              gradient: _kGradient,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Coach Analysis',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text('Powered by Groq',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.85))),
                        ],
                      ),
                    ),
                    if (rec != null)
                      GestureDetector(
                        onTap: () => appState.fetchStravaAnalysis(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('Re-analyse',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sourceIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        usingStrava
                            ? 'Using $sourceLabel'
                            : 'Using $sourceLabel (connect Strava for more)',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: isLoading
                ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(
                    color: Color(0xFF1976D2)),
              ),
            )
                : rec == null
                ? _buildPromptState(
                context, appState, usingStrava, sourceLabel)
                : _buildResult(context, rec),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildPromptState(BuildContext context, AppState appState,
      bool usingStrava, String sourceLabel) {
    final hasData = usingStrava
        ? appState.stravaActivities.isNotEmpty
        : appState.activities.isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0x1A1976D2), Color(0x1AE6783A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
          const Icon(Icons.insights, size: 48, color: Color(0xFF1976D2)),
        ),
        const SizedBox(height: 16),
        Text('Get Your AI Coaching Report',
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C3E50))),
        const SizedBox(height: 8),
        Text(
          hasData
              ? 'Analysing $sourceLabel to show you exactly where you stand and what plan to aim for next.'
              : 'Log some runs first so the AI has data to analyse.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF7F8C8D),
              height: 1.5),
        ),
        if (hasData) ...[
          const SizedBox(height: 16),
          _previewChip(Icons.person_outline,
              'Where you currently stand on the plan scale'),
          _previewChip(
              Icons.flag_outlined, 'What plan is recommended & why'),
          _previewChip(
              Icons.bar_chart, 'Your readiness score visualised'),
          _previewChip(Icons.thumb_up_outlined,
              'Strengths & areas to improve'),
        ],
        const SizedBox(height: 24),
        if (hasData)
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () => appState.fetchStravaAnalysis(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Run AI Analysis',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF1976D2), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Log at least 1 run manually or connect Strava to unlock AI analysis.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF1976D2)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _previewChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1976D2)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF7F8C8D))),
          ),
        ],
      ),
    );
  }

  // ── Result ─────────────────────────────────────────────────────────────────
  Widget _buildResult(BuildContext context, Map<String, dynamic> rec) {
    final strengthPoints   = rec['strengthPoints']   as List? ?? [];
    final improvementAreas = rec['improvementAreas'] as List? ?? [];
    final recommendedPlan  = rec['recommendedPlan']  ?? '';
    final planTier         = rec['planTier']         ?? '';
    final currentLevel     = rec['currentLevel']     ?? '';
    final readinessScore   = (rec['readinessScore']  ?? 0) as num;

    final currentParts = currentLevel.toString().split(' ');
    final currentLabel = currentParts.isNotEmpty ? currentParts[0] : '';
    final currentTier  =
    currentParts.length > 1 ? currentParts.sublist(1).join(' ') : '';

    final scorePos       = _scoreToPct(readinessScore.toInt());
    final recommendedPos = _planPosition(recommendedPlan, planTier);

    Color  readinessColor;
    String readinessLabel;
    if (readinessScore >= 80) {
      readinessColor = const Color(0xFF2ECC71);
      readinessLabel = 'Race Ready';
    } else if (readinessScore >= 60) {
      readinessColor = const Color(0xFF1976D2);
      readinessLabel = 'Building Well';
    } else if (readinessScore >= 40) {
      readinessColor = const Color(0xFFE6783A);
      readinessLabel = 'Getting Started';
    } else {
      readinessColor = const Color(0xFF9B59B6);
      readinessLabel = 'Early Stage';
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ══════════════════════════════════════════════════════════════════
        // SECTION 1 — Current level → Recommended plan (with arrow)
        // ══════════════════════════════════════════════════════════════════
        _sectionLabel('Where you stand'),
        const SizedBox(height: 12),

        _CurrentToRecommendedCard(
          currentLevel:    currentLevel,
          recommendedPlan: '$recommendedPlan $planTier',
          readinessScore:  readinessScore.toInt(),
          readinessColor:  readinessColor,
          readinessLabel:  readinessLabel,
        ),

        const SizedBox(height: 20),

        // ══════════════════════════════════════════════════════════════════
        // SECTION 3 — What this means for you
        // ══════════════════════════════════════════════════════════════════
        if (rec['reasoning'] != null) ...[
          _sectionLabel('What this means for you'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text('"${rec['reasoning']}"',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF7F8C8D),
                    height: 1.6)),
          ),
          const SizedBox(height: 20),
        ],

        // ══════════════════════════════════════════════════════════════════
        // SECTION 4 — Your focus this week
        // ══════════════════════════════════════════════════════════════════
        if (rec['nextStepTip'] != null) ...[
          _sectionLabel('Your focus this week'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1976D2).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: _kGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(rec['nextStepTip'],
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1976D2),
                          height: 1.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ══════════════════════════════════════════════════════════════════
        // SECTION 5 — Strengths + Improvements
        // ══════════════════════════════════════════════════════════════════
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _pointsList('💪 Strengths', strengthPoints,
                    const Color(0xFF2ECC71))),
            const SizedBox(width: 12),
            Expanded(
                child: _pointsList('📈 Improve', improvementAreas,
                    const Color(0xFFE6783A))),
          ],
        ),
        const SizedBox(height: 16),

        // ══════════════════════════════════════════════════════════════════
        // SECTION 6 — Lifestyle note
        // ══════════════════════════════════════════════════════════════════
        if (rec['lifestyleNote'] != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF2ECC71).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.spa_outlined,
                    color: Color(0xFF2ECC71), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rec['lifestyleNote'],
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF2C3E50),
                          height: 1.4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ══════════════════════════════════════════════════════════════════
        // UPGRADE CTA
        // ══════════════════════════════════════════════════════════════════
        if (recommendedPlan.isNotEmpty)
          GestureDetector(
            onTap: () {
              if (onUpgradeTap != null) {
                onUpgradeTap!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MembershipSelectionScreen(),
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Upgrade to $recommendedPlan $planTier Plan',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C3E50)));

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _readinessExplainer(
      int score, String current, String recPlan, String tier) {
    if (score >= 80)
      return 'You\'re training at $current level and are very close to fully ready for a $recPlan $tier plan. Keep your current volume going.';
    if (score >= 60)
      return 'You\'re at $current level. Your score of $score/100 puts you solidly between $current and $recPlan $tier — a few more consistent weeks and you\'ll be ready to step up.';
    if (score >= 40)
      return 'You\'re at $current level. A score of $score/100 means you have the base, but consistency is the missing piece before moving to $recPlan $tier.';
    return 'You\'re in the early $current stage (score $score/100). Focus on running 3× per week before stepping up to $recPlan $tier.';
  }

  Widget _pointsList(String title, List items, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 8),
          ...items.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• $p',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF2C3E50),
                    height: 1.4)),
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Current Level → Recommended Plan card with downward arrow between them
// ═══════════════════════════════════════════════════════════════════════════════
class _CurrentToRecommendedCard extends StatelessWidget {
  final String currentLevel;
  final String recommendedPlan;
  final int    readinessScore;
  final Color  readinessColor;
  final String readinessLabel;

  const _CurrentToRecommendedCard({
    required this.currentLevel,
    required this.recommendedPlan,
    required this.readinessScore,
    required this.readinessColor,
    required this.readinessLabel,
  });

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [

          // ── TOP: Current level ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50).withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3E50).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: Color(0xFF2C3E50), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are currently at',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF7F8C8D))),
                      const SizedBox(height: 2),
                      Text(currentLevel,
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2C3E50))),
                    ],
                  ),
                ),
                // Readiness score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: readinessColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: readinessColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('$readinessScore/100',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: readinessColor)),
                      Text(readinessLabel,
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: readinessColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── MIDDLE: Arrow with progress bar ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Progress',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF7F8C8D))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor:
                            (readinessScore / 100.0).clamp(0.0, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1976D2),
                                    Color(0xFFE6783A)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$readinessScore%',
                        style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: readinessColor)),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  children: [
                    Container(
                      width: 2,
                      height: 14,
                      color: const Color(0xFF1976D2).withOpacity(0.4),
                    ),
                    CustomPaint(
                      size: const Size(14, 8),
                      painter: _DownArrowPainter(
                          color: const Color(0xFF1976D2)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // ── BOTTOM: Recommended plan ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x141976D2), Color(0x14E6783A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: _kGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI suggests you are ready for',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF1976D2))),
                      const SizedBox(height: 2),
                      Text(recommendedPlan,
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1976D2))),
                    ],
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

// ── Small downward arrowhead painter ─────────────────────────────────────────
class _DownArrowPainter extends CustomPainter {
  final Color color;
  const _DownArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DownArrowPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Plan Journey Track — left = beginner, right = advanced
// ═══════════════════════════════════════════════════════════════════════════════
class _PlanJourneyTrack extends StatelessWidget {
  final double scorePos;
  final double recommendedPos;
  final String currentLevel;
  final String recommendedPlan;
  final Color  readinessColor;

  const _PlanJourneyTrack({
    required this.scorePos,
    required this.recommendedPos,
    required this.currentLevel,
    required this.recommendedPlan,
    required this.readinessColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const topLabelH  = 36.0;
      const arrowH     = 14.0;
      const trackH     = 16.0;
      const arrowBH    = 14.0;
      const botLabelH  = 36.0;
      const planNamesH = 18.0;
      const totalH = topLabelH + arrowH + trackH + arrowBH + botLabelH + planNamesH;

      return SizedBox(
        width: width,
        height: totalH,
        child: CustomPaint(
          painter: _JourneyPainter(
            totalWidth:     width,
            topLabelH:      topLabelH,
            arrowH:         arrowH,
            trackH:         trackH,
            arrowBH:        arrowBH,
            botLabelH:      botLabelH,
            planNamesH:     planNamesH,
            scorePos:       scorePos,
            recommendedPos: recommendedPos,
            currentLevel:   currentLevel,
            recommendedPlan:recommendedPlan,
            readinessColor: readinessColor,
            planLevels:     _kPlanLevels,
          ),
        ),
      );
    });
  }
}

class _JourneyPainter extends CustomPainter {
  final double totalWidth;
  final double topLabelH;
  final double arrowH;
  final double trackH;
  final double arrowBH;
  final double botLabelH;
  final double planNamesH;
  final double scorePos;
  final double recommendedPos;
  final String currentLevel;
  final String recommendedPlan;
  final Color  readinessColor;
  final List<Map<String, dynamic>> planLevels;

  const _JourneyPainter({
    required this.totalWidth,
    required this.topLabelH,
    required this.arrowH,
    required this.trackH,
    required this.arrowBH,
    required this.botLabelH,
    required this.planNamesH,
    required this.scorePos,
    required this.recommendedPos,
    required this.currentLevel,
    required this.recommendedPlan,
    required this.readinessColor,
    required this.planLevels,
  });

  static const double _padH = 16.0;
  double _x(double frac) => _padH + frac * (totalWidth - _padH * 2);

  double get _trackTop    => topLabelH + arrowH;
  double get _trackCY     => _trackTop + trackH / 2;
  double get _trackBottom => _trackTop + trackH;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Track background
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_padH, _trackTop, totalWidth - _padH * 2, trackH),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect,
        Paint()..color = const Color(0xFFE8ECF0)..style = PaintingStyle.fill);

    // 2. Filled portion
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(_padH, _trackTop,
          _x(scorePos) - _padH + 8, trackH),
      const Radius.circular(8),
    );
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF1976D2), Color(0xFFE6783A)],
      ).createShader(Rect.fromLTWH(
          _padH, _trackTop, _x(scorePos) - _padH + 8, trackH))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(fillRect, fillPaint);

    // 3. Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < planLevels.length; i++) {
      final fx = _x(i / (planLevels.length - 1).toDouble());
      canvas.drawLine(
          Offset(fx, _trackTop + 3), Offset(fx, _trackBottom - 3),
          tickPaint);
    }

    // 4. Plan name labels
    final nameStyle = TextStyle(
      color: const Color(0xFF7F8C8D),
      fontSize: 9,
      fontFamily: 'Poppins',
    );
    for (int i = 0; i < planLevels.length; i++) {
      if (i % 2 != 0) continue;
      final fx  = _x(i / (planLevels.length - 1).toDouble());
      final lbl = planLevels[i]['label'] as String;
      _drawCentredText(canvas, lbl, fx,
          _trackBottom + arrowBH + botLabelH + 4, nameStyle, 40);
    }

    // 5. "You" pin — ABOVE track
    final youX = _x(scorePos);
    final stemPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(youX, topLabelH), Offset(youX, _trackTop), stemPaint);
    _drawArrowHead(canvas, youX, _trackTop, pointing: _ArrowDir.down,
        color: const Color(0xFF2C3E50), size: 6);
    _drawPill(
      canvas: canvas,
      cx: youX,
      cy: topLabelH / 2,
      text: 'You: $currentLevel',
      bgColor: const Color(0xFF2C3E50),
      textColor: Colors.white,
    );

    // 6. Recommended pin — BELOW track
    final recX = _x(recommendedPos);
    final recStemPaint = Paint()
      ..color = const Color(0xFF1976D2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(recX, _trackBottom),
        Offset(recX, _trackBottom + arrowBH + 4),
        recStemPaint);
    _drawArrowHead(canvas, recX, _trackBottom, pointing: _ArrowDir.up,
        color: const Color(0xFF1976D2), size: 6);
    _drawPill(
      canvas: canvas,
      cx: recX,
      cy: _trackBottom + arrowBH + botLabelH / 2 + 4,
      text: 'Goal: $recommendedPlan',
      bgColor: const Color(0xFF1976D2),
      textColor: Colors.white,
    );

    // 7. Score dot
    _drawDot(canvas, youX, _trackCY,
        outerR: 7, innerR: 3.5,
        outerColor: Colors.white,
        innerColor: const Color(0xFF2C3E50),
        strokeColor: const Color(0xFF2C3E50));

    // 8. Recommended dot
    _drawDot(canvas, recX, _trackCY,
        outerR: 6, innerR: 3,
        outerColor: Colors.white,
        innerColor: const Color(0xFF1976D2),
        strokeColor: const Color(0xFF1976D2));
  }

  void _drawDot(Canvas canvas, double cx, double cy,
      {required double outerR, required double innerR,
        required Color outerColor, required Color innerColor,
        required Color strokeColor}) {
    canvas.drawCircle(
        Offset(cx, cy), outerR,
        Paint()..color = outerColor..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(cx, cy), outerR,
        Paint()
          ..color = strokeColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(
        Offset(cx, cy), innerR,
        Paint()..color = innerColor..style = PaintingStyle.fill);
  }

  void _drawArrowHead(Canvas canvas, double cx, double tipY,
      {required _ArrowDir pointing,
        required Color color,
        required double size}) {
    final path = Path();
    if (pointing == _ArrowDir.down) {
      path
        ..moveTo(cx, tipY)
        ..lineTo(cx - size, tipY - size)
        ..lineTo(cx + size, tipY - size)
        ..close();
    } else {
      path
        ..moveTo(cx, tipY)
        ..lineTo(cx - size, tipY + size)
        ..lineTo(cx + size, tipY + size)
        ..close();
    }
    canvas.drawPath(path,
        Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawPill({
    required Canvas canvas,
    required double cx,
    required double cy,
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          )),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 160);

    const pillPadH = 10.0;
    const pillPadV = 5.0;
    const pillR = Radius.circular(11);

    final pillW = tp.width + pillPadH * 2;
    final pillH = tp.height + pillPadV * 2;

    final left = (cx - pillW / 2).clamp(0.0, totalWidth - pillW);
    final top  = cy - pillH / 2;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, pillW, pillH), pillR),
        Paint()..color = bgColor..style = PaintingStyle.fill);

    tp.paint(canvas, Offset(left + pillPadH, top + pillPadV));
  }

  void _drawCentredText(Canvas canvas, String text, double cx, double cy,
      TextStyle style, double maxW) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_JourneyPainter old) =>
      old.scorePos != scorePos || old.recommendedPos != recommendedPos;
}

enum _ArrowDir { up, down }