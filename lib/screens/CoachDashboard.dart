// lib/screens/coach_dashboard.dart

import 'package:flutter/material.dart';
import '../widgets/coach_drawer.dart';
import 'athlete_details_screen.dart';
import '../models/athlete.dart';
import '../services/user_service.dart';
import '../services/auth_storage_service.dart';
import '../services/athlete_performance_service.dart';
import '../widgets/athlete_performance_tile.dart';
import 'profile_settings_screen.dart';
import 'coach_messages_page.dart';
import '../widgets/assign_workout_bottom_sheet.dart';
import '../config/api_config.dart'; // adjust path as needed'
import 'package:http/http.dart' as http;
import 'dart:convert';

// ── App-wide gradient palette ────────────────────────────────────────────────
const _kGradientStart = Color(0xFF1976D2);
const _kGradientEnd   = Color(0xFFE6783A);

class _GradientCard extends StatelessWidget {
  const _GradientCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGradientStart, _kGradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kGradientStart.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class CoachDashboard extends StatefulWidget {
  const CoachDashboard({super.key});

  @override
  State<CoachDashboard> createState() => _CoachDashboardState();
}

class _CoachDashboardState extends State<CoachDashboard> {
  List<Athlete> _athletes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _unreadMessageCount = 0;

  final List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _coachJson = {};

  String _searchTerm   = '';
  String _planFilter   = 'all';
  String _statusFilter = 'all'; // 'all' | 'peak' | 'on_track' | 'needs_focus' | 'no_data'
  String _selectedTab  = 'dashboard';

  late UserService _userService;
  AthletePerformanceService? _performanceService;
  bool _isCurrentUserCoach = true;

  static const String _apiBaseUrl = '${ApiConfig.baseUrl}';

  /// Cache: athleteId → PerformanceLevel (same data the tile's badge uses).
  /// Populated in the background after athletes load.
  final Map<String, PerformanceLevel> _levelCache = {};
  final Map<String, int> _unreadCache = {};
  bool _levelsLoading = false;

  static const List<Map<String, String>> _statusOptions = [
    {'value': 'all',         'label': 'All Status'},
    {'value': 'peak',        'label': 'Peak Performance'},
    {'value': 'on_track',    'label': 'On Track'},
    {'value': 'needs_focus', 'label': 'Needs Focus'},
    {'value': 'no_data',     'label': 'No Data'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeCoachDataAndFetchAthletes();
  }

  Future<void> _initializeCoachDataAndFetchAthletes() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final authData      = await AuthStorageService.getAuthData();
      final String? coachId   = authData['coachId'];
      final String? authToken = authData['authToken'];

      if (coachId == null || authToken == null) {
        setState(() {
          _errorMessage = 'User not logged in or session expired. Please log in.';
          _isLoading    = false;
        });
        return;
      }

      _userService = UserService(coachId, authToken);
      _performanceService = AthletePerformanceService(
        baseUrl:   _apiBaseUrl,
        authToken: authToken,
      );

      _fetchCoachProfile();
      await _fetchAthletes();
    } catch (e) {
      setState(() { _errorMessage = 'Initialization error: $e'; _isLoading = false; });
    }
  }

  Future<void> _fetchAthletes() async {
    try {
      final fetched = await _userService.fetchAthletesForCoach();
      setState(() { _athletes = fetched; _isLoading = false; });
      _fetchPerformanceLevels(); // This already sets _unreadMessageCount
      // REMOVE: _fetchUnreadMessageCount(); ← delete this line
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load athletes: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  /// Calls the same getSummary() the tile uses and caches the level per athlete.
  /// Filter and badge will always be in sync.
  Future<void> _fetchPerformanceLevels() async {
    if (_performanceService == null || _athletes.isEmpty) return;
    setState(() => _levelsLoading = true);

    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'] ?? '';

    final results = await Future.wait(
      _athletes.map((a) async {
        // Performance level
        PerformanceLevel level;
        try {
          final summary = await _performanceService!.getSummary(a.id);
          level = summary.level;
        } catch (_) {
          level = PerformanceLevel.noData;
        }

        // Unread messages from this athlete
        int unread = 0;
        try {
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/messages/unread-from/${a.id}'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            unread = data['count'] ?? 0;
          }
        } catch (_) {}

        return MapEntry(a.id, MapEntry(level, unread));
      }),
    );

    if (!mounted) return;
    setState(() {
      _levelCache.clear();
      _unreadCache.clear();
      for (final r in results) {
        _levelCache[r.key] = r.value.key;
        _unreadCache[r.key] = r.value.value;
      }
      _levelsLoading = false;

      // Total pending = sum of all per-athlete unreads
      _unreadMessageCount = _unreadCache.values.fold(0, (a, b) => a + b);
    });
  }

  Future<void> _fetchCoachProfile() async {
    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'] ?? '';
      final coachId = authData['coachId'] ?? '';

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$coachId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() => _coachJson = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Failed to fetch coach profile: $e');
    }
  }

  // Convert PerformanceLevel enum → filter key string
  String _levelKey(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.excellent:      return 'peak';
      case PerformanceLevel.good:           return 'on_track';
      case PerformanceLevel.needsAttention: return 'needs_focus';
      case PerformanceLevel.noData:         return 'no_data';
    }
  }

  List<Athlete> get _filteredAthletes {
    final lower = _searchTerm.toLowerCase();
    return _athletes.where((a) {
      final matchesSearch = a.name.toLowerCase().contains(lower) ||
          a.email.toLowerCase().contains(lower);
      final matchesPlan = _planFilter == 'all' ||
          a.plan.toLowerCase().contains(_planFilter.toLowerCase());

      bool matchesStatus = true;
      if (_statusFilter != 'all') {
        final level = _levelCache[a.id];
        if (level == null) {
          // Still loading → show athlete so the list isn't suddenly empty.
          matchesStatus = _levelsLoading;
        } else {
          matchesStatus = _levelKey(level) == _statusFilter;
        }
      }

      return matchesSearch && matchesPlan && matchesStatus;
    }).toList();
  }

  void _onTabSelected(String tabId) {
    setState(() => _selectedTab = tabId);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Switched to $tabId')));
  }

  void _openAssignSheet(Athlete athlete) {
    AssignWorkoutBottomSheet.show(
      context,
      athleteId:   athlete.id,
      athleteName: athlete.name,
      onAssigned:  () => setState(() {}),
    );
  }

  Future<void> _openMessages(Athlete athlete) async {
    final authData = await AuthStorageService.getAuthData();
    final String coachId = authData['coachId'] ?? '';
    final String token   = authData['authToken'] ?? '';
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CoachMessagesPage(
        currentUserId: coachId,
        athleteId:     athlete.id,
        athleteName:   athlete.name,
      ),
    ));

    // Clear badge locally FIRST — instant UI feedback
    if (mounted) {
      setState(() {
        _unreadCache[athlete.id] = 0;
        _unreadMessageCount = _unreadCache.values.fold(0, (a, b) => a + b);
      });
    }

    // Mark as read on server — await it fully before re-fetching
    try {
      await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/messages/read-all/${athlete.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}

    // Only NOW re-fetch so Firestore has the updated read flags
    if (mounted) _fetchPerformanceLevels();
  }

  // ── Status filter chip row ─────────────────────────────────────────────────
  Widget _buildStatusFilterRow() {
    // Build live counts from the cache.
    final counts = <String, int>{'all': _athletes.length};
    for (final a in _athletes) {
      final level = _levelCache[a.id];
      if (level != null) {
        final key = _levelKey(level);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusOptions.map((opt) {
          final isSelected = _statusFilter == opt['value'];
          final count      = counts[opt['value']];

          Color chipColor;
          switch (opt['value']) {
            case 'peak':        chipColor = const Color(0xFF1DB954); break;
            case 'on_track':    chipColor = const Color(0xFFE6783A); break;
            case 'needs_focus': chipColor = const Color(0xFFE53935); break;
            case 'no_data':     chipColor = Colors.grey;             break;
            default:            chipColor = const Color(0xFF1976D2);
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = opt['value']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? chipColor : Colors.white38,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opt['label']!,
                      style: TextStyle(
                        color:      Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize:   12,
                      ),
                    ),
                    // Count badge (after levels are fetched, for non-"all" chips)
                    if (!_levelsLoading &&
                        count != null &&
                        opt['value'] != 'all') ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color:        Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              color:      Colors.white,
                              fontSize:   10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    // Mini spinner while levels are still fetching
                    if (_levelsLoading && opt['value'] != 'all') ...[
                      const SizedBox(width: 4),
                      const SizedBox(
                        width: 8, height: 8,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _openMessagesOverview() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Messages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_athletes.isEmpty)
              const Text('No athletes found.')
            else
              ..._athletes.map((athlete) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1976D2),
                  child: Text(
                    athlete.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(athlete.name),
                subtitle: Text(athlete.email),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context); // close bottom sheet
                  _openMessages(athlete);
                },
              )),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final textTheme            = Theme.of(context).textTheme;
    final colorScheme          = Theme.of(context).colorScheme;


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedTab == 'dashboard'
              ? 'Coach Dashboard'
              : _selectedTab.replaceFirst(
              _selectedTab[0], _selectedTab[0].toUpperCase()),
          style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onBackground),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onBackground),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: colorScheme.onBackground),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Showing Notifications'))),
          ),
          IconButton(
            icon: Icon(Icons.person_outline, color: colorScheme.onBackground),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileSettingsScreen(
                  isCoach: _isCurrentUserCoach,
                  userJson: _coachJson,  // ← was const {}
                ))),
          ),
        ],
      ),
      drawer: CoachDrawer(
        onTabSelected:        _onTabSelected,
        currentTab:           _selectedTab,
        pendingMessagesCount: _unreadMessageCount,
      ),
      body: Container(
        color: Colors.white,
        child: RefreshIndicator(
          onRefresh: _fetchAthletes,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedTab == 'dashboard') ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      'Manage your athletes and track their progress',
                      style: textTheme.titleMedium?.copyWith(
                          color:
                          colorScheme.onBackground.withOpacity(0.7)),
                    ),
                  ),

                  // ── Summary cards ────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _GradientCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text('Total Athletes',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const Icon(Icons.people,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_athletes.length.toString(),
                                style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _GradientCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text('Pending Messages',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const Icon(Icons.message,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_unreadMessageCount.toString(),
                                style: textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // ── Single merged card: header + athlete list ─────────
                  _GradientCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header section
                        Padding(
                          padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Your Athletes',
                                  style: TextStyle(
                                      fontSize:   18,
                                      fontWeight: FontWeight.bold,
                                      color:      Colors.white)),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap an athlete to see details · Tap Insights to expand performance',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                              const SizedBox(height: 12),

                              // Search + plan dropdown
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    style: const TextStyle(
                                        color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText:  'Search athletes...',
                                      hintStyle: const TextStyle(
                                          color: Colors.white54),
                                      prefixIcon: const Icon(
                                          Icons.search,
                                          color: Colors.white70,
                                          size: 20),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                            color: Colors.white30),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                            color: Colors.white30),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                        BorderRadius.circular(15),
                                        borderSide: const BorderSide(
                                            color: Colors.white),
                                      ),
                                      filled:    true,
                                      fillColor: Colors.white
                                          .withOpacity(0.15),
                                      contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical:   10,
                                          horizontal: 16),
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _searchTerm = v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius:
                                    BorderRadius.circular(15),
                                    border: Border.all(
                                        color: Colors.white30),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value:         _planFilter,
                                      icon:          const Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.white,
                                          size: 20),
                                      style:         const TextStyle(
                                          color: Colors.white),
                                      dropdownColor: const Color(
                                          0xFF1565C0),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'all',
                                            child: Text('All Plans')),
                                        DropdownMenuItem(
                                            value: '5km',
                                            child: Text('5km')),
                                        DropdownMenuItem(
                                            value: '10km',
                                            child: Text('10km')),
                                        DropdownMenuItem(
                                            value: 'Half Marathon',
                                            child: Text(
                                                'Half Marathon')),
                                        DropdownMenuItem(
                                            value: 'Marathon',
                                            child: Text('Marathon')),
                                        DropdownMenuItem(
                                            value: '50km',
                                            child: Text('50km')),
                                      ],
                                      onChanged: (v) => setState(
                                              () => _planFilter = v!),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message:
                                  'Badge colour = workout completion avg\n'
                                      'Peak Performance ≥ 90%\n'
                                      'On Track 50–89%\n'
                                      'Needs Focus < 50%\n'
                                      'No Data = no workouts logged\n'
                                      'Insights: blue = assigned km, coloured = completed km',
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(Icons.info_outline,
                                        color: Colors.white
                                            .withOpacity(0.8),
                                        size: 20),
                                  ),
                                ),
                              ]),

                              const SizedBox(height: 10),

                              // Status filter chips with live counts
                              _buildStatusFilterRow(),
                            ],
                          ),
                        ),

                        const Divider(height: 0, color: Colors.white24),

                        // Athlete list
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                          )
                        else if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(_errorMessage,
                                  style: textTheme.titleMedium
                                      ?.copyWith(color: Colors.white)),
                            ),
                          )
                        else if (_filteredAthletes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  _levelsLoading && _statusFilter != 'all'
                                      ? 'Loading athlete data…'
                                      : 'No athletes found.',
                                  style: textTheme.titleMedium
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                            )
                          else
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft:  Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics:
                                const NeverScrollableScrollPhysics(),
                                itemCount: _filteredAthletes.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 0),
                                itemBuilder: (context, index) {
                                  final athlete =
                                  _filteredAthletes[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:        Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.08),
                                            blurRadius: 6,
                                            offset:
                                            const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: AthletePerformanceTile(
                                        // ValueKey forces Flutter to destroy &
                                        // recreate tile state when the athlete at
                                        // this position changes (e.g. after
                                        // filtering), preventing stale futures.
                                        key: ValueKey(athlete.id),
                                        athlete: athlete,
                                        performanceService:
                                        _performanceService ??
                                            AthletePerformanceService(
                                              baseUrl:   _apiBaseUrl,
                                              authToken: '',
                                            ),
                                        unreadCount: _unreadCache[athlete.id] ?? 0,
                                        onTap: () =>
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AthleteDetailsScreen(
                                                      athleteId:
                                                      athlete.id,
                                                      athlete: athlete,
                                                    ),
                                              ),
                                            ),
                                        onAssign:  () =>
                                            _openAssignSheet(athlete),
                                        onMessage: () =>
                                            _openMessages(athlete),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                      ],
                    ),
                  ),
                ],

                // ── Other tabs ─────────────────────────────────────────
                if (_selectedTab == 'athletes')
                  Center(
                      child: Text('Athletes Management Content Here',
                          style: textTheme.headlineSmall)),
                if (_selectedTab == 'workouts')
                  Center(
                      child: Text('Workouts Content Here',
                          style: textTheme.headlineSmall)),
                if (_selectedTab == 'messages')
                  Center(
                      child: Text('Messages Content Here',
                          style: textTheme.headlineSmall)),
                if (_selectedTab == 'settings')
                  Center(
                      child: Text('Settings Content Here',
                          style: textTheme.headlineSmall)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}