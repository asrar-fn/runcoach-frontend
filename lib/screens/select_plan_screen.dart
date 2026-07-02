// lib/screens/select_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/coach_selection_screen.dart';

class SelectPlanScreen extends ConsumerStatefulWidget {
  const SelectPlanScreen({super.key});

  @override
  ConsumerState<SelectPlanScreen> createState() => _SelectPlanScreenState();
}

class _SelectPlanScreenState extends ConsumerState<SelectPlanScreen> {
  // ── Shared light-theme palette
  static const Color _accent1   = Color(0xFF1565C0);
  static const Color _accent2   = Color(0xFFE65100);
  static const Color _bgPage    = Color(0xFFF4F6FB);
  static const Color _cardBg    = Colors.white;
  static const Color _textDark  = Color(0xFF1A1A2E);
  static const Color _textMid   = Color(0xFF6B7280);
  static const Color _textLight = Color(0xFF9CA3AF);
  static const Color _border    = Color(0xFFE5E7EB);

  final PageController _pageController =
  PageController(viewportFraction: 0.82);
  int _currentPage = 0;

  final List<Map<String, dynamic>> _plans = const [
    {
      'distance':        '5K',
      'displayDistance': '5K',
      'title':           'Kouch 2 5K',
      'description':     'Kickstart your running journey with a solid 5km plan.',
      'duration':        '8 Weeks',
      'price':           '₹5,000',
      'popular':         false,
      'colors': [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    },
    {
      'distance':        '10K',
      'displayDistance': '10K',
      'title':           '10K Run Plan',
      'description':     'Elevate your endurance and speed for a strong 10km race.',
      'duration':        '10 Weeks',
      'price':           '₹10,000',
      'popular':         true,
      'colors': [Color(0xFF1565C0), Color(0xFFE65100)],
    },
    {
      'distance':        '21.1K',
      'displayDistance': '21K',
      'title':           'Half Marathon Plan',
      'description':     'Conquer the half marathon with advanced strategies.',
      'duration':        '12 Weeks',
      'price':           '₹15,000',
      'popular':         false,
      'colors': [Color(0xFF0891B2), Color(0xFF06B6D4)],
    },
    {
      'distance':        '42.2K',
      'displayDistance': '42K',
      'title':           'Marathon Run Plan',
      'description':     'The ultimate plan to prepare you for a full marathon.',
      'duration':        '16 Weeks',
      'price':           '₹20,000',
      'popular':         false,
      'colors': [Color(0xFF15803D), Color(0xFF4ADE80)],
    },
    {
      'distance':        '50K',
      'displayDistance': '50K',
      'title':           'Ultra Run Plan',
      'description':     'Push your limits with an extreme ultra-marathon plan.',
      'duration':        '20 Weeks',
      'price':           '₹25,000',
      'popular':         false,
      'colors': [Color(0xFFBE185D), Color(0xFFA855F7)],
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToCoachSelection(Map<String, dynamic> plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachSelectionScreen(
          selectedPlanDistance: plan['distance'] as String,
          planPrice:            plan['price'] as String,
          fromUpgradeFlow:      true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgPage,
      // ── AppBar
      appBar: AppBar(
        backgroundColor:    _cardBg,
        elevation:          0,
        surfaceTintColor:   Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        _bgPage,
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: _textDark, size: 14),
            ),
          ),
        ),
        title: Text(
          'Choose Your Plan',
          style: GoogleFonts.poppins(
            color:      _textDark,
            fontWeight: FontWeight.w700,
            fontSize:   17,
          ),
        ),
        centerTitle: true,
      ),

      body: Column(
        children: [
          // ── Header section
          Container(
            color:   _cardBg,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              children: [
                // Gradient title
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Find your ',
                        style: GoogleFonts.poppins(
                          fontSize:   22,
                          fontWeight: FontWeight.w400,
                          color:      _textDark,
                          height:     1.25,
                        ),
                      ),
                      TextSpan(
                        text: 'perfect plan',
                        style: GoogleFonts.poppins(
                          fontSize:   22,
                          fontWeight: FontWeight.w700,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [_accent1, _accent2],
                            ).createShader(
                                const Rect.fromLTWH(0, 0, 220, 30)),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the training plan that matches your ambition',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textMid),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),

          // ── Card carousel
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  SizedBox(
                    height: screenSize.height * 0.48,
                    child: PageView.builder(
                      controller:  _pageController,
                      itemCount:   _plans.length,
                      onPageChanged: (i) =>
                          setState(() => _currentPage = i),
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        return _PlanCard(
                          plan:       plan,
                          isSelected: _currentPage == index,
                          onSelect:   _navigateToCoachSelection,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Swipe hint
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swipe_rounded,
                          size: 13, color: _textLight),
                      const SizedBox(width: 5),
                      Text(
                        'Swipe to explore all plans',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: _textLight),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Page indicator dots
                  _buildPageIndicator(),

                  const SizedBox(height: 28),

                  // // Selected plan summary pill
                  // _SelectedPlanSummary(
                  //   plan: _plans[_currentPage],
                  // ),
                  //
                  // const SizedBox(height: 20),

                  // Next button
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () =>
                          _navigateToCoachSelection(_plans[_currentPage]),
                      child: Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accent1, _accent2],
                            begin:  Alignment.centerLeft,
                            end:    Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:      _accent1.withOpacity(0.35),
                              blurRadius: 18,
                              offset:     const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Continue with ${_plans[_currentPage]['displayDistance']} Plan',
                                style: GoogleFonts.poppins(
                                  fontSize:   16,
                                  fontWeight: FontWeight.w700,
                                  color:      Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 11, color: _textLight),
                      const SizedBox(width: 5),
                      Text(
                        'You can upgrade your plan anytime',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: _textLight),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_plans.length, (index) {
        final bool active = _currentPage == index;
        final List<Color> dotColors =
        _plans[index]['colors'] as List<Color>;

        return GestureDetector(
          onTap: () => _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve:    Curves.easeInOut,
          ),
          child: AnimatedContainer(
            duration:  const Duration(milliseconds: 300),
            curve:     Curves.easeInOut,
            width:     active ? 28.0 : 9.0,
            height:    9.0,
            margin:    const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: active
                  ? LinearGradient(
                colors: dotColors,
                begin:  Alignment.centerLeft,
                end:    Alignment.centerRight,
              )
                  : null,
              color:     active ? null : _border,
              boxShadow: active
                  ? [
                BoxShadow(
                  color:      dotColors.first.withOpacity(0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
                  : [],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Selected Plan Summary ────────────────────────────────────────────────────

class _SelectedPlanSummary extends StatelessWidget {
  final Map<String, dynamic> plan;

  static const Color _accent1  = Color(0xFF1565C0);
  static const Color _accent2  = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B7280);
  static const Color _border   = Color(0xFFE5E7EB);

  const _SelectedPlanSummary({required this.plan});

  @override
  Widget build(BuildContext context) {
    final List<Color> planColors = plan['colors'] as List<Color>;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color:     Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset:    const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Colored distance circle
            Container(
              width:  48,
              height: 48,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                gradient: LinearGradient(
                  colors: planColors,
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      planColors.first.withOpacity(0.35),
                    blurRadius: 10,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  plan['displayDistance'] as String,
                  style: GoogleFonts.poppins(
                    color:      Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize:   13,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan['title'] as String,
                    style: GoogleFonts.poppins(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${plan['duration']}  ·  ${plan['price']}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _textMid),
                  ),
                ],
              ),
            ),

            // Price badge
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_accent1, _accent2],
              ).createShader(bounds),
              child: Text(
                plan['price'] as String,
                style: GoogleFonts.poppins(
                  fontSize:   16,
                  fontWeight: FontWeight.w800,
                  color:      Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isSelected;
  final Function(Map<String, dynamic>) onSelect;

  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B7280);
  static const Color _border   = Color(0xFFE5E7EB);

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> cardColors = plan['colors'] as List<Color>;
    final String displayLabel    = plan['displayDistance'] as String;
    final double labelFontSize   = displayLabel.length <= 3 ? 22 : 17;

    return AnimatedScale(
      scale:    isSelected ? 1.0 : 0.88,
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity:  isSelected ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onTap: () => onSelect(plan),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? cardColors.first.withOpacity(0.6)
                    : _border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? cardColors.first.withOpacity(0.18)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 24 : 8,
                  offset:     const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisAlignment:  MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Popular badge or spacer
                  if (plan['popular'] as bool)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: cardColors,
                          begin:  Alignment.centerLeft,
                          end:    Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:      cardColors.first.withOpacity(0.35),
                            blurRadius: 8,
                            offset:     const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        'MOST POPULAR',
                        style: GoogleFonts.poppins(
                          color:       Colors.white,
                          fontWeight:  FontWeight.w700,
                          fontSize:    9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 6),

                  // Distance circle
                  Container(
                    width:  76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: cardColors,
                        begin:  Alignment.topLeft,
                        end:    Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:      cardColors.first.withOpacity(0.4),
                          blurRadius: 16,
                          offset:     const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayLabel,
                        style: GoogleFonts.poppins(
                          color:      Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize:   labelFontSize,
                        ),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    plan['title'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color:      _textDark,
                      fontSize:   17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  Text(
                    plan['description'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color:  _textMid,
                      height: 1.45,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Duration + Price row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_rounded,
                            color: cardColors.first, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          plan['duration'] as String,
                          style: GoogleFonts.inter(
                            color:      _textDark,
                            fontWeight: FontWeight.w600,
                            fontSize:   12,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 1, height: 12,
                          color: _border,
                        ),
                        Icon(Icons.payments_rounded,
                            color: cardColors.last, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          plan['price'] as String,
                          style: GoogleFonts.inter(
                            color:      _textDark,
                            fontWeight: FontWeight.w600,
                            fontSize:   12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}