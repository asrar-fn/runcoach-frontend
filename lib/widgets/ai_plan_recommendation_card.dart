import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/ai_recommendation_service.dart';

class AIPlanRecommendationCard extends StatefulWidget {
  final VoidCallback onUpgradeTap;
  const AIPlanRecommendationCard({super.key, required this.onUpgradeTap});

  @override
  State<AIPlanRecommendationCard> createState() => _AIPlanRecommendationCardState();
}

class _AIPlanRecommendationCardState extends State<AIPlanRecommendationCard> {
  PlanRecommendation? _recommendation;
  bool _isLoading = false;
  bool _hasFetched = false;
  String? _error;

  Future<void> _fetchRecommendation() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await AiRecommendationService.fetchRecommendation();
      setState(() {
        _recommendation = result;
        _hasFetched = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Could not load recommendation. Try again.";
        _isLoading = false;
      });
    }
  }

  // ── Color per distance plan ──
  Color _planColor(String plan) {
    final p = plan.toUpperCase();
    if (p.contains('5K'))   return const Color(0xFF2ECC71);
    if (p.contains('10K'))  return const Color(0xFF2575FC);
    if (p.contains('21'))   return const Color(0xFFF7941D);
    if (p.contains('42'))   return const Color(0xFF9B59B6);
    if (p.contains('50'))   return const Color(0xFFE74C3C);
    return const Color(0xFF2575FC);
  }

  // ── Tier accent: Beginner = softer, Advanced = vivid ──
  Color _tierColor(String tier) {
    return tier.toLowerCase().contains('advanced')
        ? const Color(0xFFE74C3C)
        : const Color(0xFF27AE60);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFFE65100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "AI Performance Analysis",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? _buildLoadingState()
                : !_hasFetched
                ? _buildInitialState()
                : _error != null
                ? _buildErrorState()
                : _recommendation == null
                ? _buildNoDataState()
                : _buildResultState(),
          ),
        ],
      ),
    );
  }

  // ── States ────────────────────────────────────────────────────────

  Widget _buildInitialState() {
    return Column(
      children: [
        const Icon(Icons.psychology_outlined, size: 48, color: Color(0xFF2575FC)),
        const SizedBox(height: 12),
        Text(
          "Let our AI analyze your running history, lifestyle, and profile to recommend the perfect training plan.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF7F8C8D)),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _fetchRecommendation,
            icon: const Icon(Icons.auto_awesome),
            label: Text("Analyze My Performance",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2575FC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const CircularProgressIndicator(color: Color(0xFF2575FC)),
        const SizedBox(height: 16),
        Text("Analyzing your runs, profile & lifestyle...",
            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF7F8C8D))),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 40, color: Color(0xFFE74C3C)),
        const SizedBox(height: 8),
        Text(_error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: const Color(0xFFE74C3C))),
        const SizedBox(height: 12),
        TextButton(onPressed: _fetchRecommendation, child: const Text("Try Again")),
      ],
    );
  }

  Widget _buildNoDataState() {
    return Column(
      children: [
        const Icon(Icons.directions_run, size: 40, color: Color(0xFF7F8C8D)),
        const SizedBox(height: 8),
        Text("Log a few runs first so we can analyze your performance!",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF7F8C8D))),
      ],
    );
  }

  // ── Main Result ───────────────────────────────────────────────────

  Widget _buildResultState() {
    final rec       = _recommendation!;
    final planColor = _planColor(rec.recommendedPlan);
    final tierColor = _tierColor(rec.planTier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Current Level  →  Recommended Plan ──
        _buildLevelProgressRow(rec, planColor, tierColor),

        const SizedBox(height: 20),

        // ── Readiness Score Bar ──
        Row(
          children: [
            Text("Readiness for ${rec.recommendedPlan} ${rec.planTier}",
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C3E50))),
            const Spacer(),
            Text("${rec.readinessScore}%",
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: planColor)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: rec.readinessScore / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(planColor),
          ),
        ),

        const SizedBox(height: 16),

        // ── AI Reasoning ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(rec.reasoning,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: const Color(0xFF2C3E50), height: 1.5)),
        ),

        const SizedBox(height: 10),

        // ── Lifestyle Note ──
        if (rec.lifestyleNote.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bedtime_outlined,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rec.lifestyleNote,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: const Color(0xFF78350F))),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // ── Strengths & Improvements ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildBulletList(
                "💪 Strengths", rec.strengthPoints, const Color(0xFF2ECC71))),
            const SizedBox(width: 12),
            Expanded(child: _buildBulletList(
                "📈 To Improve", rec.improvementAreas, const Color(0xFFF7941D))),
          ],
        ),

        const SizedBox(height: 16),

        // ── Next Step Tip ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                planColor.withOpacity(0.08),
                planColor.withOpacity(0.02)
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: planColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: planColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(rec.nextStepTip,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF2C3E50))),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Upgrade CTA ──
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onUpgradeTap,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: Text(
              "Start ${rec.recommendedPlan} ${rec.planTier} Plan",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: planColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _fetchRecommendation,
            child: Text("Re-analyze",
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF7F8C8D))),
          ),
        ),
      ],
    );
  }

  // ── Current Level → Recommended Plan row ─────────────────────────

  Widget _buildLevelProgressRow(
      PlanRecommendation rec, Color planColor, Color tierColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        children: [
          // "You are currently" label
          Text("YOUR CURRENT LEVEL",
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7F8C8D),
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),

          // Current level badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: _planColor(rec.currentLevel), width: 2),
              boxShadow: [
                BoxShadow(
                    color: _planColor(rec.currentLevel).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Text(
              rec.currentLevel,
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _planColor(rec.currentLevel)),
            ),
          ),

          const SizedBox(height: 12),

          // Arrow + "next plan" connector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Expanded(child: Divider(color: Color(0xFFDEE2E6))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        color: planColor, size: 20),
                    Text("Recommended",
                        style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: const Color(0xFF7F8C8D),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFDEE2E6))),
            ],
          ),

          const SizedBox(height: 12),

          // Recommended plan badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: planColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: planColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: planColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Text(
                  rec.recommendedPlan,
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: planColor),
                ),
                // Tier chip
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rec.planTier.toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: tierColor,
                        letterSpacing: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bullet list helper ────────────────────────────────────────────

  Widget _buildBulletList(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50))),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, size: 6, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(item,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: const Color(0xFF7F8C8D))),
              ),
            ],
          ),
        )),
      ],
    );
  }
}