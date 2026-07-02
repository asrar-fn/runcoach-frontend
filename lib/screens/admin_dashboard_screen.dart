// lib/screens/admin_dashboard_screen.dart
//
// Admin Dashboard for endurepeak
//
// FIRESTORE COLLECTIONS USED:
//   payment_receipts/{docId}
//     - userId, planName, amount, coachName?, receiptUrl,
//       status (pending_review | approved | rejected),
//       uploadedAt, reviewedAt?, reviewedBy?, rejectionReason?
//
//   notifications/{userId}/items/{docId}
//     - type, title, message, read, createdAt
//
// NODE.JS API CALLED ON APPROVAL:
//   PATCH /api/auth/update-plan   { plan: <planKey> }
//   Authorization: Bearer <adminToken>   (admin must have a token too)
//
// HOW TO REACH THIS SCREEN:
//   Add a route in your app and gate it behind an admin-role check.
//   Example (in main.dart routes or wherever you handle login):
//
//     if (user.role == 'admin') {
//       Navigator.pushReplacement(context,
//         MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
//     }

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/auth_storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PLAN NAME  →  API plan key
// Mirrors _amountForPlan logic in dummy_payment_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
String _planKey(String planName) {
  final lower = planName.toLowerCase();
  if (lower.contains('advanced')) return 'Advanced';
  if (lower.contains('50k')) return '50K';
  if (lower.contains('42.2k')) return '42.2K';
  if (lower.contains('21.1k')) return '21.1K';
  if (lower.contains('10k')) return '10K';
  if (lower.contains('5k')) return '5K';
  return 'Advanced';
}

// ─────────────────────────────────────────────────────────────────────────────
// COLOUR TOKENS  (consistent with app palette)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF4F6FB);
  static const card = Colors.white;
  static const blue = Color(0xFF1565C0);
  static const orange = Color(0xFFE65100);
  static const green = Color(0xFF2ECC71);
  static const red = Color(0xFFE74C3C);
  static const amber = Color(0xFFF59E0B);
  static const textDark = Color(0xFF1A1A2E);
  static const textMid = Color(0xFF6B7280);
  static const textLight = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const gradient = LinearGradient(
    colors: [blue, orange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() => _selectedTab = _tabs.index);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _PendingReceiptsTab(),
                _AllReceiptsTab(),
                _AthleteListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFFE65100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.blue.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Status bar spacer (adapts to every device)
          SizedBox(height: MediaQuery.of(context).padding.top),

          // ── Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    Text(
                      'endurepeak · Payment Control',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75)),
                    ),
                  ],
                ),
                const Spacer(),
                // Live pending badge
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('payment_receipts')
                      .where('status', isEqualTo: 'pending_review')
                      .snapshots(),
                  builder: (_, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.amber,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count pending',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Tab bar
          TabBar(
            controller: _tabs,
            indicator: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.55),
            labelStyle:
            GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
            tabs: const [
              Tab(text: 'Pending Receipts'),
              Tab(text: 'All Receipts'),
              Tab(text: 'Athletes'),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — PENDING RECEIPTS
// ══════════════════════════════════════════════════════════════════════════════
class _PendingReceiptsTab extends StatelessWidget {
  const _PendingReceiptsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payment_receipts')
          .where('status', isEqualTo: 'pending_review')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _C.blue));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'All caught up!',
            subtitle: 'No pending payment receipts to review.',
            iconColor: _C.green,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) =>
              _ReceiptCard(doc: docs[i], showActions: true),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ALL RECEIPTS (history with status filter)
// ══════════════════════════════════════════════════════════════════════════════
class _AllReceiptsTab extends StatefulWidget {
  const _AllReceiptsTab();

  @override
  State<_AllReceiptsTab> createState() => _AllReceiptsTabState();
}

class _AllReceiptsTabState extends State<_AllReceiptsTab> {
  String _filter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('pending_review', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    // ← Fetch ALL docs ordered by date, then filter client-side.
    // This avoids the Firestore composite index requirement that was
    // causing the query to fail silently (list flash then disappear).
    final Stream<QuerySnapshot> stream = FirebaseFirestore.instance
        .collection('payment_receipts')
        .orderBy('uploadedAt', descending: true)
        .snapshots();

    return Column(
      children: [
        // Filter chips (unchanged)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final selected = _filter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: selected ? _C.gradient : null,
                        color: selected ? null : _C.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? Colors.transparent : _C.border),
                        boxShadow: selected
                            ? [
                          BoxShadow(
                              color: _C.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3))
                        ]
                            : [],
                      ),
                      child: Text(
                        f.$2,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _C.textMid,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // List — single stream, client-side filter
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _C.blue));
              }
              if (snap.hasError) {
                return _EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Something went wrong',
                  subtitle: snap.error.toString(),
                  iconColor: _C.red,
                );
              }

              // ← Filter happens here in Dart, not Firestore
              final allDocs = snap.data?.docs ?? [];
              final docs = _filter == 'all'
                  ? allDocs
                  : allDocs
                  .where((d) =>
              (d.data() as Map<String, dynamic>)['status'] ==
                  _filter)
                  .toList();

              if (docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No receipts found',
                  subtitle: 'No payment receipts match this filter.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: docs.length,
                itemBuilder: (_, i) =>
                    _ReceiptCard(doc: docs[i], showActions: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — ATHLETES  (simple real-time list from /api/auth/users or Firestore)
// ══════════════════════════════════════════════════════════════════════════════
class _AthleteListTab extends StatefulWidget {
  const _AthleteListTab();

  @override
  State<_AthleteListTab> createState() => _AthleteListTabState();
}

class _AthleteListTabState extends State<_AthleteListTab> {
  List<Map<String, dynamic>> _athletes = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    setState(() => _loading = true);
    try {
      final auth = await AuthStorageService.getAuthData();
      final token = auth['authToken'];
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() => _athletes = data
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (e) {
      debugPrint('Admin: load athletes error: $e');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _athletes.where((a) {
      if (_search.isEmpty) return true;
      final name = (a['name'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) ||
          email.contains(_search.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search athletes by name or email…',
              hintStyle:
              GoogleFonts.inter(fontSize: 14, color: _C.textLight),
              prefixIcon:
              const Icon(Icons.search, color: _C.textLight, size: 20),
              filled: true,
              fillColor: _C.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.blue, width: 1.5),
              ),
            ),
          ),
        ),
        if (_loading)
          const Expanded(
            child: Center(
                child: CircularProgressIndicator(color: _C.blue)),
          )
        else if (filtered.isEmpty)
          Expanded(
            child: _EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No athletes found',
              subtitle: 'Try a different search term.',
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: _C.blue,
              onRefresh: _loadAthletes,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _AthleteCard(athlete: filtered[i]),
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RECEIPT CARD  — the main unit of this dashboard
// ══════════════════════════════════════════════════════════════════════════════
class _ReceiptCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final bool showActions;

  const _ReceiptCard({required this.doc, required this.showActions});

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  bool _acting = false;

  Map<String, dynamic> get _data =>
      widget.doc.data() as Map<String, dynamic>;

  String get _status => _data['status'] ?? 'pending_review';
  String get _planName => _data['planName'] ?? '—';
  String get _userId => _data['userId'] ?? '';
  String get _coachId => _data['coachId'] ?? '';
  String get _receiptUrl => _data['receiptUrl'] ?? '';

  Color get _statusColor {
    switch (_status) {
      case 'approved':
        return _C.green;
      case 'rejected':
        return _C.red;
      default:
        return _C.amber;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending Review';
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  // ── Format the Firestore timestamp nicely
  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy, h:mm a').format(ts.toDate());
    }
    return ts.toString();
  }

  // ── Approve: update Firestore + call API to update plan + notify athlete
  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final auth = await AuthStorageService.getAuthData();
      final token = auth['authToken'];

      // 1. Call backend to update the athlete's plan
      final planKey = _planKey(_planName);
      final apiRes = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/update-plan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          // pass target user so admin can update someone else's plan
          'X-Target-User-Id': _userId,
        },
        body: jsonEncode({'plan': planKey, 'userId': _userId, 'coachId': _coachId}),
      );

      if (apiRes.statusCode != 200) {
        throw Exception('API error: ${apiRes.statusCode} ${apiRes.body}');
      }

      // 2. Update Firestore receipt doc
      await widget.doc.reference.update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': auth['userId'] ?? 'admin',
      });

      // 3. Notify the athlete
      await _sendNotification(
        userId: _userId,
        type: 'plan_approved',
        title: 'Plan Activated! 🎉',
        message:
        'Your $_planName has been activated. Start training now!',
      );

      if (mounted) {
        _showSnack('✅ Approved & plan activated for $_planName', _C.green);
      }
    } catch (e) {
      debugPrint('Admin approve error: $e');
      if (mounted) {
        _showSnack('Approval failed: $e', _C.red);
      }
    }
    if (mounted) setState(() => _acting = false);
  }

  // ── Reject: ask for reason → update Firestore → notify athlete
  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null) return; // user cancelled

    setState(() => _acting = true);
    try {
      final auth = await AuthStorageService.getAuthData();

      await widget.doc.reference.update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': auth['userId'] ?? 'admin',
        'rejectionReason': reason,
      });

      await _sendNotification(
        userId: _userId,
        type: 'plan_rejected',
        title: 'Payment Not Verified',
        message: reason.isEmpty
            ? 'We could not verify your payment receipt for $_planName. Please re-upload a clearer screenshot.'
            : 'Your receipt for $_planName was not approved: $reason',
      );

      if (mounted) {
        _showSnack('Receipt rejected and athlete notified.', _C.orange);
      }
    } catch (e) {
      debugPrint('Admin reject error: $e');
      if (mounted) _showSnack('Reject failed: $e', _C.red);
    }
    if (mounted) setState(() => _acting = false);
  }

  // ── Write a notification document for the athlete
  Future<void> _sendNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type': type,
      'title': title,
      'message': message,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Reject reason dialog
  Future<String?> _showRejectDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Reject Receipt',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optionally add a reason. The athlete will see this message.',
              style:
              GoogleFonts.inter(fontSize: 13, color: _C.textMid),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Screenshot is unclear, amount mismatch…',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: _C.textLight),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: _C.textMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Reject',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Full-screen receipt image viewer
  void _viewReceipt() {
    if (_receiptUrl.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReceiptViewerScreen(
          receiptUrl: _receiptUrl,
          planName: _planName,
          userId: _userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _data['amount'] ?? 0;
    final coachName = _data['coachName'];
    final uploadedAt = _formatDate(_data['uploadedAt']);
    final reviewedAt = _data['reviewedAt'] != null
        ? _formatDate(_data['reviewedAt'])
        : null;
    final rejectionReason = _data['rejectionReason'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _status == 'pending_review'
                ? _C.amber.withOpacity(0.4)
                : _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Card header
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon,
                          color: _statusColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        _statusLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Amount chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_C.blue, _C.orange]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${_formatNum(amount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan name + user id row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_C.blue, _C.orange]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _planName,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _C.textDark,
                            ),
                          ),
                          if (coachName != null)
                            Text('Coach: $coachName',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: _C.textMid)),
                          const SizedBox(height: 2),
                          // CORRECT:
                          Text(
                            'Athlete: ${_data['athleteName']?.toString().isNotEmpty == true ? _data['athleteName'] : 'Unknown'}',
                            style: GoogleFonts.inter(fontSize: 12, color: _C.textMid),
                          ),
                          // User ID in a copyable chip
                          GestureDetector(
                            onTap: () {
                              // copy to clipboard if needed
                            },
                            child: Text(
                              'UID: $_userId',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _C.textLight)
                                  .copyWith(fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Receipt preview thumbnail
                    if (_receiptUrl.isNotEmpty)
                      GestureDetector(
                        onTap: _viewReceipt,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _receiptUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _C.bg,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: _C.textLight,
                                      size: 24),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                  Colors.black.withOpacity(0.25),
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                    Icons.zoom_in_rounded,
                                    color: Colors.white,
                                    size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: _C.border, height: 1),
                const SizedBox(height: 12),

                // Timestamps
                _InfoRow(
                    icon: Icons.upload_rounded,
                    label: 'Submitted',
                    value: uploadedAt),
                if (reviewedAt != null) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                      icon: Icons.rate_review_outlined,
                      label: 'Reviewed',
                      value: reviewedAt),
                ],
                if (rejectionReason != null &&
                    rejectionReason.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _C.red.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _C.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _C.red, size: 15),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reason: $rejectionReason',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _C.red,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action buttons (only shown in pending tab)
                if (widget.showActions && _status == 'pending_review') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _receiptUrl.isEmpty ? null : _viewReceipt,
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: Text('View Receipt',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.blue,
                            side: const BorderSide(color: _C.blue),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _acting ? null : _reject,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: Text('Reject',
                              style: GoogleFonts.poppins(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.red,
                            side: const BorderSide(color: _C.red),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(                          // ← was Expanded(flex: 2, ...)
                        child: ElevatedButton.icon(
                          onPressed: _acting ? null : _approve,
                          icon: _acting
                              ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.check_rounded, size: 16),
                          label: Text(
                              _acting ? 'Processing…' : 'Approve',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(dynamic n) {
    if (n == null) return '0';
    final i = int.tryParse(n.toString()) ?? 0;
    if (i >= 1000) {
      final s = i.toString();
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return i.toString();
  }
}

// ── Athlete Card (for the Athletes tab) ──────────────────────────────────────
class _AthleteCard extends StatelessWidget {
  final Map<String, dynamic> athlete;

  const _AthleteCard({required this.athlete});

  @override
  Widget build(BuildContext context) {
    final name = athlete['name'] ?? 'Unknown Athlete';
    final email = athlete['email'] ?? '';
    final plan = athlete['plan'] ?? 'Free';
    final id = athlete['id'] ?? athlete['_id'] ?? '';

    Color planColor;
    switch (plan.toString().toLowerCase()) {
      case 'advanced':
        planColor = _C.blue;
        break;
      case 'free':
        planColor = _C.textLight;
        break;
      default:
        planColor = _C.green; // coach plans
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: _C.blue.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.blue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _C.textDark)),
                if (email.isNotEmpty)
                  Text(email,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _C.textMid)),
                const SizedBox(height: 2),
                Text('UID: $id',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _C.textLight),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Plan badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: planColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: planColor.withOpacity(0.3)),
            ),
            child: Text(
              plan,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: planColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen receipt viewer ────────────────────────────────────────────────
class _ReceiptViewerScreen extends StatelessWidget {
  final String receiptUrl;
  final String planName;
  final String userId;

  const _ReceiptViewerScreen({
    required this.receiptUrl,
    required this.planName,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Payment Receipt',
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(planName,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600)),
                Text(userId,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.5)),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(
            receiptUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (_, __, ___) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_not_supported_outlined,
                    color: Colors.white54, size: 56),
                const SizedBox(height: 12),
                Text('Could not load image',
                    style: GoogleFonts.inter(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _C.textLight),
        const SizedBox(width: 6),
        Text('$label: ',
            style: GoogleFonts.inter(fontSize: 12, color: _C.textMid)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _C.textDark,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = _C.textLight,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: iconColor.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.textDark)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: _C.textMid, height: 1.5)),
          ],
        ),
      ),
    );
  }
}