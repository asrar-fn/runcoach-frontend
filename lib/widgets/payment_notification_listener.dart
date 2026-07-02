// lib/widgets/payment_notification_listener.dart
//
// Wrap your AthleteDashboard (or any ancestor widget) with this widget.
// It listens to the athlete's Firestore notification subcollection and
// shows an in-app banner when their plan is approved or rejected.
//
// Usage (in athlete_dashboard.dart or wherever your root athlete widget is):
//
//   return PaymentNotificationListener(
//     userId: me?.id ?? '',
//     child: Scaffold(...),
//   );

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentNotificationListener extends StatefulWidget {
  final String userId;
  final Widget child;

  const PaymentNotificationListener({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  State<PaymentNotificationListener> createState() =>
      _PaymentNotificationListenerState();
}

class _PaymentNotificationListenerState
    extends State<PaymentNotificationListener> {
  // Track doc IDs we've already surfaced so we don't show them twice
  final Set<String> _shown = {};

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return widget.child;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.userId)
          .collection('items')
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        // Process new unread notifications
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            if (_shown.contains(doc.id)) continue;
            _shown.add(doc.id);

            final data = doc.data() as Map<String, dynamic>;
            final type = data['type'] ?? '';

            // Only surface payment-related notifications here
            if (type == 'plan_approved' || type == 'plan_rejected') {
              // Use addPostFrameCallback so we don't call setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _showBanner(context, doc, data);
              });
            }
          }
        }

        return widget.child;
      },
    );
  }

  void _showBanner(
      BuildContext context,
      DocumentSnapshot doc,
      Map<String, dynamic> data,
      ) {
    final type = data['type'] ?? '';
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final isApproved = type == 'plan_approved';

    final Color bgColor =
    isApproved ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    final IconData icon =
    isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded;

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: bgColor,
        leading: Icon(icon, color: Colors.white, size: 28),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Mark as read in Firestore
              doc.reference.update({'read': true});
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: Text(
              'Dismiss',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTIONAL: Notification inbox icon for the AppBar
// Shows a badge with unread count. Tap to open a bottom sheet list.
//
// Usage:
//   AppBar(actions: [NotificationInboxIcon(userId: me?.id ?? '')])
// ─────────────────────────────────────────────────────────────────────────────
class NotificationInboxIcon extends StatelessWidget {
  final String userId;

  const NotificationInboxIcon({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const Icon(Icons.notifications_none, color: Color(0xFF6B7280));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () => _showInbox(context, userId),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.notifications_none,
                    color: Color(0xFF6B7280), size: 26),
              ),
              if (count > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE74C3C),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showInbox(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotificationInboxSheet(userId: userId),
    );
  }
}

class _NotificationInboxSheet extends StatelessWidget {
  final String userId;

  const _NotificationInboxSheet({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notifications',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              // Mark all as read
              TextButton(
                onPressed: () async {
                  final snap = await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(userId)
                      .collection('items')
                      .where('read', isEqualTo: false)
                      .get();
                  for (final doc in snap.docs) {
                    doc.reference.update({'read': true});
                  }
                },
                child: Text('Mark all read',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: const Color(0xFF1565C0))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(userId)
                  .collection('items')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1565C0)));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 40,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No notifications yet',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFF6B7280))),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['read'] == true;
                    final type = data['type'] ?? '';
                    final isApproved = type == 'plan_approved';
                    final isPaymentType = type.startsWith('plan_') ||
                        type == 'payment_received';

                    Color dotColor = const Color(0xFF1565C0);
                    if (type == 'plan_approved')
                      dotColor = const Color(0xFF2ECC71);
                    if (type == 'plan_rejected')
                      dotColor = const Color(0xFFE74C3C);

                    return InkWell(
                      onTap: () => doc.reference.update({'read': true}),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: dotColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isApproved
                                    ? Icons.check_circle_rounded
                                    : type == 'plan_rejected'
                                    ? Icons.cancel_rounded
                                    : Icons.receipt_long_outlined,
                                color: dotColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          data['title'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: const Color(0xFF1A1A2E),
                                          ),
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: dotColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    data['message'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}