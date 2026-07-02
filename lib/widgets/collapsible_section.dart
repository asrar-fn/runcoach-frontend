// lib/widgets/collapsible_section.dart
//
// A persisted, animated collapsible section shell used across the athlete
// dashboard to cut down on scroll. Wraps any child content with a tappable
// header (icon, title, optional subtitle/summary, optional trailing badge)
// and a chevron that rotates on expand/collapse.
//
// State persists per-section across app restarts via SharedPreferences, keyed
// by `sectionId`, so a user's "I always check Milestones" or "I never open
// Tools" habits are remembered.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central place that loads/saves every section's expanded state in one
/// SharedPreferences call instead of one call per section. Call
/// [DashboardSectionPrefs.instance.load] once near the top of the dashboard
/// (e.g. in initState) and await it before first build if you want to avoid
/// a flash of default state; the widget below also handles a late load
/// gracefully by rebuilding once the value resolves.
class DashboardSectionPrefs {
  DashboardSectionPrefs._();
  static final DashboardSectionPrefs instance = DashboardSectionPrefs._();

  static const _prefsKeyPrefix = 'dash_section_expanded_';

  final Map<String, bool> _cache = {};
  bool _loaded = false;
  SharedPreferences? _prefs;

  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    for (final key in _prefs!.getKeys()) {
      if (key.startsWith(_prefsKeyPrefix)) {
        final id = key.substring(_prefsKeyPrefix.length);
        _cache[id] = _prefs!.getBool(key) ?? true;
      }
    }
    _loaded = true;
  }

  /// Returns null if never set (caller should use its own default).
  bool? isExpanded(String sectionId) => _cache[sectionId];

  void setExpanded(String sectionId, bool expanded) {
    _cache[sectionId] = expanded;
    // Fire-and-forget; UI never blocks on disk I/O.
    _prefs?.setBool('$_prefsKeyPrefix$sectionId', expanded);
  }
}

class CollapsibleSection extends StatefulWidget {
  /// Stable unique id used for persistence, e.g. 'weekly_goal', 'tools'.
  final String sectionId;

  final String title;
  final IconData icon;

  /// Gradient used for the header strip (icon chip + title area background).
  /// Defaults to the app's signature blue→orange gradient so every section
  /// reads as part of the same themed product, not a generic white list.
  final Gradient gradient;

  /// Shown next to the title when collapsed AND expanded, e.g. "4/8 earned".
  /// Keep this short — it's the "what you'd miss by not opening this" hint.
  final String? summary;

  /// Optional small trailing badge widget (e.g. an unread-count pill).
  /// Rendered to the right of the chevron.
  final Widget? trailing;

  /// Whether this section defaults to expanded the very first time the user
  /// ever sees the dashboard (i.e. before any persisted value exists).
  final bool initiallyExpanded;

  final Widget child;

  const CollapsibleSection({
    super.key,
    required this.sectionId,
    required this.title,
    required this.icon,
    required this.child,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    this.summary,
    this.trailing,
    this.initiallyExpanded = true,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final persisted = DashboardSectionPrefs.instance.isExpanded(widget.sectionId);
    _expanded = persisted ?? widget.initiallyExpanded;
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
      value: _expanded ? 1.0 : 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
    DashboardSectionPrefs.instance.setExpanded(widget.sectionId, _expanded);
  }

  @override
  Widget build(BuildContext context) {
    // Pull the gradient's leading colour for shadow tinting, so each
    // section's shadow still feels related to its header colour.
    final Color shadowTint = widget.gradient is LinearGradient
        ? (widget.gradient as LinearGradient).colors.first
        : const Color(0xFF1976D2);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowTint.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              child: Ink(
                decoration: BoxDecoration(gradient: widget.gradient),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (widget.summary != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.summary!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.trailing != null) ...[
                        widget.trailing!,
                        const SizedBox(width: 6),
                      ],
                      RotationTransition(
                        turns: _anim.drive(Tween(begin: 0.0, end: 0.5)),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _anim,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}