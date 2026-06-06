import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/auth_storage_service.dart';
import 'dummy_payment_screen.dart';
import '../config/api_config.dart'; // adjust path as needed

// ── Riverpod provider
final coachesProvider = FutureProvider<List<dynamic>>((ref) async {
  final apiService = ApiService();
  return await apiService.getCoaches();
});

// ── Price helper
String? getCoachPriceForPlan(dynamic coach, String? planDistance) {
  if (planDistance == null || coach == null) return null;
  final pricing = coach['pricing'] as Map<String, dynamic>? ?? {};
  if (pricing.containsKey(planDistance) && pricing[planDistance] != null) {
    final n = pricing[planDistance];
    if (n is num) {
      return NumberFormat.currency(
          locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(n);
    }
  }
  return null;
}

class CoachSelectionScreen extends ConsumerStatefulWidget {
  final String? selectedPlanDistance;
  final bool fromUpgradeFlow;
  final String planPrice;

  const CoachSelectionScreen({
    super.key,
    required this.selectedPlanDistance,
    this.fromUpgradeFlow = false,
    this.planPrice = '',
  });

  @override
  ConsumerState<CoachSelectionScreen> createState() =>
      _CoachSelectionScreenState();
}

class _CoachSelectionScreenState
    extends ConsumerState<CoachSelectionScreen> {
  // ── Light-theme palette (mirrors DummyPaymentScreen)
  static const Color _accent1   = Color(0xFF1565C0);
  static const Color _accent2   = Color(0xFFE65100);
  static const Color _bgPage    = Color(0xFFF4F6FB);
  static const Color _cardBg    = Colors.white;
  static const Color _textDark  = Color(0xFF1A1A2E);
  static const Color _textMid   = Color(0xFF6B7280);
  static const Color _textLight = Color(0xFF9CA3AF);
  static const Color _border    = Color(0xFFE5E7EB);

  String  _coachSearchTerm  = '';
  String? _selectedCoachId;
  String? _selectedCoachName;
  String? _selectedCoachPrice;

  Future<void> _updateCoachAndPlanInDB() async {
    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];
      if (token == null || token.isEmpty) throw Exception('Not authenticated');

      final body = jsonEncode({
        'plan': widget.selectedPlanDistance,
        'coachId': _selectedCoachId,
      });

      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/update-plan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to update plan: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ _updateCoachAndPlanInDB error: $e');
      rethrow;
    }
  }

  String _mapPlanToSpecialization(String? plan) {
    if (plan == null) return '';
    final mapping = {
      '5km':    '5km',
      '10km':   '10km',
      '21.1km': 'half marathon',
      '42.2km': 'marathon',
      '50km':   'ultra marathon',
    };
    return mapping[plan.toLowerCase()] ?? plan.toLowerCase();
  }

  void _onContinue() {
    if (_selectedCoachId == null) return;

    if (widget.fromUpgradeFlow) {
      final price = (_selectedCoachPrice?.isNotEmpty == true)
          ? _selectedCoachPrice!
          : widget.planPrice.isNotEmpty
          ? widget.planPrice
          : 'Custom';

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DummyPaymentScreen(
            planName: '${widget.selectedPlanDistance} Coach Plan',
            price: price,
            coachName: _selectedCoachName,
            onPaymentSuccess: _updateCoachAndPlanInDB,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushNamed(
        '/athlete-register',
        arguments: {
          'selectedCoachId': _selectedCoachId,
          'selectedPlan': widget.selectedPlanDistance,
          'initialUserType': 'athlete',
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coachesAsync = ref.watch(coachesProvider);

    final filteredCoaches = coachesAsync.when(
      data: (coaches) => coaches.where((c) {
        final name  = (c['name'] as String? ?? '').toLowerCase();
        final specs = c['specializations'] is List
            ? List<String>.from(c['specializations'])
            .map((e) => e.toLowerCase())
            .toList()
            : <String>[];
        final bio  = (c['bio'] as String? ?? '').toLowerCase();
        final term = _coachSearchTerm.toLowerCase();

        final matchesSearch = term.isEmpty ||
            name.contains(term) ||
            specs.any((s) => s.contains(term)) ||
            bio.contains(term);

        final mapped   = _mapPlanToSpecialization(widget.selectedPlanDistance);
        final offersPlan = specs.any((s) => s.toLowerCase().contains(mapped));

        return matchesSearch && offersPlan;
      }).toList(),
      loading: () => <dynamic>[],
      error:   (_, __) => <dynamic>[],
    );

    return Scaffold(
      backgroundColor: _bgPage,
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.06),
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
                color: _bgPage,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: _textDark, size: 14),
            ),
          ),
        ),
        title: Text(
          'Choose Your Coach',
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
          // ── Header + search ───────────────────────────────────────────────
          Container(
            color: _cardBg,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Coaches for the ',
                        style: GoogleFonts.poppins(
                          fontSize:   22,
                          fontWeight: FontWeight.w400,
                          color:      _textDark,
                          height:     1.25,
                        ),
                      ),
                      TextSpan(
                        text: widget.selectedPlanDistance ?? '',
                        style: GoogleFonts.poppins(
                          fontSize:   22,
                          fontWeight: FontWeight.w700,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [_accent1, _accent2],
                            ).createShader(
                                const Rect.fromLTWH(0, 0, 200, 30)),
                          height: 1.25,
                        ),
                      ),
                      TextSpan(
                        text: ' Plan',
                        style: GoogleFonts.poppins(
                          fontSize:   22,
                          fontWeight: FontWeight.w400,
                          color:      _textDark,
                          height:     1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select an expert coach to guide your training',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textMid),
                ),
                const SizedBox(height: 16),

                // Search bar
                Container(
                  decoration: BoxDecoration(
                    color:        const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border:       Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                          color:     Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset:    const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    style: GoogleFonts.inter(
                        color: _textDark, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name or specialization…',
                      hintStyle: GoogleFonts.inter(
                          color: _textLight, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: _textMid, size: 20),
                      border:         InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) =>
                        setState(() => _coachSearchTerm = v),
                  ),
                ),
              ],
            ),
          ),

          // Divider between header and list
          Divider(height: 1, color: _border),

          // ── Coach list ────────────────────────────────────────────────────
          Expanded(
            child: coachesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: _accent1,
                  strokeWidth: 2.5,
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: _textLight, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load coaches.\nPlease check your connection.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: _textMid),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) {
                if (filteredCoaches.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded,
                              color: _textLight, size: 44),
                          const SizedBox(height: 14),
                          Text(
                            _coachSearchTerm.isEmpty
                                ? 'No coaches available for the ${widget.selectedPlanDistance} plan yet.'
                                : 'No coaches match your search.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: _textMid),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: filteredCoaches.length,
                  itemBuilder: (context, i) {
                    final c  = filteredCoaches[i];
                    final id = c['id'] ?? c['_id'] ?? c['email'];
                    final price =
                    getCoachPriceForPlan(c, widget.selectedPlanDistance);
                    return _CoachCard(
                      coach:               c,
                      isSelected:          _selectedCoachId == id,
                      priceLabel:          price,
                      selectedPlanDistance: widget.selectedPlanDistance,
                      onTap: () => setState(() {
                        _selectedCoachId   = id;
                        _selectedCoachName = c['name'] as String?;
                        _selectedCoachPrice = price;
                      }),
                    );
                  },
                );
              },
            ),
          ),

          // ── Bottom action area ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border(
                  top: BorderSide(color: _border)),
              boxShadow: [
                BoxShadow(
                    color:     Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset:    const Offset(0, -4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected coach pill
                if (_selectedCoachId != null &&
                    _selectedCoachName != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color:        const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _accent1.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_accent1, _accent2],
                            ),
                          ),
                          child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$_selectedCoachName'
                                '${_selectedCoachPrice != null ? '  ·  $_selectedCoachPrice' : ''}',
                            style: GoogleFonts.inter(
                              color:      _textDark,
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Continue button
                GestureDetector(
                  onTap: _selectedCoachId == null ? null : _onContinue,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      gradient: _selectedCoachId != null
                          ? const LinearGradient(
                        colors: [_accent1, _accent2],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                          : LinearGradient(colors: [
                        _border,
                        _border,
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _selectedCoachId != null
                          ? [
                        BoxShadow(
                          color:      _accent1.withOpacity(0.35),
                          blurRadius: 18,
                          offset:     const Offset(0, 7),
                        ),
                      ]
                          : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.fromUpgradeFlow
                                ? Icons.payment_rounded
                                : Icons.arrow_forward_rounded,
                            color: _selectedCoachId != null
                                ? Colors.white
                                : _textLight,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.fromUpgradeFlow
                                ? 'Continue to Payment'
                                : 'Continue with Selected Coach',
                            style: GoogleFonts.poppins(
                              fontSize:   16,
                              fontWeight: FontWeight.w700,
                              color:      _selectedCoachId != null
                                  ? Colors.white
                                  : _textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Security / helper note
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 11, color: _textLight),
                    const SizedBox(width: 5),
                    Text(
                      'You can change your coach anytime',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: _textLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Coach Card ───────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  final dynamic coach;
  final bool isSelected;
  final VoidCallback onTap;
  final String? priceLabel;
  final String? selectedPlanDistance;

  // Shared palette
  static const Color _accent1  = Color(0xFF1565C0);
  static const Color _accent2  = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B7280);
  static const Color _border   = Color(0xFFE5E7EB);

  const _CoachCard({
    required this.coach,
    required this.isSelected,
    required this.onTap,
    this.priceLabel,
    this.selectedPlanDistance,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> specs = coach['specializations'] is List
        ? List<String>.from(coach['specializations'])
        : (coach['specializations'] is String
        ? [coach['specializations'] as String]
        : []);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:  isSelected ? _accent1 : _border,
            width:  isSelected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? _accent1.withOpacity(0.14)
                  : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 16 : 8,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar
            Stack(
              children: [
                Container(
                  width:  62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? _accent1.withOpacity(0.3)
                          : _border,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: NetworkImage(
                      coach['avatarUrl'] ??
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(coach['name'] ?? 'C')}&background=1565C0&color=fff&size=64',
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right:  0,
                    child: Container(
                      width:  20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [_accent1, _accent2]),
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // ── Coach details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          coach['name'] ?? 'Coach',
                          style: GoogleFonts.poppins(
                            fontSize:   15,
                            fontWeight: FontWeight.w700,
                            color:      _textDark,
                          ),
                        ),
                      ),
                      if (priceLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accent1, _accent2],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            priceLabel!,
                            style: GoogleFonts.poppins(
                              fontSize:   11,
                              fontWeight: FontWeight.w700,
                              color:      Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if ((coach['bio'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      coach['bio'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color:    _textMid,
                        height:   1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (specs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing:    6,
                      runSpacing: 6,
                      children: specs
                          .map(
                            (s) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color:        const Color(0xFFF4F6FB),
                            borderRadius: BorderRadius.circular(20),
                            border:       Border.all(color: _border),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.inter(
                              fontSize:   11,
                              color:      _textMid,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}