    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import 'package:intl/intl.dart';
    import './calendar_screen.dart';
    import './messages_page.dart';
    import './profile_settings_screen.dart';
    import '../services/auth_storage_service.dart';
    import 'dart:convert';
    import 'package:http/http.dart' as http;
    import './upgrade_intro_slides_screen.dart';
    import 'package:google_fonts/google_fonts.dart';
    import './race_predictor_screen.dart';
    import './hr_zone_calculator_screen.dart';
    import './athlete_pace_calculator_screen.dart';
    import 'package:url_launcher/url_launcher.dart';
    import './goals_screen.dart';
    import './workout_calendar.dart';
    import './athlete_assignments_screen.dart'; // ADD THIS
    import './membership_selection_screen.dart';
    import '../widgets/ai_plan_recommendation_card.dart';
    import '../models/strava_activites.dart';
    import './strava_page.dart';
    import '../widgets/unified_ai_analysis_card.dart';
    import '../config/api_config.dart'; // adjust path as needed
    import './landing_screen.dart';
    import '../widgets/collapsible_section.dart';
    import '../widgets/dashboard_section_content.dart';
    import 'package:cloud_firestore/cloud_firestore.dart';
    import '../widgets/app_logo.dart';

    // --- Data Models (equivalent to your API response types) ---
    class Me {
      final String? id;
      final String? name;
      final String? plan;
      final String? coachName;
      final String? coachId;
      final bool? isFirstLogin;
      final DateTime? dateOfBirth;
      final Map<String, dynamic>? metadata;

      Me({this.id, this.name, this.plan, this.coachName, this.coachId, this.isFirstLogin, this.dateOfBirth, this.metadata});

      factory Me.fromJson(Map<String, dynamic> json) {
        return Me(
          id: json['id'] ?? json['_id'],
          name: json['name'],
          plan: json['plan'],
          coachName: (json['coach'] as Map?)?['name'],
          coachId: json['coachId'] ?? (json['coach'] as Map?)?['id'],
          isFirstLogin: json['isFirstLogin'],
          dateOfBirth: json['dateOfBirth'] != null ? DateTime.tryParse(json['dateOfBirth']) : null,
          metadata: json['metadata'] != null
              ? Map<String, dynamic>.from(json['metadata'])
              : {},
        );
      }
    }

    class Assignment {
      final String? id;
      final String? workoutType;
      final String? title;
      final double? distanceKm;
      final int? durationMin;
      final String? targetPace;
      final String? instructions;
      final DateTime? scheduledDate;

      Assignment({
        this.id, this.workoutType, this.title,
        this.distanceKm, this.durationMin,
        this.targetPace, this.instructions, this.scheduledDate,
      });

      factory Assignment.fromJson(Map<String, dynamic> json) {
        // ✅ handles both "distance" (string) and "distanceKm" (number)
        double? parsedDistance;
        final rawDist = json['distance'] ?? json['distanceKm'];
        if (rawDist != null) parsedDistance = double.tryParse(rawDist.toString());

        int? parsedDuration;
        final rawDur = json['duration'] ?? json['durationMin'];
        if (rawDur != null) parsedDuration = int.tryParse(rawDur.toString());

        return Assignment(
          id: json['id'] ?? json['_id'],
          workoutType: json['workoutType'],
          title: json['title'],
          distanceKm: parsedDistance,
          durationMin: parsedDuration,
          targetPace: json['targetPace'],
          instructions: json['instructions'],
          scheduledDate: _safeDate(json['scheduledDate'] ?? json['date']),
        );
      }
    }

    class Activity {
      final String? id;
      final String? type;
      final double? distanceKm;
      final int? durationMin;
      final DateTime? date;
      final DateTime? createdAt;
      final String source;      // "manual" | "strava"
      final String? stravaId;   // non-null when synced from Strava
      final String? notes;      // Strava run name stored here on sync

      Activity({
        this.id,
        this.type,
        this.distanceKm,
        this.durationMin,
        this.date,
        this.createdAt,
        this.source = 'manual',
        this.stravaId,
        this.notes,
      });

      /// true when this activity was synced from Strava
      bool get isFromStrava => source == 'strava';

      factory Activity.fromJson(Map<String, dynamic> json) {
        return Activity(
          id: json['id'] ?? json['_id'],
          type: json['type'],
          distanceKm: (json['distanceKm'] ?? json['distance'])?.toDouble(),
          durationMin: (json['durationMin'] ?? json['duration'])?.toInt(),
          date: _safeDate(json['date'] ?? json['createdAt']),
          source: json['source'] ?? 'manual',
          stravaId: json['stravaId'],
          notes: json['notes'],
        );
      }
    }

    class DailyGoal {
      final DateTime date;
      final double distanceKm;
      final int durationMin;

      DailyGoal({required this.date, this.distanceKm = 0, this.durationMin = 0});

      factory DailyGoal.fromJson(Map<String, dynamic> json) {
        return DailyGoal(
          date: DateTime.parse(json['date'] ?? json['dateKey']),
          distanceKm: (json['distanceKm'] ?? 0).toDouble(),
          durationMin: (json['durationMin'] ?? 0).toInt(),
        );
      }

      Map<String, dynamic> toJson() => {
        "date": date.toIso8601String(),
        "distanceKm": distanceKm,
        "durationMin": durationMin,
      };
    }

    DateTime? _safeDate(dynamic v) {
      if (v == null) return null;
      if (v is String) {
        final d = DateTime.tryParse(v);
        return d?.toLocal();   // ← convert UTC → device local time
      }
      return null;
    }

    class SumResult {
      final double dist;
      final int time;

      SumResult({this.dist = 0, this.time = 0});
    }

    DateTime getStartOfWeek(DateTime date) {
      // Finds the Monday of the current week
      return date.subtract(Duration(days: date.weekday - 1)).copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    }

    // --- State Management ---
    class AppState extends ChangeNotifier {
      Me? _me;
      List<Assignment> _assignments = [];
      List<Activity> _activities = [];
      bool _isLoadingMe = true;
      bool _isLoadingAssignments = true;
      bool _isLoadingActivities = true;
      bool _isUploadingActivity = false;
      bool? _isFirstVisit = true; // Initialize to true

      Me? get me => _me;
      List<Assignment> get assignments => _assignments;
      List<Activity> get activities => _activities;
      bool get isLoadingMe => _isLoadingMe;
      bool get isLoadingAssignments => _isLoadingAssignments;
      bool get isLoadingActivities => _isLoadingActivities;
      bool get isUploadingActivity => _isUploadingActivity;
      bool? get isFirstVisit => _isFirstVisit;

      List<DailyGoal> _dailyGoals = [];
      List<DailyGoal> get dailyGoals => _dailyGoals;

      bool _stravaConnected = false;
      bool _isLoadingStrava = false;
      List<StravaActivity> _stravaActivities = [];

      bool get stravaConnected => _stravaConnected;
      bool get isLoadingStrava => _isLoadingStrava;
      List<StravaActivity> get stravaActivities => _stravaActivities;

      Map<String, dynamic>? _stravaAnalysis;
      bool _isLoadingStravaAnalysis = false;

      Map<String, dynamic>? get stravaAnalysis => _stravaAnalysis;
      bool get isLoadingStravaAnalysis => _isLoadingStravaAnalysis;
      bool _isSyncingStrava = false;
      bool get isSyncingStrava => _isSyncingStrava;

      Map<String, dynamic> _meJson = {};
      Map<String, dynamic> get meJson => _meJson;
      String _paymentStatus = ''; // 'pending_review' | 'approved' | 'rejected' | ''
      String _rejectionReason = '';
      String _pendingPlanName = '';

      String get paymentStatus => _paymentStatus;
      String get rejectionReason => _rejectionReason;
      String get pendingPlanName => _pendingPlanName;

      AppState() {
        _fetchMe();
        _fetchDailyGoals();
        checkStravaStatus();
        _listenToPaymentStatus();
      }

      Future<void> _fetchMe() async {
        _isLoadingMe = true;
        notifyListeners();

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print(jsonEncode(data));
            _meJson = Map<String, dynamic>.from(data);
            _me = Me.fromJson(data);
            _isFirstVisit = _me?.isFirstLogin ?? true;

            await _fetchActivities();
            await _fetchAssignments();
          } else {
            throw Exception("Failed to load user");
          }
        } catch (e) {
          print("Error fetching user: $e");
          _isFirstVisit = true;
        }

        _isLoadingMe = false;
        notifyListeners();
      }

      Future<void> _fetchAssignments() async {
        _isLoadingAssignments = true;
        notifyListeners();

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];
          final athleteId = authData['athleteId'] ?? _me?.id;

          if (athleteId == null) {
            _isLoadingAssignments = false;
            notifyListeners();
            return;
          }

          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/assignments/athlete/$athleteId'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            _assignments = (data as List)
                .map((e) => Assignment.fromJson(e))
                .toList();
          } else {
            print('Assignments fetch failed: ${response.statusCode}');
          }
        } catch (e) {
          print('Fetch assignments error: $e');
        }

        _isLoadingAssignments = false;
        notifyListeners();
      }

      Future<void> _fetchActivities() async {
        _isLoadingActivities = true;
        notifyListeners();

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];
          final userId = _me?.id;

          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/activities/athlete/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            _activities = (data as List)
                .map((e) => Activity.fromJson(e))
                .toList();
          }
        } catch (e) {
          print("Fetch activities error: $e");
        }

        _isLoadingActivities = false;
        notifyListeners();
      }

      void _listenToPaymentStatus() async {
        final authData = await AuthStorageService.getAuthData();
        final userId = authData['userId'] ?? '';
        if (userId.isEmpty) return;

        FirebaseFirestore.instance
            .collection('payment_receipts')
            .where('userId', isEqualTo: userId)
            .orderBy('uploadedAt', descending: true)
            .limit(1)
            .snapshots()
            .listen((snap) {
          if (snap.docs.isEmpty) {
            _paymentStatus = '';
            _rejectionReason = '';
            _pendingPlanName = '';
          } else {
            final data = snap.docs.first.data();
            final status = data['status'] ?? '';
            // Only surface pending/rejected — ignore approved (plan is already active)
            if (status == 'pending_review' || status == 'rejected') {
              _paymentStatus = status;
              _rejectionReason = data['rejectionReason'] ?? '';
              _pendingPlanName = data['planName'] ?? '';
            } else {
              _paymentStatus = '';
              _rejectionReason = '';
              _pendingPlanName = '';
            }
          }
          notifyListeners();
        });
      }

      Future<bool> updateActivity(String activityId, double distance, int duration, DateTime date) async {
        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          final response = await http.put(
            Uri.parse('${ApiConfig.baseUrl}/api/activities/$activityId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              "distanceKm": distance,
              "durationMin": duration,
              "date": date.toIso8601String(),
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final idx = _activities.indexWhere((a) => a.id == activityId);
            if (idx != -1) {
              _activities[idx] = Activity.fromJson(data);
              notifyListeners();
            }
            return true;
          }
          return false;
        } catch (e) {
          print("Update activity error: $e");
          return false;
        }
      }

      // Change signature to accept nullable
      Future<bool> deleteActivity(String? activityId) async {
        if (activityId == null || activityId.isEmpty) return false; // ✅ guard

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          final response = await http.delete(
            Uri.parse('${ApiConfig.baseUrl}/api/activities/$activityId'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
            _activities.removeWhere((a) => a.id == activityId);
            notifyListeners();
            return true;
          }
          return false;
        } catch (e) {
          print("Delete activity error: $e");
          return false;
        }
      }

      Future<void> uploadActivity(double distance, int duration, DateTime date) async {
        _isUploadingActivity = true;
        notifyListeners();

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          final response = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/activities'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              "distanceKm": distance,
              "durationMin": duration,
              "date": date.toIso8601String(),
              "createdAt": date.toIso8601String(),
              "type": "run"
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            final newActivity = Activity.fromJson(data);

            _activities.insert(0, newActivity);
            notifyListeners();
          } else {
            throw Exception("Failed to upload activity");
          }
        } catch (e) {
          print("Upload error: $e");
        }

        _isUploadingActivity = false;
        notifyListeners();
      }

      Future<void> _fetchDailyGoals() async {
        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/goals/me'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            _dailyGoals = (data as List)
                .map((e) => DailyGoal.fromJson(e))
                .toList();
            notifyListeners();
          }
        } catch (e) {
          print("Fetch goals error: $e");
        }
      }

      Future<void> saveWeeklyGoal(double distance, int duration, DateTime weekDate) async {
        final monday = getStartOfWeek(weekDate);
        final goal = DailyGoal(date: monday, distanceKm: distance, durationMin: duration);

        // Remove existing goal for that week
        _dailyGoals.removeWhere((g) => getStartOfWeek(g.date) == monday);
        _dailyGoals.add(goal);
        notifyListeners();

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/goals'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(goal.toJson()),
          );
        } catch (e) {
          print("Error saving goal: $e");
        }
      }

      Future<void> refreshAll() async {
        await _fetchMe();       // already internally calls _fetchActivities + _fetchAssignments
        await _fetchDailyGoals();
      }

      Future<void> checkStravaStatus() async {
        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/strava/status'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            _stravaConnected = data['connected'] == true;
            notifyListeners();

            if (_stravaConnected) {
              // Fetch Strava activities for the AI analysis card display
              await fetchStravaActivities();
              // Sync them into the DB so all other features see them too
              await syncStravaToDb();
            }
          }
        } catch (e) {
          print('Strava status check error: $e');
        }
      }

      Future<void> syncStravaToDb() async {
        _isSyncingStrava = true;
        notifyListeners();

        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          final response = await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/strava/sync-to-db'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print('Strava sync: ${data['synced']} new activities added to DB');
            // Refresh activities so the dashboard reflects the newly synced runs
            await _fetchActivities();
          } else {
            print('Strava sync-to-db failed: ${response.statusCode}');
          }
        } catch (e) {
          print('Strava syncStravaToDb error: $e');
        }

        _isSyncingStrava = false;
        notifyListeners();
      }

      Future<void> fetchStravaActivities() async {
        _isLoadingStrava = true;
        notifyListeners();
        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/strava/activities'),
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            _stravaActivities = (data['activities'] as List)
                .map((e) => StravaActivity.fromJson(e))
                .toList();
          }
        } catch (e) {
          print('Fetch Strava activities error: $e');
        }
        _isLoadingStrava = false;
        notifyListeners();

        // ← NEW: sync to DB after fetching so the activity list stays up to date
        await syncStravaToDb();
      }

      Future<void> fetchStravaAnalysis() async {
        _isLoadingStravaAnalysis = true;
        notifyListeners();
        try {
          final authData = await AuthStorageService.getAuthData();
          final token = authData['authToken'];

          // Use Strava endpoint if connected + has runs, otherwise use DB
          final endpoint = (_stravaConnected && _stravaActivities.isNotEmpty)
              ? '${ApiConfig.baseUrl}/api/ai/strava-analysis'
              : '${ApiConfig.baseUrl}/api/ai/recommend-plan';

          final response = await http.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200) {
            _stravaAnalysis = jsonDecode(response.body);
          }
        } catch (e) {
          print('AI analysis error: $e');
        }
        _isLoadingStravaAnalysis = false;
        notifyListeners();
      }
    }

    // --- Utility Functions ---
    String fmtKm(double n) => "${n.toStringAsFixed(2)} km";

    int pct(double actual, double assigned) {
      if (assigned <= 0) {
        return 0;
      }

      return ((actual / assigned) * 100).round();
    }

    // --- Custom Widgets for the Dashboard ---

    // Custom Colors based on the first screenshot - Adjusted for less clutter
    class AppColors {
      static const Color primaryBlue = Color(0xFF2575FC);
      static const Color primaryPurple = Color(0xFF6A11CB);
      static const Color backgroundLightGrey = Color(0xFFF0F2F5); // Slightly darker, less harsh
      static const Color textDark = Color(0xFF2C3E50); // Deeper dark text
      static const Color textMedium = Color(0xFF7F8C8D); // More muted medium text
      static const Color textLight = Color(0xFFBDC3C7);
      static const Color cardBackground = Color(0xFFFFFFFF);
      static const Color dividerColor = Color(0xFFE0E0E0); // Slightly softer divider
      static const Color accentOrange = Color(0xFFF7941D);
      static const Color accentGreen = Color(0xFF2ECC71); // Brighter green
      static const Color accentRed = Color(0xFFE74C3C); // Brighter red
      static const Color glassOverlay = Color(0x33FFFFFF); // For subtle glassmorphism
    }

    // Gradients
    const LinearGradient welcomeBannerGradient = LinearGradient(
      colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    const LinearGradient sidebarGradient = LinearGradient(
      colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );


    // Gradient for interactive elements
    const LinearGradient glossyGradient = LinearGradient(
      colors: [Color(0xFFE6783A), Color(0xFF1976D2)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    // Gradient for interactive elements (darker version)
    const LinearGradient glossyGradientDark = LinearGradient(
      colors: [AppColors.primaryBlue, AppColors.primaryPurple], // Light blue to light purple for glossy effect
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );


    class AthleteDashboard extends StatefulWidget {
      const AthleteDashboard({super.key});

      @override
      State<AthleteDashboard> createState() => _AthleteDashboardState();
    }

    class _AthleteDashboardState extends State<AthleteDashboard> {
      bool _showUploadForm = false;
      TextEditingController _distanceInputController = TextEditingController();
      TextEditingController _timeInputController = TextEditingController();
      DateTime? _selectedDate;
      bool _runTour = false;
      bool _prefsReady = false;

      @override
      void initState() {
        super.initState();
        _selectedDate = DateTime.now();
        DashboardSectionPrefs.instance.load().then((_) {
          if (mounted) setState(() => _prefsReady = true);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final appState = Provider.of<AppState>(context, listen: false);
          if (appState.isFirstVisit == true) {
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted) {
                setState(() {
                  _runTour = true;
                });
              }
            });
          }
        });
      }


      @override
      void dispose() {
        _distanceInputController.dispose();
        _timeInputController.dispose();
        super.dispose();
      }

      final DateTime _today = DateTime.now();
      DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
      DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

      SumResult _sumAssignedInRange(DateTime start, DateTime end, List<Assignment> assignments) {
        double dist = 0;
        int time = 0;
        for (var a in assignments) {
          if (a.scheduledDate != null &&
              !a.scheduledDate!.isBefore(start) &&
              !a.scheduledDate!.isAfter(end)) {
            dist += a.distanceKm ?? 0;
            time += a.durationMin ?? 0;
          }
        }
        return SumResult(dist: dist, time: time);
      }

      SumResult _sumActivityInRange(DateTime start, DateTime end, List<Activity> activities) {
        double dist = 0;
        int time = 0;
        for (var act in activities) {
          if (act.date != null &&
              !act.date!.isBefore(start) &&
              !act.date!.isAfter(end)) {
            dist += act.distanceKm ?? 0;
            time += act.durationMin ?? 0;
          }
        }
        return SumResult(dist: dist, time: time);
      }

      void _navigateToUpgradeFlow(BuildContext context) async {
        final appState = Provider.of<AppState>(context, listen: false);

        // Block if already under review
        if (appState.paymentStatus == 'pending_review') {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text('Review Pending',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              content: Text(
                'Your payment receipt for ${appState.pendingPlanName} is currently under review. '
                    'Please wait for our team to verify it before submitting another payment.',
                style: GoogleFonts.inter(fontSize: 14, height: 1.5),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('OK',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
          return; // ← stops navigation
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MembershipSelectionScreen(),
          ),
        );

        if (context.mounted) {
          await Provider.of<AppState>(context, listen: false).refreshAll();
        }
      }

      String _calculatePace(String distStr, String timeStr) {
        double? dist = double.tryParse(distStr);
        double? time = double.tryParse(timeStr);

        if (dist == null || time == null || dist <= 0 || time <= 0) {
          return "--:--";
        }

        // Pace in total seconds per km
        double totalSecondsPerKm = (time * 60) / dist;
        int minutes = totalSecondsPerKm ~/ 60;
        int seconds = (totalSecondsPerKm % 60).round();

        // Handle case where seconds might round to 60
        if (seconds == 60) {
          minutes++;
          seconds = 0;
        }

        return "$minutes:${seconds.toString().padLeft(2, '0')} min/km";
      }

      String _getActivityTitle(Activity a) {
        // If synced from Strava and has a name, use that
        if (a.isFromStrava && (a.notes?.isNotEmpty ?? false)) {
          return a.notes!;
        }

        if (a.date == null) return "Activity";
        if (a.type?.toLowerCase() != "run") return a.type ?? "Activity";

        final int hour = a.date!.hour;
        if (hour >= 4 && hour < 10) return "Morning Run";
        if (hour >= 10 && hour < 15) return "Afternoon Run";
        if (hour >= 15 && hour < 19) return "Evening Run";
        return "Night Run";
      }

      void _connectStrava(BuildContext context) async {
        final appState = Provider.of<AppState>(context, listen: false);
        // Always navigate to the Strava page — it handles both states
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StravaPage()),
        );
        // Re-check status when returning (user may have connected/disconnected)
        await appState.checkStravaStatus();
      }

      void _showStravaConnectedSheet(BuildContext context, AppState appState) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Strava orange pill
                Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC4C02).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFFFC4C02), size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Strava Connected!',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Strava account is linked. Activities are syncing automatically.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textMedium),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await appState.fetchStravaActivities();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFFC4C02)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Sync Now',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFFFC4C02),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final authData =
                          await AuthStorageService.getAuthData();
                          final token = authData['authToken'];
                          await http.delete(
                            Uri.parse(
                                '${ApiConfig.baseUrl}/api/strava/disconnect'),
                            headers: {'Authorization': 'Bearer $token'},
                          );
                          await appState.checkStravaStatus();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Disconnect',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      }

      void _openUploadDialog() {
        final appState = Provider.of<AppState>(context, listen: false);
        bool distanceError = false;
        bool durationError = false;
        TimeOfDay? _selectedTime;
        _selectedTime = TimeOfDay.now();

        bool isPastDate(DateTime date) {
          final now = DateTime.now();

          return date.year != now.year ||
              date.month != now.month ||
              date.day != now.day;
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Manual Activity",
                                style: GoogleFonts.poppins(
                                  fontSize: 20, fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: AppColors.textMedium),
                                onPressed: () {
                                  _distanceInputController.clear();
                                  _timeInputController.clear();
                                  Navigator.of(dialogContext).pop();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedDate != null
                                ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!)
                                : "",
                            style: GoogleFonts.poppins(color: AppColors.textMedium, fontSize: 13),
                          ),
                          const Divider(height: 32),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Distance (km)",
                                      style: GoogleFonts.poppins(fontSize: 14,
                                          fontWeight: FontWeight.w500, color: AppColors.textDark),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _distanceInputController,
                                      onChanged: (val) => setDialogState(() {
                                        if (distanceError) distanceError = false;
                                      }),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.poppins(fontSize: 15),
                                      decoration: InputDecoration(
                                        hintText: "0.0",
                                        hintStyle: GoogleFonts.poppins(
                                            color: Colors.grey.shade400, fontSize: 14),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        errorText: distanceError ? "Distance is required" : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Duration (min)",
                                      style: GoogleFonts.poppins(fontSize: 14,
                                          fontWeight: FontWeight.w500, color: AppColors.textDark),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _timeInputController,
                                      onChanged: (val) => setDialogState(() {
                                        if (durationError) durationError = false;
                                      }),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.poppins(fontSize: 15),
                                      decoration: InputDecoration(
                                        hintText: "0",
                                        hintStyle: GoogleFonts.poppins(
                                            color: Colors.grey.shade400, fontSize: 14),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        errorText: durationError ? "Duration is required" : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Calculated Pace:",
                                  style: GoogleFonts.poppins(color: AppColors.textMedium,
                                      fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  _calculatePace(
                                    _distanceInputController.text,
                                    _timeInputController.text,
                                  ),
                                  style: GoogleFonts.poppins(color: AppColors.primaryBlue,
                                      fontSize: 18, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_selectedDate != null &&
                              isPastDate(_selectedDate!)) ...[
                            const SizedBox(height: 20),

                            Text(
                              "Time of Activity",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark,
                              ),
                            ),

                            const SizedBox(height: 8),

                            InkWell(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: _selectedTime ?? TimeOfDay.now(),
                                );

                                if (picked != null) {
                                  setDialogState(() {
                                    _selectedTime = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedTime?.format(context) ?? "Select Time",
                                    ),
                                    const Icon(Icons.access_time),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text("Date of Activity",
                            style: GoogleFonts.poppins(fontSize: 14,
                                fontWeight: FontWeight.w500, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: dialogContext,
                                initialDate: _selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setDialogState(() => _selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat.yMMMd().format(_selectedDate ?? DateTime.now()),
                                    style: GoogleFonts.poppins(color: AppColors.textDark),
                                  ),
                                  const Icon(Icons.calendar_month,
                                      color: AppColors.primaryBlue, size: 20),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: GradientButton(
                                  onPressed: () {
                                    final distanceText = _distanceInputController.text.trim();
                                    final durationText = _timeInputController.text.trim();

                                    final double distance = double.tryParse(distanceText) ?? 0;
                                    final int duration = int.tryParse(durationText) ?? 0;

                                    final bool hasDistanceError = distanceText.isEmpty || distance <= 0;
                                    final bool hasDurationError = durationText.isEmpty || duration <= 0;

                                    if (hasDistanceError || hasDurationError) {
                                      setDialogState(() {
                                        distanceError = hasDistanceError;
                                        durationError = hasDurationError;
                                      });
                                      return;
                                    }

                                    DateTime activityDate;

                                    if (_selectedDate != null &&
                                        isPastDate(_selectedDate!)) {

                                      activityDate = DateTime(
                                        _selectedDate!.year,
                                        _selectedDate!.month,
                                        _selectedDate!.day,
                                        _selectedTime?.hour ?? 0,
                                        _selectedTime?.minute ?? 0,
                                      );
                                    } else {
                                      activityDate = DateTime.now();
                                    }

                                    appState.uploadActivity(
                                      distance,
                                      duration,
                                      activityDate,
                                    ).then((_) {
                                      _distanceInputController.clear();
                                      _timeInputController.clear();
                                      Navigator.of(dialogContext).pop();
                                    });
                                  },
                                  gradient: glossyGradientDark,
                                  borderRadius: 12,
                                  child: Text("Save Activity",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      }

      Future<void> _logout(BuildContext context) async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
            content: const Text('Are you sure you want to logout?',
                style: TextStyle(color: AppColors.textMedium)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMedium)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

        if (shouldLogout != true) return;
        await AuthStorageService.clearAuthData();
        if (!context.mounted) return;

        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingScreen()),
              (route) => false,
        );
      }

      @override
      Widget build(BuildContext context) {
        final appState = Provider.of<AppState>(context);
        final me = appState.me;
        final assignments = appState.assignments;
        final activities = appState.activities;
        final isLoadingMe = appState.isLoadingMe;
        final isLoadingActivities = appState.isLoadingActivities;
        final isUploading = appState.isUploadingActivity;
        final isFirstVisit = appState.isFirstVisit;
        final isFreeUser = me?.plan == null || me?.plan == "Free";
        final latestActivity = activities.isNotEmpty ? activities.first : null;
        final bool isAdvancedUser = me?.plan == 'Advanced';
        final bool isCoachUser = ['5K', '10K', '21.1K', '42.2K', '50K'].contains(me?.plan);


        final todayAssigned = _sumAssignedInRange(_startOfDay(_today), _endOfDay(_today), assignments);
        final todayActual = _sumActivityInRange(_startOfDay(_today), _endOfDay(_today), activities);
        final todaysAssignedKm = todayAssigned.dist;
        final todaysActualKm = todayActual.dist;
        final todayProgressPct = pct(todaysActualKm, todaysAssignedKm);

        final todaysAssignment = assignments.firstWhere(
              (a) => a.scheduledDate != null &&
              a.scheduledDate!.year == _today.year &&
              a.scheduledDate!.month == _today.month &&
              a.scheduledDate!.day == _today.day,
          orElse: () => Assignment(),
        );

        final activitiesForSelected = _selectedDate != null
            ? activities.where((act) =>
        act.date != null &&
            act.date!.year == _selectedDate!.year &&
            act.date!.month == _selectedDate!.month &&
            act.date!.day == _selectedDate!.day).toList()
            : [];

        final assignmentsForSelected = _selectedDate != null
            ? assignments.where((a) =>
        a.scheduledDate != null &&
            a.scheduledDate!.year == _selectedDate!.year &&
            a.scheduledDate!.month == _selectedDate!.month &&
            a.scheduledDate!.day == _selectedDate!.day).toList()
            : [];

        if (isLoadingMe || isFirstVisit == null) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundLightGrey,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryBlue),
            ),
          );
        }

        // Tour Logic
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   if (_runTour) {
        //     showDialog(
        //       context: context,
        //       builder: (BuildContext dialogContext) {
        //         return AlertDialog(
        //           title: const Text("Welcome to your Dashboard! 🎉"),
        //           content: const Text("Let's take a quick tour of your new athlete dashboard."),
        //           actions: <Widget>[
        //             TextButton(
        //               onPressed: () {
        //                 Navigator.of(dialogContext).pop();
        //                 setState(() {
        //                   _runTour = false;
        //                 });
        //                 appState.markUserSeen();
        //               },
        //               child: const Text("Start Tour (or Dismiss)"),
        //             ),
        //           ],
        //         );
        //       },
        //     );
        //     setState(() { _runTour = false; });
        //   }
        // });

        Widget _buildInputField({
          required String label,
          required TextEditingController controller,
          required String hint,
          required Function(String) onChanged,
        }) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          );
        }

    // Helper Widget for Input Fields to keep code clea

        return LayoutBuilder(
          builder: (context, constraints) {
            final isLargeScreen = constraints.maxWidth > 900;
            return Scaffold(
              backgroundColor: AppColors.backgroundLightGrey,
              appBar: AppBar(
                backgroundColor: AppColors.cardBackground,
                elevation: 0,
                leading: isLargeScreen
                    ? null
                    : Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: AppColors.textMedium),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
                title: isLargeScreen
                    ? null
                    : const Text(
                  "Athlete Dashboard",
                  style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
                ),
                centerTitle: false,
                actions: [
                  if (appState.isSyncingStrava)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFC4C02),
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppColors.textMedium),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications!")));
                    },
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.only(right: 16.0),
                  //   child: CircleAvatar(
                  //     backgroundColor: AppColors.dividerColor,
                  //     child: const Icon(Icons.person, color: AppColors.textMedium),
                  //   ),
                  // ),
                ],
              ),
              drawer: isLargeScreen ? null : _buildDrawer(context),
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLargeScreen) _buildSidebar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                      child: _buildDashboardBody(
                        context, me, assignments, activities, isLoadingActivities,
                        isFreeUser, isAdvancedUser, isCoachUser, latestActivity,
                        todaysAssignment, todaysAssignedKm, todaysActualKm, todayProgressPct,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }

      // --- Sidebar for large screens ---
      Widget _buildSidebar(BuildContext context) {
        final appState = Provider.of<AppState>(context, listen: false);
        final String currentUserId = appState.me?.id ?? '';
        final String coachId = appState.me?.coachId ?? '';

        return Container(
          width: 280,
          color: AppColors.cardBackground,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(bottom: BorderSide(color: AppColors.dividerColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: const AppLogo(
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 8),
                  children: <Widget>[
                    _DrawerItem(
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      isSelected: true,
                      onTap: () {},
                    ),
                    _DrawerItem(
                      icon: Icons.calendar_today,
                      title: 'Calendar',
                      onTap: () {
                        // 1. Get current state
                        final appState = Provider.of<AppState>(context, listen: false);

                        // 2. Navigate and pass all data
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(title: const Text("Training Calendar")),
                              body: WorkoutCalendar(
                                plan: appState.me?.plan,            // "free" or "advanced"
                                assignments: appState.assignments,  // Coach assignments
                                activities: appState.activities,    // Logged runs
                                goals: appState.dailyGoals,        // Athlete set goals
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (['5K', '10K', '21.1K', '42.2K', '50K'].contains(appState.me?.plan))
                      _DrawerItem(
                        icon: Icons.assignment_outlined,
                        title: 'Scheduled Workouts',
                        onTap: () {
                          final athleteId = appState.me?.id ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AthleteAssignmentsScreen(
                                athleteId: athleteId,
                                activities: appState.activities   // ADD THIS
                                    .map((a) => {
                                  'distanceKm': a.distanceKm,
                                  'durationMin': a.durationMin,
                                  'date': a.date?.toIso8601String(),
                                })
                                    .toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    _DrawerItem(
                      icon: Icons.flag_rounded,
                      title: 'My Goals',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SetGoalsCalendarScreen()),
                        );
                      },
                    ),
                    if (['5K', '10K', '21.1K', '42.2K', '50K'].contains(appState.me?.plan))
                      _DrawerItem(
                        icon: Icons.message,
                        title: 'Messages',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagesPage(
                                currentUserId: currentUserId,
                                coachId: coachId,
                              ),
                            ),
                          );
                        },
                      ),
                    _DrawerItem(
                      icon: Icons.person,
                      title: 'Settings',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              final appState = Provider.of<AppState>(context, listen: false);
                              // Build the JSON map from the Me object already in state
                              return ProfileSettingsScreen(
                                isCoach: false,
                                userJson: appState.meJson,
                              );
                            },
                          ),
                        );
                        if (!mounted) return;
                        // Refetch so the dashboard reflects whatever was just saved
                        await Provider.of<AppState>(context, listen: false).refreshAll();
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      color: AppColors.accentRed,
                      onTap: () => _logout(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      Widget _buildWelcomeBanner(BuildContext context, Me? me, bool hasAdvancedPlan) {
        final appState = Provider.of<AppState>(context);
        final paymentStatus = appState.paymentStatus;
        final rejectionReason = appState.rejectionReason;
        final pendingPlanName = appState.pendingPlanName;

        // ── PENDING state ──────────────────────────────────────────────────────────
        if (paymentStatus == 'pending_review') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFE65100)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
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
                      child: const Icon(Icons.hourglass_top_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment Under Review',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome, ${me?.name ?? "Athlete"}! 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your payment receipt for $pendingPlanName is being reviewed by our team.\n We\'ll activate your plan shortly.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'if you have queries reach us out admin@endurepeak.com',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // ── REJECTED state ─────────────────────────────────────────────────────────
        if (paymentStatus == 'rejected') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE74C3C).withOpacity(0.35),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
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
                      child: const Icon(Icons.cancel_outlined,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment Not Verified',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Hello, ${me?.name ?? "Athlete"} 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your payment receipt for $pendingPlanName could not be verified.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                ),
                if (rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason:',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          rejectionReason,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Re-upload CTA
                GestureDetector(
                  onTap: () => _navigateToUpgradeFlow(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_rounded,
                            color: Color(0xFFE74C3C), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Re-upload Receipt',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE74C3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ── NORMAL state (existing code) ───────────────────────────────────────────
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            gradient: welcomeBannerGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, ${me?.name ?? "Athlete"}! ⚡",
                style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              if (hasAdvancedPlan) ...[
                Text(
                  "Training Plan: ${me?.plan ?? "No Plan"}",
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                if (['5K', '10K', '21.1K', '42.2K', '50K'].contains(me?.plan)) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Coach: ${me?.coachName ?? "Unassigned"}",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ] else ...[
                Text(
                  "You're on the Basic Plan.",
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 15),
                GradientButton(
                  onPressed: () => _navigateToUpgradeFlow(context),
                  gradient: const LinearGradient(
                    colors: [Colors.white, Colors.white70],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  borderRadius: 25.0,
                  child: Text(
                    "Upgrade your plan",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      Widget _buildBasicFeaturesSection(BuildContext context, Activity? latestActivity, Me? me) {

        final appState = Provider.of<AppState>(context, listen: false);
        final stravaConnected = appState.stravaConnected;

        final List<Map<String, dynamic>> features = [
          {'icon': Icons.link,
            'title': "Connect Strava",
            'subtitle': stravaConnected ? "✓ Connected · View runs" : "Sync your runs"},
          // {'icon': Icons.watch, 'title': "Smartwatch Sync", 'subtitle': "Connect your device"},
          {'icon': Icons.upload_file, 'title': "Manual Activity", 'subtitle': "Log a new activity"},
          {'icon': Icons.speed, 'title': "Activity History", 'subtitle': "Track your running progress"},
          {'icon': Icons.flag, 'title': "Race Predictor", 'subtitle': "Estimate race times"},
          {'icon': Icons.monitor_heart, 'title': "HR Zone", 'subtitle': "Optimize heart rate"},
          // {'icon': Icons.cloud, 'title': "Weather Insights", 'subtitle': "Run-friendly forecasts"},
        ];

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: features.map((feature) {
            final isWide = MediaQuery.of(context).size.width > 600;
            final screenWidth = MediaQuery.of(context).size.width;
            final itemWidth = isWide
                ? (screenWidth - 380) / 3
                : (screenWidth - 80) / 2;

            VoidCallback onTap;
            if (feature['title'] == "Smartwatch Sync") {
              onTap = () => _showSmartwatchConnectDialog(context);
            } else if (feature['title'] == "Manual Activty") {
              onTap = () {
                _selectedDate = DateTime.now();
                _distanceInputController.clear();
                _timeInputController.clear();
                _openUploadDialog();
              };
            } else if (feature['title'] == "Race Predictor") {
              onTap = () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => AthleteScreenRacePredictor(
                  distance: latestActivity?.distanceKm ?? 0,
                  duration: latestActivity?.durationMin ?? 0,
                ),
              ));
            } else if (feature['title'] == "HR Zone") {
              onTap = () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => HRZoneCalculatorScreen(dateOfBirth: me?.dateOfBirth),
              ));
            } else if (feature['title'] == "Activity History") {
              onTap = () {
                final athleteId = me?.id;
                if (athleteId != null) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => AthletePaceCalculatorScreen(athleteId: athleteId),
                  ));
                }
              };
            } else if (feature['title'] == "Connect Strava") {
              onTap = () => _connectStrava(context);
            } else {
              onTap = () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${feature['title']} (Coming Soon)")));
            }

            return SizedBox(
              width: itemWidth,
              height: 130,
              child: _buildGlossyFeatureTile(
                context,
                feature['icon'] as IconData,
                feature['title'] as String,
                feature['subtitle'] as String,
                onTap,
              ),
            );
          }).toList(),
        );
      }


      Widget _buildGlossyFeatureTile(
          BuildContext context,
          IconData icon,
          String title,
          String subtitle,
          VoidCallback onTap,
          ) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: glossyGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 32, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }


      void _showSmartwatchConnectDialog(BuildContext context) {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("Connect your Smartwatch"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.watch),
                    title: const Text("Apple Health"),
                    onTap: () { Navigator.of(dialogContext).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting to Apple Health... (Coming Soon)"))); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.watch),
                    title: const Text("Garmin Connect"),
                    onTap: () { Navigator.of(dialogContext).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting to Garmin... (Coming Soon)"))); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.watch),
                    title: const Text("Coros App"),
                    onTap: () { Navigator.of(dialogContext).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting to Coros... (Coming Soon)"))); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.watch),
                    title: const Text("Samsung Health"),
                    onTap: () { Navigator.of(dialogContext).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connecting to Samsung Health... (Coming Soon)"))); },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      }

      Widget _buildUpgradePlanSection(BuildContext context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            gradient: sidebarGradient, // Reusing sidebar gradient for premium feel
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        );
      }

      // --- Drawer for small screens ---
      Widget _buildDrawer(BuildContext context) {
        final appState = Provider.of<AppState>(context, listen: false);
        final String currentUserId = appState.me?.id ?? '';
        final String coachId = appState.me?.coachId ?? '';

        return Drawer(
          width: 280,
          backgroundColor: AppColors.cardBackground,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              // In _buildDrawer logo container:
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  border: Border(bottom: BorderSide(color: AppColors.dividerColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: const AppLogo(
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              _DrawerItem(
                icon: Icons.dashboard,
                title: 'Dashboard',
                isSelected: true,
                onTap: () {
                  Navigator.pop(context); // Close drawer
                },
              ),
              _DrawerItem(
                icon: Icons.calendar_today,
                title: 'Calendar',
                onTap: () {
                  // 1. Get current state
                  final appState = Provider.of<AppState>(context, listen: false);

                  // 2. Navigate and pass all data
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text("Training Calendar")),
                        body: WorkoutCalendar(
                          plan: appState.me?.plan,            // "free" or "advanced"
                          assignments: appState.assignments,  // Coach assignments
                          activities: appState.activities,    // Logged runs
                          goals: appState.dailyGoals,        // Athlete set goals
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (['5K', '10K', '21.1K', '42.2K', '50K'].contains(appState.me?.plan))
                _DrawerItem(
                  icon: Icons.assignment_outlined,
                  title: 'Scheduled Workouts',
                  onTap: () {
                    final athleteId = appState.me?.id ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AthleteAssignmentsScreen(athleteId: athleteId),
                      ),
                    );
                  },
                ),
              _DrawerItem(
                icon: Icons.flag_rounded,
                title: 'My Goals',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SetGoalsCalendarScreen()),
                  );
                },
              ),
              if (['5K', '10K', '21.1K', '42.2K', '50K'].contains(appState.me?.plan))
                _DrawerItem(
                  icon: Icons.message,
                  title: 'Messages',
                  onTap: () {
                    Navigator.pop(context); // Close drawer first
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagesPage(
                          currentUserId: currentUserId,
                          coachId: coachId,
                        ),
                      ),
                    );
                  },
                ),
              _DrawerItem(
                icon: Icons.settings,
                title: 'Settings',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        final appState = Provider.of<AppState>(context, listen: false);
                        return ProfileSettingsScreen(
                          isCoach: false,
                          userJson: appState.meJson,
                        );
                      },
                    ),
                  );
                  if (!mounted) return;
                  await appState.refreshAll();
                },
              ),
              _DrawerItem(
                icon: Icons.logout_rounded,
                title: 'Logout',
                color: AppColors.accentRed,
                onTap: () {
                  Navigator.pop(context); // close drawer first
                  _logout(context);
                },
              ),
            ],
          ),
        );
      }

      Widget _buildTodayWorkoutSection(BuildContext context, Assignment todaysAssignment,
          double todaysAssignedKm, double todaysActualKm, int todayProgressPct, VoidCallback onUploadManually) {
        final appState = Provider.of<AppState>(context, listen: false);
        final bool hasAssignment = todaysAssignment.id != null;
        final double displayAssignedKm = hasAssignment ? (todaysAssignment.distanceKm ?? 0.0) : 0.0;
        final int displayAssignedMin = hasAssignment ? (todaysAssignment.durationMin ?? 0) : 0;
        final String currentUserId = appState.me?.id ?? '';
        final String coachId = appState.me?.coachId ?? '';

        const cardGradient = LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        final String assignmentTitle = hasAssignment
            ? (todaysAssignment.workoutType ?? "Assigned Workout")
            : "No Assignment Today";

        final String assignmentDetails = hasAssignment
            ? "${displayAssignedKm.toStringAsFixed(1)} km • $displayAssignedMin min${todaysAssignment.targetPace != null && todaysAssignment.targetPace!.isNotEmpty ? ' • ${todaysAssignment.targetPace}' : ''}"
            : "Enjoy your rest day! 🎉";

        final int progressPct = pct(todaysActualKm, displayAssignedKm);

        return Container(
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header Row ---aaa
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_run, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignmentTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            assignmentDetails,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Progress Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        hasAssignment ? "$progressPct%" : "--",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // --- Stats Row ---
                Row(
                  children: [
                    _buildStatChip(context, "Assigned", "${displayAssignedKm.toStringAsFixed(1)} km"),
                    const SizedBox(width: 10),
                    _buildStatChip(context, "Logged", "${todaysActualKm.toStringAsFixed(2)} km"),
                  ],
                ),

                const SizedBox(height: 14),

                // --- Progress Bar ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: displayAssignedKm > 0
                        ? (todaysActualKm / displayAssignedKm).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPct >= 100
                          ? const Color(0xFF2ECC71)
                          : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    String progressMessage;
                    if (!hasAssignment) {
                      progressMessage = todaysActualKm > 0
                          ? "Independent run logged 🏃"
                          : "No workout assigned today";
                    } else if (progressPct >= 100) {
                      progressMessage = "Target achieved! 🎯";
                    } else {
                      progressMessage = "You've completed $progressPct% of today's target";
                    }
                    return Text(
                      progressMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // --- Action Buttons Row ---
                Row(
                  children: [
                    // Log Activity
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.add_circle_outline,
                        label: "Log Activity",
                        onTap: onUploadManually,
                        color: Colors.white,
                        textColor: const Color(0xFF1976D2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Message Coach
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.chat_bubble_outline,
                        label: "Message",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessagesPage(
                              currentUserId: currentUserId,
                              coachId: coachId,
                            ),
                          ),
                        ),
                        color: Colors.white.withOpacity(0.18),
                        textColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // My Workouts
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.assignment_outlined,
                        label: "Scheduled Workouts",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AthleteAssignmentsScreen(
                              athleteId: currentUserId,
                            ),
                          ),
                        ),
                        color: Colors.white.withOpacity(0.18),
                        textColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

    // Helper: compact stat chip
      Widget _buildStatChip(BuildContext context, String label, String value) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.white.withOpacity(0.8))),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        );
      }

    // Helper: action button inside the card
      Widget _buildActionButton(BuildContext context,
          {required IconData icon,
            required String label,
            required VoidCallback onTap,
            required Color color,
            required Color textColor}) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      Widget _buildRecentActivityList(
          BuildContext context, List<Activity> activities, bool isLoadingActivities) {
        // ── Filter to today only ────────────────────────────────────────────────────
        final today = DateTime.now();
        final todayActivities = activities.where((a) {
          if (a.date == null) return false;
          return a.date!.year == today.year &&
              a.date!.month == today.month &&
              a.date!.day == today.day;
        }).toList();

        return Container(
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200.withOpacity(0.6),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header with date pill ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Runs",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('EEE, MMM d').format(today),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Body ──────────────────────────────────────────────────────────────
              if (isLoadingActivities)
                const Center(
                  child:
                  CircularProgressIndicator(color: AppColors.primaryBlue),
                )
              else if (todayActivities.isNotEmpty)
                Column(
                  children: todayActivities
                      .asMap()
                      .entries
                      .map((entry) {
                    final isLast =
                        entry.key == todayActivities.length - 1;
                    return _buildActivityRow(context, entry.value,
                        isLast: isLast);
                  })
                      .toList(),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28.0),
                    child: Column(
                      children: [
                        Icon(Icons.directions_run,
                            size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          "No runs logged today.",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Tap 'Manual Activity' or sync Strava to add one!",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      Widget _buildDashboardBody(
          BuildContext context,
          Me? me,
          List<Assignment> assignments,
          List<Activity> activities,
          bool isLoadingActivities,
          bool isFreeUser,
          bool isAdvancedUser,
          bool isCoachUser,
          Activity? latestActivity,
          Assignment todaysAssignment,
          double todaysAssignedKm,
          double todaysActualKm,
          int todayProgressPct,
          ) {
        final appState = Provider.of<AppState>(context);

        // ── Today's activities (for the "Recent Activities" section) ──────────
        final today = DateTime.now();
        final todayActivities = activities.where((a) {
          if (a.date == null) return false;
          return a.date!.year == today.year &&
              a.date!.month == today.month &&
              a.date!.day == today.day;
        }).toList();

        // ── This week's totals (for the Goal Tracker section) ──────────────────
        final monday = getStartOfWeek(today);
        final sunday = monday.add(const Duration(days: 6));
        final weekActivities = activities.where((a) {
          if (a.date == null) return false;
          return a.date!.isAfter(monday.subtract(const Duration(seconds: 1))) &&
              a.date!.isBefore(sunday.add(const Duration(days: 1)));
        }).toList();
        final weekTotalKm = weekActivities.fold<double>(0, (s, a) => s + (a.distanceKm ?? 0));
        final weekTotalMin = weekActivities.fold<int>(0, (s, a) => s + (a.durationMin ?? 0));
        final weeklyGoal = appState.dailyGoals.firstWhere(
              (g) => getStartOfWeek(g.date) == monday,
          orElse: () => DailyGoal(date: monday),
        );

        // ── Tools grid data (same features/handlers as _buildBasicFeaturesSection) ─
        final stravaConnected = appState.stravaConnected;
        final toolsFeatures = <Map<String, dynamic>>[
          {
            'icon': Icons.link,
            'title': 'Connect Strava',
            'subtitle': stravaConnected ? '✓ Connected' : 'Sync your runs',
            'onTap': () => _connectStrava(context),
          },
          {
            'icon': Icons.upload_file,
            'title': 'Manual Activity',
            'subtitle': 'Log a new activity',
            'onTap': () {
              _selectedDate = DateTime.now();
              _distanceInputController.clear();
              _timeInputController.clear();
              _openUploadDialog();
            },
          },
          {
            'icon': Icons.speed,
            'title': 'Activity History',
            'subtitle': 'Track your progress',
            'onTap': () {
              final athleteId = me?.id;
              if (athleteId != null) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AthletePaceCalculatorScreen(athleteId: athleteId),
                ));
              }
            },
          },
          {
            'icon': Icons.flag,
            'title': 'Race Predictor',
            'subtitle': 'Estimate race times',
            'onTap': () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AthleteScreenRacePredictor(
                distance: latestActivity?.distanceKm ?? 0,
                duration: latestActivity?.durationMin ?? 0,
              ),
            )),
          },
          {
            'icon': Icons.monitor_heart,
            'title': 'HR Zone',
            'subtitle': 'Optimize heart rate',
            'onTap': () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => HRZoneCalculatorScreen(dateOfBirth: me?.dateOfBirth),
            )),
          },
        ];

        // ── Milestone badges (same logic as AchievementBadgesCard) ─────────────
        final totalDist = activities.fold<double>(0, (s, a) => s + (a.distanceKm ?? 0));
        final hasActivity = activities.isNotEmpty;
        final hasLongRun = activities.any((a) => (a.distanceKm ?? 0) >= 10);
        final hasFastPace = activities.any((a) {
          if ((a.distanceKm ?? 0) <= 0 || (a.durationMin ?? 0) <= 0) return false;
          final paceSec = (a.durationMin! * 60) / a.distanceKm!;
          return paceSec <= 300;
        });
        final hasEarlyRun = activities.any((a) => a.date != null && a.date!.hour < 7);
        final hasNightRun = activities.any((a) => a.date != null && a.date!.hour >= 21);
        final has100km = totalDist >= 100;

        final milestoneBadges = <Map<String, dynamic>>[
          {'icon': Icons.emoji_events, 'label': 'First 10K', 'earned': hasLongRun, 'color': const Color(0xFFF7941D)},
          {'icon': Icons.bolt, 'label': 'Sub-5 Pace', 'earned': hasFastPace, 'color': const Color(0xFF2575FC)},
          {'icon': Icons.wb_sunny_outlined, 'label': 'Early Bird', 'earned': hasEarlyRun, 'color': const Color(0xFFF7C31D)},
          {'icon': Icons.hiking, 'label': 'First Run', 'earned': hasActivity, 'color': const Color(0xFF2ECC71)},
          {'icon': Icons.social_distance, 'label': '100km Club', 'earned': has100km, 'color': const Color(0xFF1ABC9C)},
          {'icon': Icons.nightlight_round, 'label': 'Night Runner', 'earned': hasNightRun, 'color': const Color(0xFF34495E)},
        ];
        final earnedCount = milestoneBadges.where((b) => b['earned'] == true).length;

        // ── Motivation quote ─────────────────────────────────────────────────
        const motivations = [
          "The only bad workout is the one that didn't happen. You showed up — that already puts you ahead.",
          "Every kilometre you run today is a kilometre your future self will thank you for.",
          "Progress isn't always visible day to day — but it's always happening. Keep going.",
          "Champions aren't made in gyms. They're made from something deep inside them — a desire, a dream.",
          "Your legs will do what your mind believes. Believe in the run today.",
          "The pain you feel today will be the strength you feel tomorrow.",
          "Consistency beats perfection every single time. One more run, one more step forward.",
        ];
        final motivationQuote = motivations[(DateTime.now().weekday - 1) % motivations.length];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Always visible: welcome banner ─────────────────────────────────
            _buildWelcomeBanner(context, me, !isFreeUser),
            const SizedBox(height: 20),

            // ── Weekly Streak — collapsible, default open ───────────────────────
            // ── Today's Motivation — full gradient card ──────────────────────────
            if (isAdvancedUser || isCoachUser) ...[
              DailyMotivationCard(name: me?.name ?? "Athlete"),
              const SizedBox(height: 12),
            ],

// ── Weekly Streak — full gradient card ────────────────────────────────
            WeeklyStreakCard(activities: activities),
            const SizedBox(height: 12),

            // ── Always visible: today's headline card (coach plan only) ────────
            if (isCoachUser) ...[
              _buildTodayWorkoutSection(
                context,
                todaysAssignment,
                todaysAssignedKm,
                todaysActualKm,
                todayProgressPct,
                    () {
                  _selectedDate = DateTime.now();
                  _distanceInputController.clear();
                  _timeInputController.clear();
                  _openUploadDialog();
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Weekly Goal — collapsible, default open ──────────────────────────
            CollapsibleSection(
              sectionId: 'weekly_goal',
              title: 'Weekly Goal',
              icon: Icons.flag_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              ),
              initiallyExpanded: true,
              summary: '${weekTotalKm.toStringAsFixed(1)} km logged this week',
              child: CompactGoalTracker(
                totalKm: weekTotalKm,
                totalMin: weekTotalMin,
                weeklyGoal: weeklyGoal,
                onSetGoal: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SetGoalsCalendarScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Advanced Metrics — collapsible, default CLOSED (advanced plan) ──
            if (isAdvancedUser) ...[
              CollapsibleSection(
                sectionId: 'advanced_metrics',
                title: 'Advanced Metrics',
                icon: Icons.monitor_heart_outlined,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
                ),
                initiallyExpanded: false,
                summary: 'VO2 Max · Heart Rate trends',
                child: const Column(
                  children: [
                    CompactWatchPrompt(
                        message: 'Connect your smartwatch to unlock VO2 Max estimation'),
                    SizedBox(height: 10),
                    CompactWatchPrompt(
                        message: 'Connect your smartwatch to see Heart Rate trends and zones'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Your Tools — collapsible, default CLOSED ─────────────────────────
            CollapsibleSection(
              sectionId: 'your_tools',
              title: 'Your Tools',
              icon: Icons.apps_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              ),
              initiallyExpanded: false,
              summary: '${toolsFeatures.length} tools available',
              child: CompactToolsGrid(features: toolsFeatures),
            ),
            const SizedBox(height: 12),

            // ── Milestones — collapsible, default CLOSED ─────────────────────────
            if (isAdvancedUser || isCoachUser) ...[
              CollapsibleSection(
                sectionId: 'milestones',
                title: 'Milestones',
                icon: Icons.emoji_events_outlined,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
                ),
                initiallyExpanded: false,
                summary: '$earnedCount of ${milestoneBadges.length} earned',
                child: CompactMilestones(badges: milestoneBadges),
              ),
              const SizedBox(height: 12),
            ],

            // ── AI Insights — kept as its own existing widget, just no header text ─
            if (isFreeUser || isAdvancedUser) ...[
              CollapsibleSection(
                sectionId: 'ai_insights',
                title: 'AI Insights',
                icon: Icons.insights_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
                ),
                initiallyExpanded: true,
                child: const UnifiedAIAnalysisCard(),
              ),
              const SizedBox(height: 12),
            ],

            // ── Recent / Today's Activities — collapsible, default open ──────────
            CollapsibleSection(
              sectionId: 'recent_activities',
              title: isFreeUser ? 'Recent Run Activities' : "Today's Runs",
              icon: Icons.directions_run_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              ),
              initiallyExpanded: true,
              summary: '${todayActivities.length} logged today',
              child: isLoadingActivities
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1976D2))),
              )
                  : todayActivities.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  children: [
                    Icon(Icons.directions_run, size: 34, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text("No runs logged today.",
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMedium)),
                    const SizedBox(height: 4),
                    Text("Tap 'Manual Activity' or sync Strava to add one!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textLight)),
                  ],
                ),
              )
                  : Column(
                children: todayActivities.asMap().entries.map((entry) {
                  final a = entry.value;
                  final isLast = entry.key == todayActivities.length - 1;
                  String paceStr = '—';
                  final dist = a.distanceKm ?? 0;
                  final dur = a.durationMin ?? 0;
                  if (dist > 0 && dur > 0) {
                    final totalSec = (dur * 60) / dist;
                    final mins = totalSec ~/ 60;
                    final secs = (totalSec % 60).round();
                    paceStr = '$mins:${secs.toString().padLeft(2, '0')} /km';
                  }
                  return CompactActivityRow(
                    title: _getActivityTitle(a),
                    timeLabel: a.date != null ? DateFormat.jm().format(a.date!) : '—',
                    distanceLabel: '${a.distanceKm?.toStringAsFixed(2) ?? "0.00"} km',
                    durationLabel: '${a.durationMin?.round() ?? 0} min',
                    paceLabel: paceStr,
                    isFromStrava: a.isFromStrava,
                    isLast: isLast,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }

      Widget _buildActivityRow(BuildContext context, Activity a,
          {required bool isLast}) {
        // ── Pace calculation ────────────────────────────────────────────────────────
        String paceStr = '—';
        final dist = a.distanceKm ?? 0;
        final dur = a.durationMin ?? 0;
        if (dist > 0 && dur > 0) {
          final totalSec = (dur * 60) / dist;
          final mins = totalSec ~/ 60;
          final secs = (totalSec % 60).round();
          paceStr =
          '$mins:${secs.toString().padLeft(2, '0')} /km';
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: icon ────────────────────────────────────────────────
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: a.isFromStrava
                          ? const Color(0xFFFC4C02).withOpacity(0.1)
                          : AppColors.primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_run,
                      size: 20,
                      color: a.isFromStrava
                          ? const Color(0xFFFC4C02)
                          : AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Middle: title + date + strava badge ───────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getActivityTitle(a),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (a.isFromStrava) ...[
                              const SizedBox(width: 8),
                              const _StravaSourceBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.date != null
                              ? DateFormat.jm().format(a.date!) // time only — date is implicit (today)
                              : '—',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Right: km · min · pace ─────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Distance
                      Text(
                        '${a.distanceKm?.toStringAsFixed(2) ?? "0.00"} km',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: a.isFromStrava
                              ? const Color(0xFFFC4C02)
                              : AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Duration
                      Text(
                        '${a.durationMin?.round() ?? 0} min',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppColors.textMedium),
                      ),
                      const SizedBox(height: 3),
                      // Pace chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (a.isFromStrava
                              ? const Color(0xFFFC4C02)
                              : AppColors.primaryBlue)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.speed,
                              size: 10,
                              color: a.isFromStrava
                                  ? const Color(0xFFFC4C02)
                                  : AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              paceStr,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: a.isFromStrava
                                    ? const Color(0xFFFC4C02)
                                    : AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(
                  height: 1, thickness: 1, color: AppColors.dividerColor),
          ],
        );
      }
    }

    // Custom button widget to apply gradient
    class GradientButton extends StatelessWidget {
      const GradientButton({
        super.key,
        required this.onPressed,
        required this.child,
        this.gradient = welcomeBannerGradient, // Default to banner gradient
        this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        this.borderRadius = 8.0,
        this.disabled = false,
      });

      final VoidCallback onPressed;
      final Widget child;
      final LinearGradient gradient;
      final EdgeInsetsGeometry padding;
      final double borderRadius;
      final bool disabled;

      @override
      Widget build(BuildContext context) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: disabled ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade600]) : gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [ // Add subtle shadow for depth
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: disabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: padding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ).copyWith(
              foregroundColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.disabled)) {
                    return Colors.white.withOpacity(0.7);
                  }
                  return Colors.white;
                },
              ),
              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.pressed)) {
                    return Colors.white.withOpacity(0.2);
                  }
                  return null;
                },
              ),
            ),
            child: child,
          ),
        );
      }
    }

    // Custom Drawer Item (used for both Drawer and fixed Sidebar)
    class _DrawerItem extends StatelessWidget {
      final IconData icon;
      final String title;
      final VoidCallback onTap;
      final bool isSelected;
      final Color? color; // NEW: optional override, e.g. red for Logout

      const _DrawerItem({
        required this.icon,
        required this.title,
        required this.onTap,
        this.isSelected = false,
        this.color,
      });

      @override
      Widget build(BuildContext context) {
        final iconColor = color ?? (isSelected ? Colors.white : AppColors.textMedium);
        final textColor = color ?? (isSelected ? Colors.white : AppColors.textDark);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: isSelected
              ? BoxDecoration(
            gradient: sidebarGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          )
              : null,
          child: ListTile(
            leading: Icon(icon, color: iconColor, size: 26),
            title: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 17,
              ),
            ),
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }

    class AthleteDashboardApp extends StatelessWidget {
      const AthleteDashboardApp({super.key});

      @override
      Widget build(BuildContext context) {
        return ChangeNotifierProvider(
          create: (_) => AppState(),
          child: MaterialApp(
            title: 'Athlete Dashboard',
            debugShowCheckedModeBanner: false, // Hide debug banner
            theme: ThemeData(
              primarySwatch: Colors.blue,
              primaryColor: AppColors.primaryBlue,
              cardColor: AppColors.cardBackground,
              scaffoldBackgroundColor: AppColors.backgroundLightGrey,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.textDark,
                elevation: 0,
                iconTheme: IconThemeData(color: AppColors.textMedium),
                titleTextStyle: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Slightly more rounded
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // More rounded inputs
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                labelStyle: const TextStyle(color: AppColors.textDark, fontFamily: 'Poppins'),
                hintStyle: TextStyle(color: Colors.grey.shade500, fontFamily: 'Poppins'),
              ),
              cardTheme: CardThemeData( // Keep card theme for potential future use or consistency
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
                margin: EdgeInsets.zero,
              ),
              textTheme: GoogleFonts.poppinsTextTheme().copyWith(
                headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark),
                headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textDark),
                headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
                titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
                titleMedium: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark),
                titleSmall: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textDark),
                bodyLarge: const TextStyle(fontSize: 16, color: AppColors.textDark),
                bodyMedium: const TextStyle(fontSize: 14, color: AppColors.textDark),
                bodySmall: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ),
            home: const AthleteDashboard(),
            routes: {
              '/calendar': (context) => const CalendarScreen(),
              '/settings': (context) {
                // Routes don't have AppState access easily, so use empty map as fallback
                // The real navigation always goes through the drawer/sidebar which passes full data
                return ProfileSettingsScreen(isCoach: false, userJson: const {});
              },
            },
          ),
        );
      }
    }

    // --- New Component: Weekly Streak Card ---

    // ── Drop-in replacement for WeeklyStreakCard ───────────────────────────────────
    // Change: shows Mon–Sun of the CURRENT calendar week instead of rolling 7 days.

    class WeeklyStreakCard extends StatelessWidget {
      final List<Activity> activities;

      const WeeklyStreakCard({super.key, required this.activities});

      @override
      Widget build(BuildContext context) {
        final DateTime today = DateTime.now();

        // ── Current week: Monday → Sunday ────────────────────────────────────────
        // DateTime.weekday: Mon=1 … Sun=7
        final DateTime monday = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: today.weekday - 1)); // rewind to Monday

        // Build status for each of the 7 days (Mon … Sun)
        final List<({DateTime date, bool hasActivity, bool isFuture})> days =
        List.generate(7, (i) {
          final DateTime day = monday.add(Duration(days: i));
          final bool isFuture = day.isAfter(today);
          final bool hasActivity = isFuture
              ? false
              : activities.any((a) {
            if (a.date == null) return false;
            return a.date!.year == day.year &&
                a.date!.month == day.month &&
                a.date!.day == day.day;
          });
          return (date: day, hasActivity: hasActivity, isFuture: isFuture);
        });

        final int completedCount =
            days.where((d) => d.hasActivity).length;

        // ── Dynamic colour / motivation ──────────────────────────────────────────
        LinearGradient cardGradient;
        String motivation;
        Color shadowColor;

        if (completedCount >= 6) {
          cardGradient = const LinearGradient(
            colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          motivation = 'Absolute Legend! Perfect consistency this week! 🔥';
          shadowColor = const Color(0xFF2ECC71).withOpacity(0.4);
        } else if (completedCount >= 4) {
          cardGradient = const LinearGradient(
            colors: [Color(0xFF2575FC), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          motivation = "Great job! You're staying consistent. 💪";
          shadowColor = const Color(0xFF2575FC).withOpacity(0.4);
        } else {
          cardGradient = const LinearGradient(
            colors: [Color(0xFF2575FC), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
          motivation = "Let's get moving! You can do this. 🏃";
          shadowColor = const Color(0xFF2575FC).withOpacity(0.4);
        }

        // Short day labels Mon … Sun
        const List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

        // Date range label e.g. "May 19 – May 25"
        final DateTime sunday = monday.add(const Duration(days: 6));
        final String weekRange =
            '${DateFormat('MMM d').format(monday)} – ${DateFormat('MMM d').format(sunday)}';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Weekly Performance',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Week range pill
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      weekRange,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),

              // ── Active count ────────────────────────────────────────────────────
              Text(
                '$completedCount Days Active',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),

              // ── Motivation ──────────────────────────────────────────────────────
              Text(
                motivation,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),

              // ── Day indicators (Mon → Sun) ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final d = days[i];
                  final bool isToday = d.date.year == today.year &&
                      d.date.month == today.month &&
                      d.date.day == today.day;

                  return Column(
                    children: [
                      // Tick / cross / future dot
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: d.isFuture
                              ? Colors.white.withOpacity(0.15)
                              : d.hasActivity
                              ? Colors.white.withOpacity(0.25)
                              : Colors.white.withOpacity(0.12),
                          border: isToday
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: d.isFuture
                            ? Icon(Icons.remove,
                            color: Colors.white.withOpacity(0.4), size: 16)
                            : Icon(
                          d.hasActivity
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          color: d.hasActivity
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Day label
                      Text(
                        dayLabels[i],
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? Colors.white
                              : Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      }
    }

    class WeeklyGoalTrackerCard extends StatelessWidget {
      final List<Activity> activities;
      final List<DailyGoal> goals;

      const WeeklyGoalTrackerCard(
          {super.key, required this.activities, required this.goals});

      @override
      Widget build(BuildContext context) {
        final now = DateTime.now();
        final monday = getStartOfWeek(now);
        final sunday = monday.add(const Duration(days: 6));

        final weeklyGoal = goals.firstWhere(
              (g) => getStartOfWeek(g.date) == monday,
          orElse: () => DailyGoal(date: monday),
        );

        final weekActivities = activities.where((a) {
          if (a.date == null) return false;
          return a.date!.isAfter(monday.subtract(const Duration(seconds: 1))) &&
              a.date!.isBefore(sunday.add(const Duration(days: 1)));
        }).toList();

        final double totalKm =
        weekActivities.fold(0, (s, a) => s + (a.distanceKm ?? 0));
        final int totalMin =
        weekActivities.fold(0, (s, a) => s + (a.durationMin ?? 0));

        final bool hasDistGoal = weeklyGoal.distanceKm > 0;
        final bool hasTimeGoal = weeklyGoal.durationMin > 0;
        final bool noGoal = !hasDistGoal && !hasTimeGoal;

        final distPct =
        hasDistGoal ? (totalKm / weeklyGoal.distanceKm).clamp(0.0, 1.0) : 0.0;
        final timePct = hasTimeGoal
            ? (totalMin / weeklyGoal.durationMin).clamp(0.0, 1.0)
            : 0.0;

        String message;
        if (noGoal) {
          message = "Set a weekly goal to track your progress! 🎯";
        } else if (hasDistGoal && hasTimeGoal) {
          final both = distPct >= 1.0 && timePct >= 1.0;
          message = both
              ? "CHAMPION! You nailed both goals this week! 🔥🏆"
              : "Keep going — you're working towards distance & time! 💪";
        } else if (hasDistGoal) {
          message = distPct >= 1.0
              ? "CHAMPION! You smashed your ${weeklyGoal.distanceKm}km goal! 🔥🏆"
              : distPct > 0.7
              ? "Almost there! ${(weeklyGoal.distanceKm - totalKm).toStringAsFixed(1)}km to go! 💪"
              : "You've got this! Keep clocking those kms. 🏃‍♂️";
        } else {
          message = timePct >= 1.0
              ? "CHAMPION! You hit your ${weeklyGoal.durationMin} min goal! 🔥🏆"
              : timePct > 0.7
              ? "So close! ${weeklyGoal.durationMin - totalMin} min left! 💪"
              : "Keep running — every minute counts! 🏃‍♂️";
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 15),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Weekly Goal Tracker",
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: noGoal
                          ? null
                          : const LinearGradient(
                          colors: [Color(0xFF1976D2), Color(0xFFE6783A)]),
                      color: noGoal ? Colors.grey.shade100 : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      noGoal
                          ? "No Goal Set"
                          : (hasDistGoal && hasTimeGoal
                          ? "Distance + Time"
                          : hasDistGoal
                          ? "Distance"
                          : "Time"),
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: noGoal ? Colors.grey : Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(message,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 18),

              // ── No-goal empty state with CTA button ───────────────────────────
              if (noGoal)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, // stretch to full card width
                  children: [
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                              builder: (_) => const SetGoalsCalendarScreen()),
                        ),
                        child: Container(
                          // full width of the column, then auto-height
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center, // icon + text centred
                            children: [
                              const Icon(Icons.flag_rounded,
                                  size: 16, color: Color(0xFF1976D2)),
                              const SizedBox(width: 8),
                              Text(
                                'Set Weekly Goal',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                // ── Distance progress bar ──────────────────────────────────────
                if (hasDistGoal) ...[
                  _buildProgressRow(
                    context,
                    icon: Icons.directions_run,
                    label: "Distance",
                    current: "${totalKm.toStringAsFixed(1)} km",
                    goal: "${weeklyGoal.distanceKm} km",
                    progress: distPct,
                    color: const Color(0xFFFFFFFF),
                  ),
                  if (hasTimeGoal) const SizedBox(height: 14),
                ],
                // ── Time progress bar ──────────────────────────────────────────
                if (hasTimeGoal)
                  _buildProgressRow(
                    context,
                    icon: Icons.timer_outlined,
                    label: "Duration",
                    current: "${totalMin} min",
                    goal: "${weeklyGoal.durationMin} min",
                    progress: timePct,
                    color: const Color(0xFFFFFFFF),
                  ),
              ],
            ],
          ),
        );
      }

      Widget _buildProgressRow(
          BuildContext context, {
            required IconData icon,
            required String label,
            required String current,
            required String goal,
            required double progress,
            required Color color,
          }) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFFFFF))),
                const Spacer(),
                Text("$current / $goal",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? const Color(0xFFFFFFFF) : color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${(progress * 100).round()}% completed",
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
            ),
          ],
        );
      }
    }

    // ============================================================
    // ADVANCED PLAN WIDGETS
    // ============================================================

    class VO2MaxCard extends StatelessWidget {
      final List<Activity> activities;
      const VO2MaxCard({super.key, required this.activities});

      // Estimate VO2Max from recent pace: simplified Daniels formula
      double _estimateVO2Max() {
        if (activities.isEmpty) return 0;
        final recent = activities.first;
        final dist = recent.distanceKm ?? 0;
        final dur = recent.durationMin ?? 0;
        if (dist <= 0 || dur <= 0) return 0;
        // Speed in m/min
        final speedMperMin = (dist * 1000) / dur;
        final vo2 = -4.60 + 0.182258 * speedMperMin + 0.000104 * speedMperMin * speedMperMin;
        return vo2.clamp(20.0, 80.0);
      }

      String _fitnessCategory(double vo2) {
        if (vo2 >= 55) return "Superior 🏆";
        if (vo2 >= 48) return "Excellent 💪";
        if (vo2 >= 42) return "Good 👍";
        if (vo2 >= 35) return "Fair 🏃";
        return "Needs Work 📈";
      }

      @override
      Widget build(BuildContext context) {
        final vo2 = _estimateVO2Max();
        final hasSyncedData = activities.isNotEmpty;
        final category = vo2 > 0 ? _fitnessCategory(vo2) : "—";
        // Percentile 0-1 for range 30-65
        final progress = vo2 > 0 ? ((vo2 - 30) / 35).clamp(0.0, 1.0) : 0.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2575FC).withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
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
                    child: const Icon(Icons.air, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("VO2 Max Estimation",
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text("Based on recent run performance",
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // if (!hasSyncedData)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.watch_outlined, color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Connect your smartwatch to enable VO2 Max estimation",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.white.withOpacity(0.9)),
                      ),
                    ),
                  ],
                ),
              ),
              // else ...[
              //   Text(
              //     vo2.toStringAsFixed(1),
              //     style: GoogleFonts.poppins(
              //         fontSize: 52, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
              //   ),
              //   Text("mL/kg/min",
              //       style: GoogleFonts.poppins(
              //           fontSize: 13, color: Colors.white.withOpacity(0.8))),
              //   const SizedBox(height: 12),
              //   Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              //     decoration: BoxDecoration(
              //       color: Colors.white.withOpacity(0.2),
              //       borderRadius: BorderRadius.circular(20),
              //     ),
              //     child: Text(
              //       category,
              //       style: GoogleFonts.poppins(
              //           fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              //     ),
              //   ),
              //   const SizedBox(height: 14),
              //   ClipRRect(
              //     borderRadius: BorderRadius.circular(6),
              //     child: LinearProgressIndicator(
              //       value: progress,
              //       minHeight: 8,
              //       backgroundColor: Colors.white.withOpacity(0.25),
              //       valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              //     ),
              //   ),
              //   const SizedBox(height: 6),
              //   Text("Typical range: 30–65 mL/kg/min",
              //       style: GoogleFonts.poppins(
              //           fontSize: 11, color: Colors.white.withOpacity(0.7))),
              // ],
              // const SizedBox(height: 14),
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //   decoration: BoxDecoration(
              //     color: Colors.white.withOpacity(0.15),
              //     borderRadius: BorderRadius.circular(10),
              //   ),
              //   child: Row(
              //     children: [
              //       Container(
              //         width: 8, height: 8,
              //         decoration: const BoxDecoration(
              //           color: Color(0xFF7FDDAA), shape: BoxShape.circle,
              //         ),
              //       ),
              //       const SizedBox(width: 8),
              //       Text(
              //         hasSyncedData
              //             ? "Estimated from your run data · Sync watch for precision":"",
              //         style: GoogleFonts.poppins(
              //             fontSize: 11, color: Colors.white.withOpacity(0.85)),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        );
      }
    }


    class HRTrendCard extends StatelessWidget {
      final List<Activity> activities;
      const HRTrendCard({super.key, required this.activities});

      @override
      Widget build(BuildContext context) {
        final now = DateTime.now();

        // Build 7-day data (placeholder avg HR per day from activities)
        // In real app you'd pull HR data from watch sync
        final List<Map<String, dynamic>> days = List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          final dayActivities = activities.where((a) =>
          a.date != null &&
              a.date!.year == date.year &&
              a.date!.month == date.month &&
              a.date!.day == date.day).toList();
          final hasActivity = dayActivities.isNotEmpty;
          // Simulated HR (in real app: pull from watch data)
          final simulatedHr = hasActivity ? (140 + (i * 5) % 25) : 0;
          return {
            'label': ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
            'hr': simulatedHr,
            'hasActivity': hasActivity,
          };
        });

        final activeDays = days.where((d) => d['hasActivity'] as bool).toList();
        final avgHr = activeDays.isEmpty
            ? 0
            : activeDays.fold<int>(0, (sum, d) => sum + (d['hr'] as int)) ~/
            activeDays.length;
        final maxHr = activeDays.isEmpty
            ? 0
            : activeDays.map((d) => d['hr'] as int).reduce((a, b) => a > b ? a : b);

        final hasWatchData = activeDays.isNotEmpty;

        // AFTER
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.35),
                  blurRadius: 15, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AFTER
              Text("Heart Rate Trends",
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("7-day overview ",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 16),

              // if (!hasWatchData)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.watch_outlined,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Connect your smartwatch to see HR trends, HR zones and resting HR",
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )
              // else ...[
              //   // 7-day bars
              //   Row(
              //     crossAxisAlignment: CrossAxisAlignment.end,
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: days.map((day) {
              //       final hr = day['hr'] as int;
              //       final hasAct = day['hasActivity'] as bool;
              //       final maxVal = 180;
              //       final heightFraction = hasAct ? (hr / maxVal).clamp(0.0, 1.0) : 0.0;
              //
              //       Color barColor = const Color(0xFF2575FC);
              //       if (hr > 165) barColor = const Color(0xFFE74C3C);
              //       else if (hr > 155) barColor = const Color(0xFFE6783A);
              //       else if (hr < 145) barColor = const Color(0xFF2ECC71);
              //
              //       return Column(
              //         children: [
              //           Text(
              //             hasAct ? "$hr" : "—",
              //             style: GoogleFonts.poppins(
              //                 fontSize: 10,
              //                 fontWeight: FontWeight.w600,
              //                 color: AppColors.textDark),
              //           ),
              //           const SizedBox(height: 4),
              //           Container(
              //             width: 28,
              //             height: 64,
              //             decoration: BoxDecoration(
              //               gradient: const LinearGradient(
              //                 colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
              //                 begin: Alignment.topCenter,
              //                 end: Alignment.bottomCenter,
              //               ),
              //               borderRadius: BorderRadius.circular(6),
              //             ),
              //             alignment: Alignment.bottomCenter,
              //             child: AnimatedContainer(
              //               duration: const Duration(milliseconds: 600),
              //               width: 28,
              //               height: 64 * heightFraction,
              //               decoration: BoxDecoration(
              //                 color: hasAct ? barColor : Colors.transparent,
              //                 borderRadius: BorderRadius.circular(6),
              //               ),
              //             ),
              //           ),
              //           const SizedBox(height: 4),
              //           Text(day['label'] as String,
              //               style: GoogleFonts.poppins(
              //                   fontSize: 11, color: AppColors.textMedium)),
              //         ],
              //       );
              //     }).toList(),
              //   ),
              //   const SizedBox(height: 16),
              //   Row(
              //     children: [
              //       _HRChip(label: "Avg HR", value: "$avgHr bpm",
              //           color: AppColors.primaryBlue),
              //       const SizedBox(width: 10),
              //       _HRChip(label: "Max HR", value: "$maxHr bpm",
              //           color: AppColors.accentRed),
              //       const SizedBox(width: 10),
              //       _HRChip(label: "Resting", value: "—",
              //           color: AppColors.accentGreen),
              //     ],
              //   ),
              //   const SizedBox(height: 10),
              //   // AFTER
              //   Text(
              //     "💡 Sync your watch for resting HR and precise zone data",
              //     style: GoogleFonts.poppins(
              //         fontSize: 11, color: Colors.white.withOpacity(0.8),
              //         fontStyle: FontStyle.italic),
              //   ),
              // ],
            ],
          ),
        );
      }
    }

    class _HRChip extends StatelessWidget {
      final String label;
      final String value;
      final Color color;
      const _HRChip(
          {required this.label, required this.value, required this.color});

      @override
      Widget build(BuildContext context) {
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMedium)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        );
      }
    }


    // class CadenceAnalysisCard extends StatelessWidget {
    //   final List<Activity> activities;
    //   const CadenceAnalysisCard({super.key, required this.activities});
    //
    //   String _cadenceTip(int cadence) {
    //     if (cadence == 0) return "Sync your smartwatch to track cadence data.";
    //     if (cadence >= 170 && cadence <= 180) {
    //       return "You're in the optimal cadence range! Great running efficiency. 🎯";
    //     } else if (cadence < 170) {
    //       return "Try increasing your cadence slightly. Aim for 170–180 spm to reduce injury risk.";
    //     } else {
    //       return "Your cadence is high — focus on relaxing your stride for better economy.";
    //     }
    //   }
    //
    //   @override
    //   Widget build(BuildContext context) {
    //     // Simulated cadence (real app: from watch sync)
    //     final hasSyncedData = activities.isNotEmpty;
    //     final cadence = hasSyncedData ? 174 : 0; // placeholder
    //     final barValues = hasSyncedData
    //         ? [0.6, 0.75, 0.82, 0.88, 0.91, 0.85, 0.95]
    //         : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    //
    //     return Container(
    //       width: double.infinity,
    //       padding: const EdgeInsets.all(20),
    //       decoration: BoxDecoration(
    //         gradient: const LinearGradient(
    //           colors: [Color(0xFFE6783A), Color(0xFFF7941D)],
    //           begin: Alignment.topLeft,
    //           end: Alignment.bottomRight,
    //         ),
    //         borderRadius: BorderRadius.circular(20),
    //         boxShadow: [
    //           BoxShadow(
    //             color: const Color(0xFFE6783A).withOpacity(0.35),
    //             blurRadius: 16, offset: const Offset(0, 6),
    //           ),
    //         ],
    //       ),
    //       child: Column(
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [
    //           Row(
    //             children: [
    //               Container(
    //                 padding: const EdgeInsets.all(8),
    //                 decoration: BoxDecoration(
    //                   color: Colors.white.withOpacity(0.2),
    //                   borderRadius: BorderRadius.circular(10),
    //                 ),
    //                 child: const Icon(Icons.directions_run,
    //                     color: Colors.white, size: 20),
    //               ),
    //               const SizedBox(width: 10),
    //               Column(
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Text("Cadence Analysis",
    //                       style: GoogleFonts.poppins(
    //                           fontSize: 15, fontWeight: FontWeight.w700,
    //                           color: Colors.white)),
    //                   Text("Steps per minute · Last 7 runs",
    //                       style: GoogleFonts.poppins(
    //                           fontSize: 11,
    //                           color: Colors.white.withOpacity(0.8))),
    //                 ],
    //               ),
    //             ],
    //           ),
    //           const SizedBox(height: 16),
    //           Row(
    //             crossAxisAlignment: CrossAxisAlignment.end,
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Column(
    //                 crossAxisAlignment: CrossAxisAlignment.start,
    //                 children: [
    //                   Text(
    //                     cadence > 0 ? "$cadence" : "—",
    //                     style: GoogleFonts.poppins(
    //                         fontSize: 44, fontWeight: FontWeight.w800,
    //                         color: Colors.white, height: 1.0),
    //                   ),
    //                   Text("steps/min (avg)",
    //                       style: GoogleFonts.poppins(
    //                           fontSize: 13,
    //                           color: Colors.white.withOpacity(0.85))),
    //                 ],
    //               ),
    //               // Mini bar chart
    //               SizedBox(
    //                 height: 56,
    //                 child: Row(
    //                   crossAxisAlignment: CrossAxisAlignment.end,
    //                   children: barValues.map((v) {
    //                     return Container(
    //                       width: 10,
    //                       margin: const EdgeInsets.only(left: 4),
    //                       height: 56 * v,
    //                       decoration: BoxDecoration(
    //                         color: v > 0
    //                             ? Colors.white.withOpacity(v > 0.5 ? 0.9 : 0.4)
    //                             : Colors.white.withOpacity(0.2),
    //                         borderRadius: BorderRadius.circular(3),
    //                       ),
    //                     );
    //                   }).toList(),
    //                 ),
    //               ),
    //             ],
    //           ),
    //           const SizedBox(height: 14),
    //           Container(
    //             padding: const EdgeInsets.all(12),
    //             decoration: BoxDecoration(
    //               color: Colors.white.withOpacity(0.18),
    //               borderRadius: BorderRadius.circular(10),
    //             ),
    //             child: Row(
    //               children: [
    //                 const Text("💡", style: TextStyle(fontSize: 14)),
    //                 const SizedBox(width: 8),
    //                 Expanded(
    //                   child: Text(
    //                     _cadenceTip(cadence),
    //                     style: GoogleFonts.poppins(
    //                         fontSize: 12, color: Colors.white.withOpacity(0.95)),
    //                   ),
    //                 ),
    //               ],
    //             ),
    //           ),
    //         ],
    //       ),
    //     );
    //   }
    // }


    class AchievementBadgesCard extends StatelessWidget {
      final List<Activity> activities;
      const AchievementBadgesCard({super.key, required this.activities});

      @override
      Widget build(BuildContext context) {
        // Compute earned badges dynamically
        final totalDist = activities.fold<double>(
            0, (s, a) => s + (a.distanceKm ?? 0));
        final hasActivity = activities.isNotEmpty;
        final hasLongRun = activities.any((a) => (a.distanceKm ?? 0) >= 10);
        final has7DayStreak = _calculateStreak(activities) >= 7;
        final has30DayStreak = _calculateStreak(activities) >= 30;
        final hasFastPace = activities.any((a) {
          if ((a.distanceKm ?? 0) <= 0 || (a.durationMin ?? 0) <= 0) return false;
          final paceSec = (a.durationMin! * 60) / a.distanceKm!;
          return paceSec <= 300; // sub 5 min/km
        });
        final hasEarlyRun = activities.any(
                (a) => a.date != null && a.date!.hour < 7);
        final hasNightRun = activities.any(
                (a) => a.date != null && a.date!.hour >= 21);
        final has100km = totalDist >= 100;

        final badges = [
          {'icon': Icons.local_fire_department, 'label': '7-Day Streak', 'earned': has7DayStreak, 'color': const Color(0xFFE74C3C)},
          {'icon': Icons.emoji_events, 'label': 'First 10K', 'earned': hasLongRun, 'color': const Color(0xFFF7941D)},
          {'icon': Icons.bolt, 'label': 'Sub-5 Pace', 'earned': hasFastPace, 'color': const Color(0xFF2575FC)},
          {'icon': Icons.wb_sunny_outlined, 'label': 'Early Bird', 'earned': hasEarlyRun, 'color': const Color(0xFFF7C31D)},
          {'icon': Icons.hiking, 'label': 'First Run', 'earned': hasActivity, 'color': const Color(0xFF2ECC71)},
          {'icon': Icons.star, 'label': '30-Day Streak', 'earned': has30DayStreak, 'color': const Color(0xFF9B59B6)},
          {'icon': Icons.social_distance, 'label': '100km Club', 'earned': has100km, 'color': const Color(0xFF1ABC9C)},
          {'icon': Icons.nightlight_round, 'label': 'Night Runner', 'earned': hasNightRun, 'color': const Color(0xFF34495E)},
        ];

        final earnedCount = badges.where((b) => b['earned'] as bool).length;
        final total = badges.length;
        final progress = earnedCount / total;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.shade200.withOpacity(0.8),
                  blurRadius: 15, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Performance Badges ",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  Text("$earnedCount / $total",
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.dividerColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue),
                ),
              ),
              const SizedBox(height: 18),
              // Replace the GridView.builder with this:
              Wrap(
                spacing: 8,
                runSpacing: 16,
                children: List.generate(badges.length, (i) {
                  final badge = badges[i];
                  final earned = badge['earned'] as bool;
                  final color = badge['color'] as Color;
                  final isWide = MediaQuery.of(context).size.width > 600;
                  final screenWidth = MediaQuery.of(context).size.width;
                  final itemWidth = isWide
                      ? (screenWidth - 380 - 80) / 4   // 4 per row on large screens
                      : (screenWidth - 80 - 48) / 4;   // 4 per row on small screens too

                  return SizedBox(
                    width: itemWidth,
                    height: 90,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: earned
                                ? LinearGradient(
                                colors: [color, color.withOpacity(0.6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                                : null,
                            color: earned ? null : const Color(0xFFE8ECF0),
                            boxShadow: earned
                                ? [BoxShadow(
                                color: color.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3))]
                                : null,
                          ),
                          child: Icon(
                            earned ? (badge['icon'] as IconData) : Icons.lock_outline,
                            color: earned ? Colors.white : const Color(0xFFBDC3C7),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          badge['label'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: earned ? AppColors.textDark : AppColors.textLight,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      }

      int _calculateStreak(List<Activity> activities) {
        if (activities.isEmpty) return 0;
        final sorted = activities
            .where((a) => a.date != null)
            .toList()
          ..sort((a, b) => b.date!.compareTo(a.date!));

        int streak = 0;
        DateTime? lastDate;

        for (final act in sorted) {
          final d = DateTime(act.date!.year, act.date!.month, act.date!.day);
          if (lastDate == null) {
            lastDate = d;
            streak = 1;
          } else {
            final diff = lastDate.difference(d).inDays;
            if (diff == 1) {
              streak++;
              lastDate = d;
            } else if (diff == 0) {
              continue;
            } else {
              break;
            }
          }
        }
        return streak;
      }
    }


    class DailyMotivationCard extends StatelessWidget {
      final String name;
      const DailyMotivationCard({super.key, required this.name});

      String _getMotivation() {
        final messages = [
          "The only bad workout is the one that didn't happen. You showed up — that already puts you ahead.",
          "Every kilometre you run today is a kilometre your future self will thank you for.",
          "Progress isn't always visible day to day — but it's always happening. Keep going, $name.",
          "Champions aren't made in gyms. They're made from something deep inside them — a desire, a dream.",
          "Your legs will do what your mind believes. Believe in the run today.",
          "The pain you feel today will be the strength you feel tomorrow.",
          "Consistency beats perfection every single time. One more run, one more step forward.",
        ];
        final index = DateTime.now().weekday - 1;
        return messages[index % messages.length];
      }

      @override
      Widget build(BuildContext context) {
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        final today = days[DateTime.now().weekday - 1];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A11CB).withOpacity(0.35),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
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
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text("$today's Motivation",
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.3)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '"${_getMotivation()}"',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "— Your endurepeak · $today",
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.65)),
              ),
            ],
          ),
        );
      }
    }

    class StravaActivitiesCard extends StatelessWidget {
      const StravaActivitiesCard({super.key});

      @override
      Widget build(BuildContext context) {
        final appState = Provider.of<AppState>(context);

        // Only render if Strava is connected
        if (!appState.stravaConnected) return const SizedBox.shrink();

        final activities = appState.stravaActivities;
        final isLoading = appState.isLoadingStrava;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200.withOpacity(0.8),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFC4C02), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    // Strava flame-style icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_run,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Strava Activities',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${activities.length} run${activities.length == 1 ? '' : 's'} synced',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sync button
                    GestureDetector(
                      onTap: () => appState.fetchStravaActivities(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sync,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Sync',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: isLoading
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(
                        color: Color(0xFFFC4C02)),
                  ),
                )
                    : activities.isEmpty
                    ? _buildEmptyState()
                    : Column(
                  children: activities
                      .take(8)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) => _buildActivityRow(
                      context, entry.value,
                      isLast: entry.key ==
                          (activities.length > 8
                              ? 7
                              : activities.length - 1)))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      }

      Widget _buildActivityRow(BuildContext context, StravaActivity a,
          {required bool isLast}) {
        final dateStr = DateFormat('EEE, MMM d').format(a.date);
        final timeStr = DateFormat('h:mm a').format(a.date);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Orange dot + line
                  Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFC4C02),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Activity info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$dateStr · $timeStr',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Stat chips row
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _StatChip(
                              icon: Icons.straighten,
                              label:
                              '${a.distanceKm.toStringAsFixed(2)} km',
                              color: const Color(0xFFFC4C02),
                            ),
                            _StatChip(
                              icon: Icons.timer_outlined,
                              label: '${a.durationMin} min',
                              color: AppColors.primaryBlue,
                            ),
                            _StatChip(
                              icon: Icons.speed,
                              label: a.paceString,
                              color: const Color(0xFF2ECC71),
                            ),
                            if (a.elevationGain != null &&
                                a.elevationGain! > 0)
                              _StatChip(
                                icon: Icons.terrain,
                                label:
                                '↑ ${a.elevationGain!.toStringAsFixed(0)}m',
                                color: const Color(0xFF9B59B6),
                              ),
                            if (a.heartRateAvg != null)
                              _StatChip(
                                icon: Icons.favorite_outline,
                                label: '${a.heartRateAvg} bpm',
                                color: const Color(0xFFE74C3C),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(height: 1, color: AppColors.dividerColor),
          ],
        );
      }

      Widget _buildEmptyState() {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.directions_run,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No Strava runs found',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Log a run on Strava and tap Sync to see it here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    /// Small pill chip used inside each activity row
    class _StatChip extends StatelessWidget {
      final IconData icon;
      final String label;
      final Color color;

      const _StatChip(
          {required this.icon, required this.label, required this.color});

      @override
      Widget build(BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }
    }

    class StravaAnalysisCard extends StatelessWidget {
      const StravaAnalysisCard({super.key});

      @override
      Widget build(BuildContext context) {
        final appState = Provider.of<AppState>(context);
        if (!appState.stravaConnected) return const SizedBox.shrink();

        final analysis = appState.stravaAnalysis;
        final isLoading = appState.isLoadingStravaAnalysis;
        final rec = analysis?['recommendation'];

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: Colors.grey.shade200.withOpacity(0.8),
              blurRadius: 15, offset: const Offset(0, 6),
            )],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Strava Analysis',
                              style: GoogleFonts.poppins(fontSize: 16,
                                  fontWeight: FontWeight.w700, color: Colors.white)),
                          Text('Powered by Groq · Based on your Strava runs',
                              style: GoogleFonts.poppins(fontSize: 11,
                                  color: Colors.white.withOpacity(0.85))),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => appState.fetchStravaAnalysis(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Analyse',
                            style: GoogleFonts.poppins(fontSize: 12,
                                fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: isLoading
                    ? const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(color: Color(0xFF6A11CB)),
                ))
                    : rec == null
                    ? _buildPromptState(context, appState)
                    : _buildAnalysisResult(context, rec, analysis!),
              ),
            ],
          ),
        );
      }

      Widget _buildPromptState(BuildContext context, AppState appState) {
        return Column(
          children: [
            const Icon(Icons.insights, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 12),
            Text('Analyse your Strava runs',
                style: GoogleFonts.poppins(fontSize: 15,
                    fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text('Get AI coaching insights on every run you\'ve logged on Strava.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMedium)),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: () => appState.fetchStravaAnalysis(),
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
              borderRadius: 12,
              child: Text('Run AI Analysis',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }

      Widget _buildAnalysisResult(BuildContext context,
          Map<String, dynamic> rec, Map<String, dynamic>? analysis) {
        final perRunInsights = rec['perRunInsights'] as List? ?? [];
        final strengthPoints = rec['strengthPoints'] as List? ?? [];
        final improvementAreas = rec['improvementAreas'] as List? ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Readiness score + plan badge
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text('${rec['readinessScore'] ?? "--"}',
                            style: GoogleFonts.poppins(fontSize: 36,
                                fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('Readiness Score',
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: Colors.white.withOpacity(0.85))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFC4C02).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFC4C02).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('${rec['recommendedPlan'] ?? "--"}',
                            style: GoogleFonts.poppins(fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFC4C02))),
                        Text('${rec['planTier'] ?? ""}',
                            style: GoogleFonts.poppins(fontSize: 11,
                                color: AppColors.textMedium)),
                        Text('Recommended Plan',
                            style: GoogleFonts.poppins(fontSize: 10,
                                color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reasoning
            if (rec['reasoning'] != null) ...[
              Text('"${rec['reasoning']}"',
                  style: GoogleFonts.poppins(fontSize: 13,
                      fontStyle: FontStyle.italic, color: AppColors.textMedium,
                      height: 1.5)),
              const SizedBox(height: 16),
            ],

            // Weekly structure
            if (rec['weeklyStructure'] != null) ...[
              _sectionHeader('📅 Suggested Weekly Structure'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
                ),
                child: Text(rec['weeklyStructure'],
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDark,
                        height: 1.5)),
              ),
              const SizedBox(height: 16),
            ],

            // Per-run insights
            if (perRunInsights.isNotEmpty) ...[
              _sectionHeader('🏃 Per-Run Coaching Tips'),
              const SizedBox(height: 8),
              ...perRunInsights.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.chevron_right,
                        color: Color(0xFFFC4C02), size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['runName'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 12,
                                fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        Text(r['insight'] ?? '',
                            style: GoogleFonts.poppins(fontSize: 12,
                                color: AppColors.textMedium, height: 1.4)),
                      ],
                    )),
                  ],
                ),
              )),
              const SizedBox(height: 8),
            ],

            // Strengths + improvements
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPointsList(
                    '💪 Strengths', strengthPoints, const Color(0xFF2ECC71))),
                const SizedBox(width: 12),
                Expanded(child: _buildPointsList(
                    '📈 Improve', improvementAreas, const Color(0xFFE6783A))),
              ],
            ),
            const SizedBox(height: 16),

            // Next step tip
            if (rec['nextStepTip'] != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(rec['nextStepTip'],
                        style: GoogleFonts.poppins(fontSize: 13,
                            color: Colors.white, height: 1.4))),
                  ],
                ),
              ),
          ],
        );
      }

      Widget _sectionHeader(String title) => Text(title,
          style: GoogleFonts.poppins(fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.textDark));

      Widget _buildPointsList(String title, List items, Color color) {
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
              Text(title, style: GoogleFonts.poppins(fontSize: 12,
                  fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 8),
              ...items.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $p', style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textDark, height: 1.4)),
              )),
            ],
          ),
        );
      }
    }

    class _StravaSourceBadge extends StatelessWidget {
      const _StravaSourceBadge();

      @override
      Widget build(BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFC4C02).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFC4C02).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 3),
              Text(
                'Strava',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFC4C02),
                ),
              ),
            ],
          ),
        );
      }
    }

    void main() {
      runApp( AthleteDashboardApp());
    }