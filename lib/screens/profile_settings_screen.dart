import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_storage_service.dart';
import '../config/api_config.dart';
import './landing_screen.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const Color kBlue = Color(0xFF2575FC);
const Color kOrange = Color(0xFFF7941D);
const Color kSurface = Color(0xFFF7F8FC);
const Color kBorder = Color(0xFFE4E7EF);
const Color kText = Color(0xFF0F1117);
const Color kMuted = Color(0xFF8B90A0);
const Color kWhite = Color(0xFFFFFFFF);
const Color kSuccess = Color(0xFF1D9E75);
const Color kError = Color(0xFFE24B4A);

const LinearGradient kGrad = LinearGradient(
  colors: [kBlue, kOrange],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ─── User Data Model (populated from API) ────────────────────────────────────
class UserData {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String country;
  final String role;
  final String experienceLevel;
  final String weeklyMileage;
  final String runningGoals;
  final String bio;
  final int height;
  final int weight;
  final DateTime? dateOfBirth;
  final String gender;
  final String plan;
  final String? stravaId;
  final CoachData? coach;
  final String certifications;
  final int coachingExperienceYears;
  final List<String> specializations;

  const UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.country,
    required this.role,
    required this.experienceLevel,
    required this.weeklyMileage,
    required this.runningGoals,
    required this.bio,
    required this.height,
    required this.weight,
    this.dateOfBirth,
    required this.gender,
    required this.plan,
    this.stravaId,
    this.coach,
    this.certifications = '',
    this.coachingExperienceYears = 0,
    this.specializations = const [],
  });

  /// Construct from your API JSON response
  factory UserData.fromJson(Map<String, dynamic> json) {
    List<String> parseSpecializations(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) return raw.isEmpty ? [] : [raw];
      return [];
    }

    return UserData(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      role: json['role']?.toString() ?? 'athlete',
      experienceLevel: json['experienceLevel']?.toString() ?? 'beginner',
      weeklyMileage: json['weeklyMileage']?.toString() ?? '0-10',
      runningGoals: json['runningGoals']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      height: (json['height'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'].toString())
          : null,
      gender: json['gender']?.toString() ?? '',
      plan: json['plan']?.toString() ?? '',
      stravaId: json['stravaId']?.toString(),
      coach: json['coach'] != null ? CoachData.fromJson(json['coach']) : null,
      certifications: json['certifications']?.toString() ?? '',
      coachingExperienceYears:
      (json['coachingExperienceYears'] as num?)?.toInt() ?? 0,
      specializations: parseSpecializations(json['specializations']),
    );
  }
}

class CoachData {
  final String id;
  final String name;
  final String email;

  const CoachData({required this.id, required this.name, required this.email});

  factory CoachData.fromJson(Map<String, dynamic> json) => CoachData(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'] ?? '',
  );
}

// ─── Editable Profile Model ───────────────────────────────────────────────────
class ProfileModel {
  String firstName;
  String lastName;
  String email;
  String phoneCode;
  String phone;
  String city;
  String country;
  String height;
  String heightUnit;
  String weight;
  String weightUnit;
  DateTime? dob;
  String experience;
  String weeklyMileage;
  String goals;
  String distanceUnit;
  String timezone;
  String gender;
  String currentPassword;
  String newPassword;
  String confirmPassword;
  String bio;
  String certifications;
  int coachingExperienceYears;
  List<String> specializations;

  ProfileModel({
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phoneCode = '+91',
    this.phone = '',
    this.city = '',
    this.country = '',
    this.height = '',
    this.heightUnit = 'cm',
    this.weight = '',
    this.weightUnit = 'kg',
    this.dob,
    this.experience = 'beginner',
    this.weeklyMileage = '0-10',
    this.goals = '',
    this.distanceUnit = 'km',
    this.timezone = 'Asia/Kolkata',
    this.gender = 'male',
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.bio = '',
    this.certifications = '',
    this.coachingExperienceYears = 0,
    this.specializations = const [],
  });

  /// Initialize from API UserData
  factory ProfileModel.fromUserData(UserData user) {
    final nameParts = user.name.split(' ');
    final phoneRaw = user.phone.replaceAll(' ', '');
    String code = '+91';
    String number = phoneRaw;
    for (final c in ['+1', '+44', '+61', '+91']) {
      if (phoneRaw.startsWith(c)) {
        code = c;
        number = phoneRaw.substring(c.length);
        break;
      }
    }
    return ProfileModel(
      firstName: nameParts.isNotEmpty ? nameParts.first : '',
      lastName: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
      email: user.email,
      phoneCode: code,
      phone: number,
      city: user.city,
      country: user.country,
      height: user.height > 0 ? user.height.toString() : '',
      weight: user.weight > 0 ? user.weight.toString() : '',
      dob: user.dateOfBirth,
      experience: user.experienceLevel,
      weeklyMileage: user.weeklyMileage,
      goals: user.runningGoals,
      gender: user.gender,
      timezone: user.country == 'India' ? 'Asia/Kolkata' : 'America/New_York',
      bio: user.bio,
      certifications: user.certifications,
      coachingExperienceYears: user.coachingExperienceYears,
      specializations: List<String>.from(user.specializations), // explicit copy
    );
  }

  ProfileModel copy() => ProfileModel(
    firstName: firstName,
    lastName: lastName,
    email: email,
    phoneCode: phoneCode,
    phone: phone,
    city: city,
    country: country,
    height: height,
    heightUnit: heightUnit,
    weight: weight,
    weightUnit: weightUnit,
    dob: dob,
    experience: experience,
    weeklyMileage: weeklyMileage,
    goals: goals,
    distanceUnit: distanceUnit,
    timezone: timezone,
    gender: gender,
    bio: bio,
    certifications: certifications,
    coachingExperienceYears: coachingExperienceYears,
    specializations: List.from(specializations),
  );
}

// ─── Shared helpers ──────────────────────────────────────────────────────────
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (b) =>
        kGrad.createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
    child: Text(text, style: style.copyWith(color: Colors.white)),
  );
}

class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool loading;
  final bool small;
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.small = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null && !widget.loading;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: widget.small
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 9)
              : const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            gradient: disabled ? null : kGrad,
            color: disabled ? kBorder : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      color: Colors.white, size: widget.small ? 15 : 17),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: disabled ? kMuted : Colors.white,
                    fontSize: widget.small ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class ProfileSettingsScreen extends StatefulWidget {
  /// Pass the decoded JSON map from your API response here
  final Map<String, dynamic> userJson;
  final bool isCoach;

  const ProfileSettingsScreen({
    super.key,
    required this.userJson,
    this.isCoach = false,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ProfileModel _profile;
  late ProfileModel _original;
  late UserData _userData;
  bool _saving = false;
  bool _savingPass = false;

  // Tabs: Personal, Fitness, Metrics, Security (no Alerts)
  List<Map<String, String>> get _tabDefs => widget.isCoach
      ? [
    {'id': 'profile',   'label': 'Profile'},
    {'id': 'coaching',  'label': 'Coaching'},
    {'id': 'security',  'label': 'Security'},
  ]
      : [
    {'id': 'personal',  'label': 'Personal'},
    {'id': 'fitness',   'label': 'Fitness'},
    {'id': 'metrics',   'label': 'Metrics'},
    {'id': 'security',  'label': 'Security'},
  ];

  bool get _isDirty => _hasChanges();

  bool _hasChanges() {
    final o = _original;
    final p = _profile;
    return p.firstName != o.firstName ||
        p.lastName != o.lastName ||
        p.email != o.email ||
        p.phone != o.phone ||
        p.phoneCode != o.phoneCode ||
        p.city != o.city ||
        p.country != o.country ||
        p.height != o.height ||
        p.heightUnit != o.heightUnit ||
        p.weight != o.weight ||
        p.weightUnit != o.weightUnit ||
        p.dob != o.dob ||
        p.experience != o.experience ||
        p.weeklyMileage != o.weeklyMileage ||
        p.goals != o.goals ||
        p.distanceUnit != o.distanceUnit ||
        p.timezone != o.timezone ||
        p.gender != o.gender;
        p.bio != o.bio ||
        p.certifications != o.certifications ||
        p.coachingExperienceYears != o.coachingExperienceYears || !_listEquals(p.specializations, o.specializations);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _userData = UserData.fromJson(widget.userJson);
    _profile = ProfileModel.fromUserData(_userData);
    _original = _profile.copy();
    _tabs = TabController(
      length: widget.isCoach ? 3 : 4,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() {});

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];

      final Map<String, dynamic> payload = {
        'name': '${_profile.firstName} ${_profile.lastName}'.trim(),
        'email': _profile.email,
        'phoneNumber': '${_profile.phoneCode} ${_profile.phone}',
        'city': _profile.city,
        'country': _profile.country,
        'height': _profile.height,
        'weight': _profile.weight,
        'gender': _profile.gender,
        'experienceLevel': _profile.experience,
        'weeklyMileage': _profile.weeklyMileage,
        'runningGoals': _profile.goals,
        if (_profile.dob != null)
          'dateOfBirth':
          '${_profile.dob!.year}-${_profile.dob!.month.toString().padLeft(2, '0')}-${_profile.dob!.day.toString().padLeft(2, '0')}',
        if (widget.isCoach) 'bio': _profile.bio,
        if (widget.isCoach) 'certifications': _profile.certifications,
        if (widget.isCoach) 'coachingExperienceYears': _profile.coachingExperienceYears,
        if (widget.isCoach) 'specializations': _profile.specializations,
      };

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/me'), // ← see note below
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        setState(() {
          _saving = false;
          _original = _profile.copy();
        });
        _showSnack('Profile saved successfully', isSuccess: true);
      } else {
        setState(() => _saving = false);
        _showSnack('Failed to save profile (${response.statusCode})', isError: true);
      }
    } catch (e) {
      setState(() => _saving = false);
      _showSnack('Error saving profile: $e', isError: true);
    }
  }

  void _discard() {
    setState(() => _profile = _original.copy());
    _showSnack('Changes discarded');
  }

  Future<void> _changePassword() async {
    if (_profile.currentPassword.isEmpty ||
        _profile.newPassword.isEmpty ||
        _profile.confirmPassword.isEmpty) {
      _showSnack('Please fill all password fields', isError: true);
      return;
    }
    if (_profile.newPassword != _profile.confirmPassword) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }

    setState(() => _savingPass = true);

    try {
      final authData = await AuthStorageService.getAuthData();
      final token = authData['authToken'];

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/users/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': _profile.currentPassword,
          'newPassword': _profile.newPassword,
        }),
      );

      setState(() => _savingPass = false);

      if (response.statusCode == 200) {
        setState(() {
          _profile.currentPassword = '';
          _profile.newPassword = '';
          _profile.confirmPassword = '';
        });
        _showSnack('Password updated successfully', isSuccess: true);
      } else {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'Failed to update password', isError: true);
      }
    } catch (e) {
      setState(() => _savingPass = false);
      _showSnack('Error updating password: $e', isError: true);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.w700, color: kText)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: kMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await AuthStorageService.clearAuthData();
    if (!mounted) return;

    // Use the ROOT navigator to blow away the entire stack
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingScreen()),
          (route) => false,
    );
  }


  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError
            ? kError
            : isSuccess
            ? kSuccess
            : kText,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String get _displayName {
    final n = '${_profile.firstName} ${_profile.lastName}'.trim();
    print(_profile);
    print(_userData);
    return n.isEmpty ? _userData.name : n;
  }

  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: kSurface,
      ),
      child: Scaffold(
        backgroundColor: kSurface,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildAvatarSection(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: widget.isCoach
                      ? [
                    _buildCoachProfileTab(),
                    _buildCoachingTab(),
                    _buildSecurityTab(),
                  ]
                      : [
                    _buildPersonalTab(),
                    _buildFitnessTab(),
                    _buildMetricsTab(),
                    _buildSecurityTab(),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoachProfileTab() => _TabScroll(children: [
    _SectionHeader(icon: Icons.person_outline_rounded, label: 'Personal Information'),
    _FieldRow(children: [
      _Field(
        label: 'First name',
        icon: Icons.badge_outlined,
        child: _TextInput(
          value: _profile.firstName,
          hint: 'First name',
          onChanged: (v) { _profile.firstName = v; _markDirty(); },
        ),
      ),
      _Field(
        label: 'Last name',
        child: _TextInput(
          value: _profile.lastName,
          hint: 'Last name',
          onChanged: (v) { _profile.lastName = v; _markDirty(); },
        ),
      ),
    ]),
    _Field(
      label: 'Email address',
      icon: Icons.mail_outline_rounded,
      child: _TextInput(
        value: _profile.email,
        hint: 'you@example.com',
        keyboard: TextInputType.emailAddress,
        onChanged: (v) { _profile.email = v; _markDirty(); },
      ),
    ),
    _Field(
      label: 'Mobile number',
      icon: Icons.phone_outlined,
      child: _PhoneInput(
        code: _profile.phoneCode,
        number: _profile.phone,
        onCodeChanged: (v) { _profile.phoneCode = v; _markDirty(); },
        onNumberChanged: (v) { _profile.phone = v; _markDirty(); },
      ),
    ),
    _FieldRow(children: [
      _Field(
        label: 'City',
        icon: Icons.location_city_outlined,
        child: _TextInput(
          value: _profile.city,
          hint: 'City',
          onChanged: (v) { _profile.city = v; _markDirty(); },
        ),
      ),
      _Field(
        label: 'Country',
        icon: Icons.public_outlined,
        child: _TextInput(
          value: _profile.country,
          hint: 'Country',
          onChanged: (v) { _profile.country = v; _markDirty(); },
        ),
      ),
    ]),
    _Field(
      label: 'Bio',
      icon: Icons.info_outline_rounded,
      child: _TextArea(
        value: _profile.bio,
        hint: 'Tell athletes about yourself...',
        onChanged: (v) { _profile.bio = v; _markDirty(); },
      ),
    ),
  ]);

  Widget _buildCoachingTab() => _TabScroll(children: [
    _SectionHeader(icon: Icons.sports_rounded, label: 'Coaching Details'),
    _Field(
      label: 'Certifications',
      icon: Icons.workspace_premium_outlined,
      child: _TextInput(
        value: _profile.certifications,
        hint: 'e.g. Certified TCS Runner',
        onChanged: (v) { _profile.certifications = v; _markDirty(); },
      ),
    ),
    _Field(
      label: 'Years of coaching experience',
      icon: Icons.timer_outlined,
      child: _TextInput(
        value: _profile.coachingExperienceYears > 0
            ? _profile.coachingExperienceYears.toString()
            : '',
        hint: 'e.g. 7',
        keyboard: TextInputType.number,
        onChanged: (v) {
          _profile.coachingExperienceYears = int.tryParse(v) ?? 0;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Specializations',
      icon: Icons.directions_run_rounded,
      child: _ChipGroup(
        options: const [
          {'value': '5km',           'label': '5km'},
          {'value': '10km',          'label': '10km'},
          {'value': 'Half Marathon', 'label': 'Half Marathon'},
          {'value': 'Marathon',      'label': 'Marathon'},
          {'value': '50km',          'label': '50km'},
          {'value': 'Ultra',         'label': 'Ultra'},
        ],
        // Multi-select: toggle in the list
        selected: _profile.specializations.isNotEmpty
            ? _profile.specializations.first
            : '',
        onChanged: (v) {
          final list = List<String>.from(_profile.specializations);
          list.contains(v) ? list.remove(v) : list.add(v);
          _profile.specializations = list;
          _markDirty();
        },
        selectedMultiple: _profile.specializations,
      ),
    ),
  ]);

  // ── APP BAR ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() => Container(
    color: kWhite,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: kText,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile Settings',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: kText)),
              const Text('Manage your account & preferences',
                  style: TextStyle(fontSize: 12, color: kMuted)),
            ],
          ),
        ),
        // Show athlete ID as badge
        _PillBadge(
          label: _userData.id,
          color: kBlue.withOpacity(0.08),
          textColor: kBlue,
        ),
        GestureDetector(
          onTap: _logout,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: kError.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kError.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.logout_rounded, size: 14, color: kError),
                SizedBox(width: 5),
                Text('Logout',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kError)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ── AVATAR ────────────────────────────────────────────────────────────────
  Widget _buildAvatarSection() => Container(
    color: kWhite,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Row(
      children: [
        // Avatar with gradient ring
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGrad,
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE6F1FB),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kBlue),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () =>
                    _showSnack('Photo upload — connect image_picker'),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: kGrad,
                    shape: BoxShape.circle,
                    border: Border.all(color: kWhite, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isCoach
                    ? '${_profile.coachingExperienceYears > 0 ? "${_profile.coachingExperienceYears} yrs exp" : "Coach"} · ${_userData.city.isNotEmpty ? _userData.city : "Location not set"}'
                    : '${_experienceLabel(_profile.experience)} · ${_userData.city}',
                style: const TextStyle(
                  fontSize: 12,
                  color: kMuted,
                ),
              ),
              const SizedBox(height: 4),
              // Plan badge
              Row(
                children: [
                  if (widget.isCoach) ...[
                    if (_userData.specializations.isNotEmpty)
                      _PillBadge(
                        label: _userData.specializations.take(2).join(', '),
                        color: kOrange.withOpacity(0.1),
                        textColor: kOrange,
                        icon: Icons.sports_rounded,
                      ),
                  ] else ...[
                    _PillBadge(
                      label: '${_userData.plan} Plan',
                      color: kOrange.withOpacity(0.1),
                      textColor: kOrange,
                      icon: Icons.directions_run_rounded,
                    ),
                    if (_userData.coach != null) ...[
                      const SizedBox(width: 6),
                      _PillBadge(
                        label: _userData.coach!.name.split(' ').first,
                        color: kBlue.withOpacity(0.08),
                        textColor: kBlue,
                        icon: Icons.sports_rounded,
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  String _experienceLabel(String v) {
    const map = {
      'beginner': 'Beginner',
      'intermediate': 'Intermediate',
      'advanced': 'Advanced',
      'expert': 'Expert',
    };
    return map[v] ?? v;
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: kWhite,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: TabBar(
        controller: _tabs,
        isScrollable: true,
        padding: const EdgeInsets.all(3),
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: kGrad,
          borderRadius: BorderRadius.circular(7),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: kMuted,
        labelStyle:
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        tabs: _tabDefs.map((t) => Tab(text: t['label'])).toList(),
      ),
    ),
  );

  // ── PERSONAL TAB ─────────────────────────────────────────────────────────
  Widget _buildPersonalTab() => _TabScroll(children: [
    _SectionHeader(
        icon: Icons.person_outline_rounded, label: 'Personal Information'),
    _FieldRow(children: [
      _Field(
        label: 'First name',
        icon: Icons.badge_outlined,
        child: _TextInput(
          value: _profile.firstName,
          hint: 'First name',
          onChanged: (v) {
            _profile.firstName = v;
            _markDirty();
          },
        ),
      ),
      _Field(
        label: 'Last name',
        child: _TextInput(
          value: _profile.lastName,
          hint: 'Last name',
          onChanged: (v) {
            _profile.lastName = v;
            _markDirty();
          },
        ),
      ),
    ]),
    _Field(
      label: 'Email address',
      icon: Icons.mail_outline_rounded,
      child: _TextInput(
        value: _profile.email,
        hint: 'you@example.com',
        keyboard: TextInputType.emailAddress,
        onChanged: (v) {
          _profile.email = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Mobile number',
      icon: Icons.phone_outlined,
      child: _PhoneInput(
        code: _profile.phoneCode,
        number: _profile.phone,
        onCodeChanged: (v) {
          _profile.phoneCode = v;
          _markDirty();
        },
        onNumberChanged: (v) {
          _profile.phone = v;
          _markDirty();
        },
      ),
    ),
    _FieldRow(children: [
      _Field(
        label: 'City',
        icon: Icons.location_city_outlined,
        child: _TextInput(
          value: _profile.city,
          hint: 'City',
          onChanged: (v) {
            _profile.city = v;
            _markDirty();
          },
        ),
      ),
      _Field(
        label: 'Country',
        icon: Icons.public_outlined,
        child: _TextInput(
          value: _profile.country,
          hint: 'Country',
          onChanged: (v) {
            _profile.country = v;
            _markDirty();
          },
        ),
      ),
    ]),
    _Field(
      label: 'Running goals',
      icon: Icons.flag_outlined,
      child: _TextArea(
        value: _profile.goals,
        hint: 'e.g. Run a sub-4hr marathon, stay injury-free...',
        onChanged: (v) {
          _profile.goals = v;
          _markDirty();
        },
      ),
    ),
    // Coach info card (read-only)
    if (_userData.coach != null) _buildCoachCard(),
  ]);

  Widget _buildCoachCard() => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kBlue.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBlue.withOpacity(0.12)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: kGrad,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _userData.coach!.name.isNotEmpty
                ? _userData.coach!.name[0].toUpperCase()
                : 'C',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Coach',
                  style: TextStyle(
                      fontSize: 11,
                      color: kMuted,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(_userData.coach!.name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kText)),
              Text(_userData.coach!.email,
                  style:
                  const TextStyle(fontSize: 11, color: kMuted)),
            ],
          ),
        ),
        const Icon(Icons.sports_rounded, color: kBlue, size: 18),
      ],
    ),
  );

  // ── FITNESS TAB ───────────────────────────────────────────────────────────
  Widget _buildFitnessTab() => _TabScroll(children: [
    _SectionHeader(
        icon: Icons.fitness_center_outlined, label: 'Fitness Profile'),
    _FieldRow(children: [
      _Field(
        label: 'Height',
        icon: Icons.height_rounded,
        child: _UnitInput(
          value: _profile.height,
          unit: _profile.heightUnit,
          units: const ['cm', 'ft'],
          onValueChanged: (v) {
            _profile.height = v;
            _markDirty();
          },
          onUnitChanged: (v) {
            _profile.heightUnit = v;
            _markDirty();
          },
        ),
      ),
      _Field(
        label: 'Weight',
        icon: Icons.monitor_weight_outlined,
        child: _UnitInput(
          value: _profile.weight,
          unit: _profile.weightUnit,
          units: const ['kg', 'lbs'],
          onValueChanged: (v) {
            _profile.weight = v;
            _markDirty();
          },
          onUnitChanged: (v) {
            _profile.weightUnit = v;
            _markDirty();
          },
        ),
      ),
    ]),
    _Field(
      label: 'Date of birth',
      icon: Icons.cake_outlined,
      child: _DateInput(
        value: _profile.dob,
        onChanged: (v) {
          _profile.dob = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Gender',
      icon: Icons.person_outline_rounded,
      child: _ChipGroup(
        options: const [
          {'value': 'male', 'label': 'Male'},
          {'value': 'female', 'label': 'Female'},
          {'value': 'other', 'label': 'Other'},
        ],
        selected: _profile.gender,
        onChanged: (v) {
          _profile.gender = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Experience level',
      icon: Icons.military_tech_outlined,
      child: _ChipGroup(
        options: const [
          {'value': 'beginner', 'label': 'Beginner'},
          {'value': 'intermediate', 'label': 'Intermediate'},
          {'value': 'advanced', 'label': 'Advanced'},
          {'value': 'expert', 'label': 'Expert'},
        ],
        selected: _profile.experience,
        onChanged: (v) {
          _profile.experience = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Weekly mileage',
      icon: Icons.route_outlined,
      child: _ChipGroup(
        options: const [
          {'value': '0-10', 'label': '0–10 km'},
          {'value': '10-20', 'label': '10–20 km'},
          {'value': '20-30', 'label': '20–30 km'},
          {'value': '30-40', 'label': '30–40 km'},
          {'value': '40+', 'label': '40+ km'},
        ],
        selected: _profile.weeklyMileage,
        onChanged: (v) {
          _profile.weeklyMileage = v;
          _markDirty();
        },
      ),
    ),
  ]);

  // ── METRICS TAB ───────────────────────────────────────────────────────────
  Widget _buildMetricsTab() => _TabScroll(children: [
    _SectionHeader(
        icon: Icons.tune_rounded, label: 'Display Preferences'),
    _Field(
      label: 'Distance unit',
      icon: Icons.straighten_rounded,
      child: _ChipGroup(
        options: const [
          {'value': 'km', 'label': 'Kilometers (km)'},
          {'value': 'miles', 'label': 'Miles'},
        ],
        selected: _profile.distanceUnit,
        onChanged: (v) {
          _profile.distanceUnit = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Timezone',
      icon: Icons.public_rounded,
      child: _DropdownInput(
        value: _profile.timezone,
        options: const [
          {
            'value': 'Asia/Kolkata',
            'label': 'Asia/Kolkata (IST +5:30)'
          },
          {
            'value': 'America/New_York',
            'label': 'America/New_York (EST -5)'
          },
          {'value': 'Europe/London', 'label': 'Europe/London (GMT +0)'},
          {
            'value': 'Australia/Sydney',
            'label': 'Australia/Sydney (AEST +11)'
          },
        ],
        onChanged: (v) {
          _profile.timezone = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Height unit',
      icon: Icons.height_rounded,
      child: _ChipGroup(
        options: const [
          {'value': 'cm', 'label': 'Centimeters'},
          {'value': 'ft', 'label': 'Feet / Inches'},
        ],
        selected: _profile.heightUnit,
        onChanged: (v) {
          _profile.heightUnit = v;
          _markDirty();
        },
      ),
    ),
    _Field(
      label: 'Weight unit',
      icon: Icons.monitor_weight_outlined,
      child: _ChipGroup(
        options: const [
          {'value': 'kg', 'label': 'Kilograms (kg)'},
          {'value': 'lbs', 'label': 'Pounds (lbs)'},
        ],
        selected: _profile.weightUnit,
        onChanged: (v) {
          _profile.weightUnit = v;
          _markDirty();
        },
      ),
    ),
  ]);

  // ── SECURITY TAB ─────────────────────────────────────────────────────────
  Widget _buildSecurityTab() => _TabScroll(children: [
    _SectionHeader(
        icon: Icons.lock_outline_rounded, label: 'Change Password'),
    _PasswordField(
      label: 'Current password',
      value: _profile.currentPassword,
      hint: 'Enter current password',
      onChanged: (v) => setState(() => _profile.currentPassword = v),
    ),
    _PasswordField(
      label: 'New password',
      value: _profile.newPassword,
      hint: 'Min 8 characters',
      showStrength: true,
      onChanged: (v) => setState(() => _profile.newPassword = v),
    ),
    _PasswordField(
      label: 'Confirm new password',
      value: _profile.confirmPassword,
      hint: 'Repeat new password',
      onChanged: (v) => setState(() => _profile.confirmPassword = v),
    ),
    const SizedBox(height: 8),
    GradientButton(
      label: _savingPass ? 'Updating…' : 'Update Password',
      icon: Icons.lock_reset_rounded,
      loading: _savingPass,
      onPressed: (!_savingPass &&
          _profile.currentPassword.isNotEmpty &&
          _profile.newPassword.isNotEmpty &&
          _profile.confirmPassword.isNotEmpty)
          ? _changePassword
          : null,
    ),
  ]);

  // ── BOTTOM BAR ───────────────────────────────────────────────────────────
  Widget _buildBottomBar() => Container(
    decoration: BoxDecoration(
      color: kWhite,
      border: Border(top: BorderSide(color: kBorder, width: 0.5)),
    ),
    padding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        if (_isDirty) ...[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: kOrange, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('Unsaved changes',
              style: TextStyle(
                  fontSize: 12,
                  color: kMuted,
                  fontWeight: FontWeight.w500)),
        ],
        const Spacer(),
        if (_isDirty)
          GestureDetector(
            onTap: _discard,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: const Text('Discard',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kMuted)),
            ),
          ),
        const SizedBox(width: 8),
        GradientButton(
          label: _saving ? 'Saving…' : 'Save Changes',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _isDirty && !_saving ? _save : null,

        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _PillBadge({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(icon, size: 17, color: kBlue),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kText,
                letterSpacing: 0.1)),
      ],
    ),
  );
}

class _TabScroll extends StatelessWidget {
  final List<Widget> children;
  const _TabScroll({required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children),
  );
}

class _FieldRow extends StatelessWidget {
  final List<Widget> children;
  const _FieldRow({required this.children});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children
        .expand(
            (w) => [Expanded(child: w), const SizedBox(width: 10)])
        .toList()
      ..removeLast(),
  );
}

class _Field extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget child;
  const _Field({required this.label, this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: kMuted),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kMuted,
                    letterSpacing: 0.1)),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

// ── Input decoration ──────────────────────────────────────────────────────────
final _inputDecoration = InputDecoration(
  isDense: true,
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  filled: true,
  fillColor: kWhite,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: const BorderSide(color: kBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: const BorderSide(color: kBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: const BorderSide(color: kBlue, width: 1.5),
  ),
);

class _TextInput extends StatefulWidget {
  final String value;
  final String hint;
  final TextInputType keyboard;
  final ValueChanged<String> onChanged;
  const _TextInput({
    required this.value,
    required this.hint,
    this.keyboard = TextInputType.text,
    required this.onChanged,
  });

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_TextInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _c.text != widget.value) {
      _c.text = widget.value;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _c,
    keyboardType: widget.keyboard,
    style: const TextStyle(fontSize: 14, color: kText),
    decoration:
    _inputDecoration.copyWith(hintText: widget.hint),
    onChanged: widget.onChanged,
  );
}

class _TextArea extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  const _TextArea(
      {required this.value,
        required this.hint,
        required this.onChanged});

  @override
  State<_TextArea> createState() => _TextAreaState();
}

class _TextAreaState extends State<_TextArea> {
  late TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _c,
    maxLines: 3,
    style:
    const TextStyle(fontSize: 14, color: kText, height: 1.5),
    decoration:
    _inputDecoration.copyWith(hintText: widget.hint),
    onChanged: widget.onChanged,
  );
}

class _PhoneInput extends StatelessWidget {
  final String code;
  final String number;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<String> onNumberChanged;
  const _PhoneInput({
    required this.code,
    required this.number,
    required this.onCodeChanged,
    required this.onNumberChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: code,
            onChanged: (v) => onCodeChanged(v!),
            style: const TextStyle(fontSize: 13, color: kText),
            items: const [
              DropdownMenuItem(
                  value: '+91', child: Text('🇮🇳 +91')),
              DropdownMenuItem(
                  value: '+1', child: Text('🇺🇸 +1')),
              DropdownMenuItem(
                  value: '+44', child: Text('🇬🇧 +44')),
              DropdownMenuItem(
                  value: '+61', child: Text('🇦🇺 +61')),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _TextInput(
          value: number,
          hint: 'Mobile number',
          keyboard: TextInputType.phone,
          onChanged: onNumberChanged,
        ),
      ),
    ],
  );
}

class _UnitInput extends StatelessWidget {
  final String value;
  final String unit;
  final List<String> units;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<String> onUnitChanged;
  const _UnitInput({
    required this.value,
    required this.unit,
    required this.units,
    required this.onValueChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _TextInput(
          value: value,
          hint: '0',
          keyboard: TextInputType.number,
          onChanged: onValueChanged,
        ),
      ),
      const SizedBox(width: 6),
      Container(
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: kBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: unit,
            onChanged: (v) => onUnitChanged(v!),
            style: const TextStyle(fontSize: 13, color: kText),
            items: units
                .map((u) =>
                DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
          ),
        ),
      ),
    ],
  );
}

class _DropdownInput extends StatelessWidget {
  final String value;
  final List<Map<String, String>> options;
  final ValueChanged<String> onChanged;
  const _DropdownInput(
      {required this.value,
        required this.options,
        required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: kBorder),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        style: const TextStyle(fontSize: 14, color: kText),
        onChanged: (v) => onChanged(v!),
        items: options
            .map((o) => DropdownMenuItem(
            value: o['value'], child: Text(o['label']!)))
            .toList(),
      ),
    ),
  );
}

class _DateInput extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _DateInput({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime(1990),
        firstDate: DateTime(1920),
        lastDate: DateTime.now(),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme:
            const ColorScheme.light(primary: kBlue),
          ),
          child: child!,
        ),
      );
      onChanged(picked);
    },
    child: AbsorbPointer(
      child: TextFormField(
        controller: TextEditingController(
          text: value != null
              ? '${value!.day.toString().padLeft(2, '0')} / ${value!.month.toString().padLeft(2, '0')} / ${value!.year}'
              : '',
        ),
        style: const TextStyle(fontSize: 14, color: kText),
        decoration: _inputDecoration.copyWith(
          hintText: 'DD / MM / YYYY',
          suffixIcon: const Icon(
              Icons.calendar_today_outlined,
              size: 17,
              color: kMuted),
        ),
      ),
    ),
  );
}

class _ChipGroup extends StatelessWidget {
  final List<Map<String, String>> options;
  final String selected;
  final List<String>? selectedMultiple;  // ADD
  final ValueChanged<String> onChanged;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.selectedMultiple,               // ADD
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: options.map((o) {
      // Multi-select mode if selectedMultiple provided
      final isSelected = selectedMultiple != null
          ? selectedMultiple!.contains(o['value'])
          : o['value'] == selected;
      return GestureDetector(
        onTap: () => onChanged(o['value']!),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected ? kGrad : null,
            color: isSelected ? null : kWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : kBorder,
            ),
          ),
          child: Text(
            o['label']!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : kMuted,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _PasswordField extends StatefulWidget {
  final String label;
  final String value;
  final String hint;
  final bool showStrength;
  final ValueChanged<String> onChanged;
  const _PasswordField({
    required this.label,
    required this.value,
    required this.hint,
    this.showStrength = false,
    required this.onChanged,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;
  late TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _strength {
    final pw = _c.text;
    double s = 0;
    if (pw.length >= 8) s += 0.25;
    if (pw.contains(RegExp(r'[A-Z]'))) s += 0.25;
    if (pw.contains(RegExp(r'[0-9]'))) s += 0.25;
    if (pw.contains(RegExp(r'[^A-Za-z0-9]'))) s += 0.25;
    return s;
  }

  Color get _strengthColor {
    final s = _strength;
    if (s <= 0.25) return kError;
    if (s <= 0.5) return const Color(0xFFEF9F27);
    if (s <= 0.75) return kBlue;
    return kSuccess;
  }

  @override
  Widget build(BuildContext context) => _Field(
    label: widget.label,
    icon: Icons.lock_outline_rounded,
    child: Column(
      children: [
        TextFormField(
          controller: _c,
          obscureText: _obscure,
          style: const TextStyle(fontSize: 14, color: kText),
          decoration: _inputDecoration.copyWith(
            hintText: widget.hint,
            suffixIcon: GestureDetector(
              onTap: () =>
                  setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: kMuted,
              ),
            ),
          ),
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
        ),
        if (widget.showStrength && _c.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _strength,
              backgroundColor: kBorder,
              valueColor:
              AlwaysStoppedAnimation<Color>(_strengthColor),
              minHeight: 3,
            ),
          ),
        ],
      ],
    ),
  );
}