import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/auth_storage_service.dart';
import './AthleteDashboard.dart' show AppState, AppColors;
import '../models/strava_activites.dart';
import '../config/api_config.dart'; // adjust path as needed

// ── Platform gradient (matches AthleteDashboard glossyGradient) ──────────────
const _kGradient = LinearGradient(
  colors: [Color(0xFF1976D2), Color(0xFFE6783A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Tinted icon background used on stat cards & activity cards
BoxDecoration _tintedBox({double radius = 10}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: const LinearGradient(
    colors: [Color(0x1A1976D2), Color(0x1AE6783A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
);

class StravaPage extends StatefulWidget {
  const StravaPage({super.key});

  @override
  State<StravaPage> createState() => _StravaPageState();
}

class _StravaPageState extends State<StravaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.stravaConnected) {
        appState.fetchStravaActivities();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _connectStrava(BuildContext context, AppState appState) async {
    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'];
    final url =
    Uri.parse('${ApiConfig.baseUrl}/api/strava/connect?token=$token');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      await Future.delayed(const Duration(seconds: 2));
      await appState.checkStravaStatus();
    }
  }

  Future<void> _disconnectStrava(BuildContext context, AppState appState) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog( // 👈 Use dialogContext, not context
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Disconnect Strava?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            'Your Strava activities will no longer sync to PeakForm.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), // 👈 dialogContext
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),  // 👈 dialogContext
            child: Text('Disconnect',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];

      if (token == null || token.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auth error — please log in again')),
          );
        }
        return;
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/strava/disconnect'),
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('Disconnect status: ${response.statusCode}');
      debugPrint('Disconnect body: ${response.body}');

      if (!context.mounted) return; // 👈 Always check after async gaps

      if (response.statusCode == 200) {
        await appState.checkStravaStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Strava disconnected'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${response.statusCode} — ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final connected = appState.stravaConnected;
    final activities = appState.stravaActivities;
    final isLoading = appState.isLoadingStrava;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF2C3E50), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Gradient icon badge — matches platform style
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_run,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Strava',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C3E50))),
          ],
        ),
        actions: [
          if (connected)
            TextButton.icon(
              onPressed: () => _disconnectStrava(context, appState),
              icon: const Icon(Icons.link_off, color: Colors.red, size: 16),
              label: Text('Disconnect',
                  style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: connected
          ? _buildConnectedBody(context, appState, activities, isLoading)
          : _buildNotConnectedBody(context, appState),
    );
  }

  // ── NOT CONNECTED ──────────────────────────────────────────────────────────
  Widget _buildNotConnectedBody(BuildContext context, AppState appState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gradient-tinted circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0x1A1976D2), Color(0x1AE6783A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.directions_run,
                  color: Color(0xFF1976D2), size: 52),
            ),
            const SizedBox(height: 28),
            Text('Connect to Strava',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2C3E50))),
            const SizedBox(height: 12),
            Text(
              'Sync your runs automatically. Your Strava activities will appear here and be used for AI coaching analysis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF7F8C8D), height: 1.6),
            ),
            const SizedBox(height: 32),
            _buildBenefitRow(Icons.sync, 'Auto-sync all your Strava runs'),
            const SizedBox(height: 12),
            // Gradient connect button
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _kGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: () => _connectStrava(context, appState),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Connect to your strava account',
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: _tintedBox(radius: 8),
          child: Icon(icon, color: const Color(0xFF1976D2), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF2C3E50))),
        ),
      ],
    );
  }

  // ── CONNECTED ──────────────────────────────────────────────────────────────
  Widget _buildConnectedBody(BuildContext context, AppState appState,
      List<StravaActivity> activities, bool isLoading) {
    final totalKm = activities.fold<double>(0, (s, a) => s + a.distanceKm);
    final totalRuns = activities.length;
    final validActivities =
    activities.where((a) => a.distanceKm > 0 && a.durationMin > 0).toList();
    final avgPace = validActivities.isNotEmpty
        ? validActivities
        .map((a) => a.durationMin / a.distanceKm)
        .fold<double>(0, (s, p) => s + p) /
        validActivities.length
        : 0.0;

    final avgPaceStr = avgPace > 0
        ? '${avgPace.truncate()}:${((avgPace % 1) * 60).round().toString().padLeft(2, '0')}'
        : '--:--';

    return Column(
      children: [
        // ── Status Banner ────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: _kGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Strava Connected',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text('Activities syncing automatically',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => appState.fetchStravaActivities(),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Sync',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Stats Row ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatCard('Total Runs', '$totalRuns',
                  Icons.directions_run, const Color(0xFF1976D2)),
              const SizedBox(width: 10),
              _buildStatCard('Total km', totalKm.toStringAsFixed(1),
                  Icons.straighten, const Color(0xFFE6783A)),
              const SizedBox(width: 10),
              _buildStatCard('Avg Pace', '$avgPaceStr /km',
                  Icons.speed, const Color(0xFF1976D2)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Tab Bar ──────────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: _kGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF7F8C8D),
            labelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
            tabs: const [
              Tab(text: 'Activities'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Tab Views ────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActivitiesTab(activities, isLoading, appState),
              _buildStatsTab(activities),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: _tintedBox(radius: 8),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2C3E50))),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: const Color(0xFF7F8C8D))),
          ],
        ),
      ),
    );
  }

  // ── Activities Tab ─────────────────────────────────────────────────────────
  Widget _buildActivitiesTab(
      List<StravaActivity> activities, bool isLoading, AppState appState) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1976D2)),
        ),
      );
    }
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_run, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No runs synced yet',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7F8C8D))),
            const SizedBox(height: 8),
            Text('Log a run on Strava and tap Sync',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFFBDC3C7))),
            const SizedBox(height: 24),
            // Gradient sync button
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: _kGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: OutlinedButton.icon(
                onPressed: () => appState.fetchStravaActivities(),
                icon: const Icon(Icons.sync, color: Colors.white, size: 16),
                label: Text('Sync Now',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: activities.length,
      itemBuilder: (context, i) => _buildActivityCard(activities[i]),
    );
  }

  Widget _buildActivityCard(StravaActivity a) {
    final dateStr = DateFormat('EEE, MMM d · h:mm a').format(a.date);
    final hour = a.date.hour;
    IconData timeIcon;
    if (hour >= 4 && hour < 10) {
      timeIcon = Icons.wb_sunny_outlined;
    } else if (hour >= 10 && hour < 15) {
      timeIcon = Icons.wb_sunny;
    } else if (hour >= 15 && hour < 19) {
      timeIcon = Icons.wb_twilight;
    } else {
      timeIcon = Icons.nightlight_round;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Gradient-tinted icon box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: _tintedBox(radius: 10),
                child:
                Icon(timeIcon, color: const Color(0xFF1976D2), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2C3E50))),
                    Text(dateStr,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF7F8C8D))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniStat('${a.distanceKm.toStringAsFixed(2)} km',
                  Icons.straighten, const Color(0xFFE6783A)),
              _miniStat('${a.durationMin} min',
                  Icons.timer_outlined, const Color(0xFF1976D2)),
              _miniStat(a.paceString, Icons.speed, const Color(0xFF2ECC71)),
              if (a.elevationGain != null && a.elevationGain! > 0)
                _miniStat('↑${a.elevationGain!.toStringAsFixed(0)}m',
                    Icons.terrain, const Color(0xFF9B59B6)),
              if (a.heartRateAvg != null)
                _miniStat('${a.heartRateAvg} bpm',
                    Icons.favorite_outline, const Color(0xFFE74C3C)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2C3E50)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── Stats Tab ──────────────────────────────────────────────────────────────
  Widget _buildStatsTab(List<StravaActivity> activities) {
    if (activities.isEmpty) {
      return Center(
        child: Text('No data yet — sync your Strava runs',
            style: GoogleFonts.poppins(color: const Color(0xFF7F8C8D))),
      );
    }

    final longestRun =
    activities.map((a) => a.distanceKm).reduce((a, b) => a > b ? a : b);
    final fastestPace = activities
        .where((a) => a.distanceKm > 0 && a.durationMin > 0)
        .map((a) => a.durationMin / a.distanceKm)
        .reduce((a, b) => a < b ? a : b);
    final fastestStr =
        '${fastestPace.truncate()}:${((fastestPace % 1) * 60).round().toString().padLeft(2, '0')} /km';

    final monday = DateTime.now()
        .subtract(Duration(days: DateTime.now().weekday - 1));
    final weekRuns = activities.where((a) => a.date.isAfter(monday)).toList();
    final weekKm = weekRuns.fold<double>(0, (s, a) => s + a.distanceKm);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _statsCard('This Week', [
            _statRow('Runs', '${weekRuns.length}', Icons.directions_run),
            _statRow('Distance', '${weekKm.toStringAsFixed(1)} km',
                Icons.straighten),
          ]),
          const SizedBox(height: 12),
          _statsCard('All Time', [
            _statRow('Longest Run', '${longestRun.toStringAsFixed(2)} km',
                Icons.emoji_events),
            _statRow('Fastest Pace', fastestStr, Icons.bolt),
            _statRow('Total Runs', '${activities.length}',
                Icons.directions_run),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statsCard(String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient accent bar on section title
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: _kGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C3E50))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Gradient icon tint
          Container(
            padding: const EdgeInsets.all(6),
            decoration: _tintedBox(radius: 7),
            child: Icon(icon, color: const Color(0xFF1976D2), size: 14),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: const Color(0xFF7F8C8D))),
          const Spacer(),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C3E50))),
        ],
      ),
    );
  }
}