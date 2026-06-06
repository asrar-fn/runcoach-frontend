// lib/screens/dummy_payment_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DummyPaymentScreen extends StatefulWidget {
  final String planName;
  final String price;
  final String? coachName;
  final Future<void> Function() onPaymentSuccess;

  const DummyPaymentScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.onPaymentSuccess,
    this.coachName,
  });

  @override
  State<DummyPaymentScreen> createState() => _DummyPaymentScreenState();
}

class _DummyPaymentScreenState extends State<DummyPaymentScreen>
    with TickerProviderStateMixin {
  _ScreenState _screenState = _ScreenState.payment;
  bool _processing = false;

  final _cardNumberCtrl = TextEditingController(text: '4242 4242 4242 4242');
  final _expiryCtrl     = TextEditingController(text: '12/28');
  final _cvvCtrl        = TextEditingController(text: '123');
  final _nameCtrl       = TextEditingController(text: 'John Athlete');

  late final AnimationController _successCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _pulse;

  // Light-theme palette
  static const Color _accent1    = Color(0xFF1565C0); // deep blue
  static const Color _accent2    = Color(0xFFE65100); // deep orange
  static const Color _bgPage     = Color(0xFFF4F6FB); // very light grey-blue
  static const Color _cardBg     = Colors.white;
  static const Color _textDark   = Color(0xFF1A1A2E);
  static const Color _textMid    = Color(0xFF6B7280);
  static const Color _textLight  = Color(0xFF9CA3AF);
  static const Color _border     = Color(0xFFE5E7EB);
  static const Color _inputFill  = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _checkScale = CurvedAnimation(
      parent: _successCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    );
    _ringScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
          parent: _successCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _ringOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _successCtrl,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn)),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _pulseCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePay() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1400));
    await widget.onPaymentSuccess();
    setState(() {
      _processing   = false;
      _screenState  = _ScreenState.success;
    });
    _successCtrl.forward();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _screenState == _ScreenState.payment
            ? _buildPaymentUI()
            : _buildSuccessUI(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PAYMENT UI
  // ══════════════════════════════════════════════════════════════
  Widget _buildPaymentUI() {
    return SafeArea(
      key: const ValueKey('payment'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back button ──────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:        _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                        color:     Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset:    const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: _textDark, size: 16),
              ),
            ),

            const SizedBox(height: 24),

            // ── Header ───────────────────────────────────────────
            // "Secure" — lighter weight, gradient accent on "Checkout"
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Secure ',
                    style: GoogleFonts.poppins(
                      fontSize:   26,
                      fontWeight: FontWeight.w400,
                      color:      _textDark,
                      height:     1.2,
                    ),
                  ),
                  TextSpan(
                    text: 'Checkout',
                    style: GoogleFonts.poppins(
                      fontSize:   26,
                      fontWeight: FontWeight.w700,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [_accent1, _accent2],
                        ).createShader(
                            const Rect.fromLTWH(0, 0, 200, 40)),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete your subscription',
              style: GoogleFonts.inter(
                  fontSize: 13, color: _textMid),
            ),

            const SizedBox(height: 24),

            // ── Order summary ────────────────────────────────────
            _OrderSummaryCard(
              planName:  widget.planName,
              price:     widget.price,
              coachName: widget.coachName,
            ),

            const SizedBox(height: 20),

            // ── Credit card visual ───────────────────────────────
            _CreditCardVisual(
              name:   _nameCtrl.text,
              number: _cardNumberCtrl.text,
              expiry: _expiryCtrl.text,
            ),

            const SizedBox(height: 24),

            // ── Card Details label ───────────────────────────────
            Text(
              'Card Details',
              style: GoogleFonts.poppins(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      _textDark,
              ),
            ),
            const SizedBox(height: 12),

            // ── Fields ───────────────────────────────────────────
            _LightTextField(
              controller:   _cardNumberCtrl,
              label:        'Card Number',
              hint:         '0000 0000 0000 0000',
              icon:         Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _LightTextField(
                  controller:   _expiryCtrl,
                  label:        'Expiry',
                  hint:         'MM/YY',
                  icon:         Icons.calendar_today_outlined,
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LightTextField(
                  controller:   _cvvCtrl,
                  label:        'CVV',
                  hint:         '•••',
                  icon:         Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  obscure:      true,
                ),
              ),
            ]),
            const SizedBox(height: 12),

            _LightTextField(
              controller:   _nameCtrl,
              label:        'Cardholder Name',
              hint:         'Full Name',
              icon:         Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
            ),

            const SizedBox(height: 28),

            // ── Pay button ───────────────────────────────────────
            _PayButton(
              price:      widget.price,
              processing: _processing,
              onTap:      _processing ? null : _handlePay,
            ),

            const SizedBox(height: 16),

            // ── Security note ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 11, color: _textLight),
                const SizedBox(width: 5),
                Text(
                  '256-bit SSL encrypted · Demo mode',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: _textLight),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUCCESS UI  (unchanged — dark theme looks great here)
  // ══════════════════════════════════════════════════════════════
  Widget _buildSuccessUI() {
    return Container(
      key: const ValueKey('success'),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0F14), Color(0xFF0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _successCtrl,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: _ringScale.value * 1.4,
                  child: Opacity(
                    opacity: _ringOpacity.value * 0.25,
                    child: Container(
                      width: 160, height: 160,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF27AE60)),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2ECC71).withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: _checkScale.value,
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 56),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          Text('Payment Successful!',
              style: GoogleFonts.poppins(
                fontSize:   26,
                fontWeight: FontWeight.w700,
                color:      Colors.white,
              )),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              widget.coachName != null
                  ? 'Welcome to ${widget.planName}!\nYour coach ${widget.coachName} is ready for you.'
                  : 'Welcome to ${widget.planName}!\nYour journey to peak performance starts now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color:    Colors.white.withOpacity(0.65),
                height:   1.6,
              ),
            ),
          ),

          const SizedBox(height: 36),

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFFE6783A)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color:      const Color(0xFF1976D2).withOpacity(0.4),
                  blurRadius: 16,
                  offset:     const Offset(0, 6),
                ),
              ],
            ),
            child: Text(widget.planName,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize:   14,
                    color:      Colors.white)),
          ),

          const SizedBox(height: 32),

          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) =>
                Transform.scale(scale: _pulse.value, child: child),
            child: Text(
              'Returning to dashboard…',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ScreenState { payment, success }

// ─── Order Summary Card ───────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  final String  planName;
  final String  price;
  final String? coachName;

  const _OrderSummaryCard({
    required this.planName,
    required this.price,
    this.coachName,
  });

  static const Color _accent1  = Color(0xFF1565C0);
  static const Color _accent2  = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B7280);
  static const Color _border   = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:       Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color:     Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset:    const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon with gradient bg
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_accent1, _accent2]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planName,
                        style: GoogleFonts.poppins(
                            fontSize:   15,
                            fontWeight: FontWeight.w700,
                            color:      _textDark)),
                    if (coachName != null)
                      Text('Coach: $coachName',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color:    _textMid)),
                  ],
                ),
              ),
              // Price with gradient text
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_accent1, _accent2],
                ).createShader(bounds),
                child: Text(
                  price,
                  style: GoogleFonts.poppins(
                      fontSize:   20,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white), // masked by shader
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: _border),
          const SizedBox(height: 10),

          _SummaryRow(label: 'Subtotal',   value: price),
          const SizedBox(height: 5),
          _SummaryRow(label: 'GST (18%)',  value: '₹0'),
          const SizedBox(height: 5),
          _SummaryRow(label: 'Total Due',  value: price, highlight: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  static const Color _accent2  = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid  = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize:   13,
                color:      highlight ? _textDark : _textMid,
                fontWeight: highlight
                    ? FontWeight.w600
                    : FontWeight.normal)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize:   highlight ? 15 : 13,
                fontWeight: FontWeight.w700,
                color:      highlight ? _accent2 : _textMid)),
      ],
    );
  }
}

// ─── Credit Card Visual ───────────────────────────────────────────────────────

class _CreditCardVisual extends StatelessWidget {
  final String name;
  final String number;
  final String expiry;

  const _CreditCardVisual({
    required this.name,
    required this.number,
    required this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height:  175,
      width:   double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF1976D2).withOpacity(0.45),
            blurRadius: 22,
            offset:     const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 28),
              ),
            ),
          ),
          Positioned(
            right: 25, top: 15,
            child: Container(
              width: 75, height: 75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withOpacity(0.06), width: 18),
              ),
            ),
          ),
          // Card content
          Column(
            crossAxisAlignment:  CrossAxisAlignment.start,
            mainAxisAlignment:   MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RunCoach',
                      style: GoogleFonts.poppins(
                          color:      Colors.white,
                          fontSize:   15,
                          fontWeight: FontWeight.w700)),
                  const Icon(Icons.credit_card_rounded,
                      color: Colors.white, size: 26),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    number.isEmpty ? '•••• •••• •••• ••••' : number,
                    style: GoogleFonts.sourceCodePro(
                        color:         Colors.white,
                        fontSize:      16,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CARD HOLDER',
                            style: GoogleFonts.inter(
                                fontSize:      9,
                                color:         Colors.white.withOpacity(0.6),
                                letterSpacing: 1.1)),
                        Text(
                          name.isEmpty ? 'YOUR NAME' : name.toUpperCase(),
                          style: GoogleFonts.inter(
                              color:      Colors.white,
                              fontSize:   12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 28),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXPIRES',
                            style: GoogleFonts.inter(
                                fontSize:      9,
                                color:         Colors.white.withOpacity(0.6),
                                letterSpacing: 1.1)),
                        Text(
                          expiry.isEmpty ? 'MM/YY' : expiry,
                          style: GoogleFonts.inter(
                              color:      Colors.white,
                              fontSize:   12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Light Text Field ─────────────────────────────────────────────────────────

class _LightTextField extends StatelessWidget {
  final TextEditingController controller;
  final String         label;
  final String         hint;
  final IconData       icon;
  final TextInputType  keyboardType;
  final bool           obscure;

  static const Color _textDark  = Color(0xFF1A1A2E);
  static const Color _textMid   = Color(0xFF6B7280);
  static const Color _inputFill = Color(0xFFF9FAFB);
  static const Color _border    = Color(0xFFE5E7EB);
  static const Color _accent1   = Color(0xFF1565C0);

  const _LightTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color:      _textMid,
                letterSpacing: 0.3)),
        const SizedBox(height: 6),
        TextField(
          controller:   controller,
          keyboardType: keyboardType,
          obscureText:  obscure,
          // Dark text so it's readable on white background
          style: GoogleFonts.sourceCodePro(
              color: _textDark, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: GoogleFonts.sourceCodePro(
                color: _textMid.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(icon, color: _textMid, size: 18),
            filled:      true,
            fillColor:   _inputFill,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: _accent1, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pay Button ───────────────────────────────────────────────────────────────

class _PayButton extends StatelessWidget {
  final String        price;
  final bool          processing;
  final VoidCallback? onTap;

  const _PayButton({
    required this.price,
    required this.processing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:  const Duration(milliseconds: 200),
        width:     double.infinity,
        padding:   const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: processing
              ? const LinearGradient(
              colors: [Color(0xFFBBBBBB), Color(0xFFAAAAAA)])
              : const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFFE65100)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: processing
              ? []
              : [
            BoxShadow(
              color:      const Color(0xFF1976D2).withOpacity(0.45),
              blurRadius: 18,
              offset:     const Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: processing
              ? const SizedBox(
            height: 22, width: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded,
                  color: Colors.white, size: 15),
              const SizedBox(width: 8),
              Text(
                'Pay $price',
                style: GoogleFonts.poppins(
                  fontSize:   16,
                  fontWeight: FontWeight.w700,
                  color:      Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}