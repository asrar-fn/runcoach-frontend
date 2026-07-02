// lib/screens/dummy_payment_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_storage_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AMOUNT MAPPING
// ─────────────────────────────────────────────────────────────────────────────
int _amountForPlan(String planName) {
  final lower = planName.toLowerCase();
  if (lower.contains('advanced')) return 500;
  if (lower.contains('50k')) return 25000;
  if (lower.contains('42.2k')) return 20000;
  if (lower.contains('21.1k')) return 15000;
  if (lower.contains('10k')) return 10000;
  if (lower.contains('5k')) return 5000;
  return 500;
}

String _formatAmount(int amount) {
  if (amount >= 1000) {
    final s = amount.toString();
    if (s.length > 3) {
      return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
  }
  return '₹$amount';
}

// ─────────────────────────────────────────────────────────────────────────────

class DummyPaymentScreen extends StatefulWidget {
  final String planName;
  final String price;
  final String? coachName;
  final String? coachId;

  // onPaymentSuccess is now called by the ADMIN after approval,
  // not here. We keep the parameter so existing call-sites don't break —
  // but we no longer invoke it from this screen.
  final Future<void> Function() onPaymentSuccess;

  const DummyPaymentScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.onPaymentSuccess,
    this.coachName,
    this.coachId,
  });

  @override
  State<DummyPaymentScreen> createState() => _DummyPaymentScreenState();
}

class _DummyPaymentScreenState extends State<DummyPaymentScreen>
    with TickerProviderStateMixin {
  _ScreenState _screenState = _ScreenState.qr;
  bool _uploadingReceipt = false;

  late final AnimationController _pendingCtrl;
  late final Animation<double> _pendingScale;
  late final Animation<double> _pendingOpacity;

  // Colour palette (matches existing app)
  static const Color _accent1 = Color(0xFF1565C0);
  static const Color _accent2 = Color(0xFFE65100);
  static const Color _bgPage = Color(0xFFF4F6FB);
  static const Color _cardBg = Colors.white;
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid = Color(0xFF6B7280);
  static const Color _textLight = Color(0xFF9CA3AF);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _pendingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pendingScale = CurvedAnimation(
      parent: _pendingCtrl,
      curve: Curves.elasticOut,
    );
    _pendingOpacity = CurvedAnimation(
      parent: _pendingCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _pendingCtrl.dispose();
    super.dispose();
  }

  // ── Bottom sheet → receipt upload
  void _onDoneWithPayment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptUploadSheet(onUpload: _handleReceiptUpload),
    );
  }

  // ── Upload receipt to Storage → write pending Firestore doc → show pending UI
  Future<void> _handleReceiptUpload(XFile imageFile) async {
    setState(() => _uploadingReceipt = true);
    try {
      final authData = await AuthStorageService.getAuthData();
      final userId = authData['userId'] ?? '';
      final token = authData['authToken'] ?? '';

      if (userId.isEmpty) {
        if (mounted) {
          setState(() => _uploadingReceipt = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Session error — please log out and log in again.'),
            backgroundColor: Colors.red.shade700,
          ));
        }
        return;
      }

      // ── Fetch athlete name directly from the API ──────────────────────────
      String athleteName = '';
      try {
        final meRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (meRes.statusCode == 200) {
          final meData = jsonDecode(meRes.body);
          athleteName = meData['name']?.toString() ?? '';
        }
      } catch (_) {}

      // Fallback to whatever is stored locally
      if (athleteName.isEmpty) {
        athleteName = authData['name'] ??
            authData['userName'] ??
            authData['displayName'] ??
            '';
      }
      // ─────────────────────────────────────────────────────────────────────

      // 1. Upload image to Firebase Storage
      final fileName =
          'receipts/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final bytes = await imageFile.readAsBytes();
      final snapshot = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final receiptUrl = await snapshot.ref.getDownloadURL();

      // 2. Write payment receipt document
      await FirebaseFirestore.instance.collection('payment_receipts').add({
        'userId': userId,
        'planName': widget.planName,
        'amount': _amountForPlan(widget.planName),
        'coachName': widget.coachName,
        'coachId': widget.coachId,
        'receiptUrl': receiptUrl,
        'status': 'pending_review',
        'uploadedAt': FieldValue.serverTimestamp(),
        'athleteName': athleteName, // ← now fetched from API
      });

      // rest of the method stays exactly the same...

      // 3. Write a notification so the athlete knows we received their receipt
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .add({
        'type': 'payment_received',
        'title': 'Receipt Received',
        'message':
        'We received your payment receipt for ${widget.planName}. '
            'Our team will review it shortly.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Show "Pending Approval" screen (no plan update yet)
      if (mounted) {
        setState(() {
          _uploadingReceipt = false;
          _screenState = _ScreenState.pending;
        });
        _pendingCtrl.forward();
      }
    } catch (e, stack) {
      debugPrint('❌ Receipt upload error: $e\n$stack');
      if (mounted) {
        setState(() => _uploadingReceipt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed. Please try again.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _screenState == _ScreenState.qr
                ? _buildQrUI()
                : _buildPendingUI(),
          ),
          if (_uploadingReceipt)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                    const SizedBox(height: 20),
                    Text(
                      'Uploading receipt…',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sending to admin for review',
                      style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QR PAYMENT UI  (unchanged from original)
  // ══════════════════════════════════════════════════════════════
  Widget _buildQrUI() {
    final amount = _amountForPlan(widget.planName);
    final formattedAmt = _formatAmount(amount);

    return SafeArea(
      key: const ValueKey('qr'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: _textDark, size: 16),
              ),
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: 'Complete ',
                  style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                      color: _textDark,
                      height: 1.2),
                ),
                TextSpan(
                  text: 'Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                          colors: [_accent1, _accent2])
                          .createShader(const Rect.fromLTWH(0, 0, 200, 40)),
                    height: 1.2,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan the QR below to complete your subscription',
              style: GoogleFonts.inter(fontSize: 13, color: _textMid),
            ),
            const SizedBox(height: 24),
            _OrderSummaryCard(
              planName: widget.planName,
              price: formattedAmt,
              coachName: widget.coachName,
            ),
            const SizedBox(height: 24),
            // QR card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_accent1, _accent2],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Pay $formattedAmt',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 220,
                    height: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/payment_qr.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded,
                                size: 80, color: _textLight),
                            const SizedBox(height: 8),
                            Text(
                              'Add your QR to\nassets/images/payment_qr.jpg',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _textMid),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Open any UPI app and scan',
                      style:
                      GoogleFonts.inter(fontSize: 13, color: _textMid)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _UpiChip(label: 'GPay'),
                      const SizedBox(width: 8),
                      _UpiChip(label: 'PhonePe'),
                      const SizedBox(width: 8),
                      _UpiChip(label: 'Paytm'),
                      const SizedBox(width: 8),
                      _UpiChip(label: 'BHIM'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _InstructionStep(
                      number: '1',
                      text: 'Open your UPI app and tap "Scan QR"'),
                  const SizedBox(height: 8),
                  _InstructionStep(
                      number: '2',
                      text:
                      'Enter amount $formattedAmt and complete payment'),
                  const SizedBox(height: 8),
                  _InstructionStep(
                      number: '3',
                      text: 'Take a screenshot of the success screen'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _onDoneWithPayment,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_accent1, _accent2],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _accent1.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 7))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Done with Payment',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 11, color: _textLight),
                const SizedBox(width: 5),
                Text(
                  'You will upload your payment receipt in the next step',
                  style:
                  GoogleFonts.inter(fontSize: 11, color: _textLight),
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
  // PENDING APPROVAL UI  (replaces old "Plan Activated" screen)
  // ══════════════════════════════════════════════════════════════
  Widget _buildPendingUI() {
    return Container(
      key: const ValueKey('pending'),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0F14), Color(0xFF0A1628)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated clock icon
              AnimatedBuilder(
                animation: _pendingCtrl,
                builder: (_, child) => Transform.scale(
                  scale: _pendingScale.value,
                  child: Opacity(
                    opacity: _pendingOpacity.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFFE65100)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      color: Colors.white, size: 52),
                ),
              ),

              const SizedBox(height: 36),

              Text(
                'Payment Receipt Submitted!',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              Text(
                'Your payment receipt is under review.\nWe\'ll activate your ${widget.planName} once our team verifies it — usually within a few hours.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.65),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // Plan pill
              // Find the plan pill Column in _buildPendingUI() and replace with:

              Center(
                child: Column(
                  children: [
                    Text(
                      'Selected Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFFE6783A)]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.planName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // What happens next card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.12), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next?',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _NextStep(
                      icon: Icons.search_rounded,
                      text: 'Admin reviews your payment receipt',
                    ),
                    const SizedBox(height: 10),
                    _NextStep(
                      icon: Icons.verified_rounded,
                      text: 'Plan activated automatically on approval',
                    ),
                    const SizedBox(height: 10),
                    _NextStep(
                      icon: Icons.assignment_ind_outlined,
                      text: 'To access the selected plan, please logout and login into your account after few hours.',
                    ),
                    const SizedBox(height: 10),
                    _NextStep(
                      icon: Icons.email_outlined,
                      text: 'For any payment-related questions or concerns, please contact us at admin@endurepeak.com',
                    ),

                    // _NextStep(
                    //   icon: Icons.notifications_active_outlined,
                    //   text: 'You\'ll be notified in the app',
                    // ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Back to dashboard button
              GestureDetector(
                onTap: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Text(
                    'Back to Dashboard',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── "What happens next" step row ─────────────────────────────────────────────
class _NextStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _NextStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

enum _ScreenState { qr, pending }

// ─── Receipt Upload Bottom Sheet ──────────────────────────────────────────────
class _ReceiptUploadSheet extends StatefulWidget {
  final Future<void> Function(XFile) onUpload;

  const _ReceiptUploadSheet({required this.onUpload});

  @override
  State<_ReceiptUploadSheet> createState() => _ReceiptUploadSheetState();
}

class _ReceiptUploadSheetState extends State<_ReceiptUploadSheet> {
  XFile? _pickedFile;
  bool _picking = false;
  Uint8List? _previewBytes;

  static const Color _accent1 = Color(0xFF1565C0);
  static const Color _accent2 = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _bgPage = Color(0xFFF4F6FB);

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedFile = picked;
          _previewBytes = bytes;
        });
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: _border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text(
            'Upload Payment Receipt',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Share a screenshot or photo of your payment confirmation',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: _textMid),
          ),
          const SizedBox(height: 24),
          if (_pickedFile != null) ...[
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _accent1.withOpacity(0.3)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(_previewBytes!, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _pickedFile = null;
                      _previewBytes = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Looks good? Tap Submit below.',
              style: GoogleFonts.inter(fontSize: 12, color: _textMid),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _PickOption(
                    icon: Icons.photo_library_outlined,
                    label: 'From Gallery',
                    onTap: _picking
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Take Photo',
                    onTap: _picking
                        ? null
                        : () => _pickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _pickedFile == null
                ? null
                : () {
              Navigator.of(context).pop();
              widget.onUpload(_pickedFile!);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _pickedFile != null
                    ? const LinearGradient(
                  colors: [_accent1, _accent2],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
                    : const LinearGradient(
                    colors: [Color(0xFFE5E7EB), Color(0xFFE5E7EB)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _pickedFile != null
                    ? [
                  BoxShadow(
                    color: _accent1.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
                    : [],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_rounded,
                      color: _pickedFile != null
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Submit Receipt for Review',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _pickedFile != null
                            ? Colors.white
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: GoogleFonts.inter(fontSize: 13, color: _textMid)),
          ),
        ],
      ),
    );
  }
}

class _PickOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const Color _accent1 = Color(0xFF1565C0);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _bgPage = Color(0xFFF4F6FB);

  const _PickOption(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _bgPage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(icon, color: _accent1, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order Summary Card ───────────────────────────────────────────────────────
class _OrderSummaryCard extends StatelessWidget {
  final String planName;
  final String price;
  final String? coachName;

  const _OrderSummaryCard({
    required this.planName,
    required this.price,
    this.coachName,
  });

  static const Color _accent1 = Color(0xFF1565C0);
  static const Color _accent2 = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_accent1, _accent2]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                const Icon(Icons.bolt, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planName,
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textDark)),
                    if (coachName != null)
                      Text('Coach: $coachName',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _textMid)),
                  ],
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                    colors: [_accent1, _accent2])
                    .createShader(bounds),
                child: Text(
                  price,
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: _border),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Amount', value: price),
          const SizedBox(height: 5),
          _SummaryRow(label: 'GST', value: 'Included'),
          const SizedBox(height: 5),
          _SummaryRow(label: 'Total Due', value: price, highlight: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow(
      {required this.label, required this.value, this.highlight = false});

  static const Color _accent2 = Color(0xFFE65100);
  static const Color _textDark = Color(0xFF1A1A2E);
  static const Color _textMid = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: highlight ? _textDark : _textMid,
              fontWeight:
              highlight ? FontWeight.w600 : FontWeight.normal,
            )),
        Text(value,
            style: GoogleFonts.poppins(
              fontSize: highlight ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: highlight ? _accent2 : _textMid,
            )),
      ],
    );
  }
}

// ─── Small helpers ────────────────────────────────────────────────────────────
class _UpiChip extends StatelessWidget {
  final String label;
  const _UpiChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280))),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFFE65100)]),
          ),
          child: Center(
            child: Text(number,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                  height: 1.45)),
        ),
      ],
    );
  }
}