// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'coach_selection_screen.dart';
import '../services/api_service.dart';
import '../providers/api_providers.dart';
import './landing_screen.dart';
import './sign_in_screen.dart';
import 'package:flutter/services.dart';


// --- Helper Data ---
const Map<String, List<String>> countryToCities = {
  "India": ["Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai", "Kolkata", "Pune", "Ahmedabad", "Jaipur", "Lucknow"],
  "United States": ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego"],
  "United Kingdom": ["London", "Birmingham", "Manchester", "Glasgow", "Liverpool", "Newcastle", "Leeds", "Sheffield"],
  "Canada": ["Toronto", "Montreal", "Vancouver", "Calgary", "Edmonton", "Ottawa", "Winnipeg", "Quebec City"],
  "Australia": ["Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide", "Gold Coast", "Newcastle", "Canberra"],
  "UAE": ["Dubai", "Abu Dhabi", "Sharjah", "Al Ain", "Ajman", "Ras Al Khaimah", "Fujairah", "Umm Al Quwain"],
  "Germany": ["Berlin", "Hamburg", "Munich", "Cologne", "Frankfurt", "Stuttgart", "Düsseldorf", "Dortmund"],
  "France": ["Paris", "Marseille", "Lyon", "Toulouse", "Nice", "Nantes", "Strasbourg", "Montpellier"],
};

const List<String> specializationOptions = [
  "5km", "10km", "Half Marathon", "Marathon", "Ultra Marathon", "Track & Field",
  "Trail Running", "Beginner Runners", "Elite Athletes",
];

final registerProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, payload) async {
  final apiService = ref.read(apiServiceProvider);
  try {
    final response = await apiService.registerUser(payload);
    return response;
  } catch (e) {
    throw Exception(e.toString());
  }
});

final coachesProvider = FutureProvider<List<dynamic>>((ref) async {
  await Future.delayed(const Duration(seconds: 1));
  return [
    {
      'id': 'coach-1',
      '_id': 'coach-1',
      'name': 'Coach Alex',
      'specializations': ['Marathon', 'Half Marathon', 'Elite Athletes'],
      'bio': 'Experienced marathon coach dedicated to optimizing your race performance.',
      'avatarUrl': 'https://randomuser.me/api/portraits/men/32.jpg',
      'pricing': {'5km': 5000, '10km': 9000, '21.1km': 15000, '42.2km': 25000, '50km': 30000}
    },
    {
      'id': 'coach-2',
      '_id': 'coach-2',
      'name': 'Coach Sarah',
      'specializations': ['5km', '10km', 'Beginner Runners', 'Trail Running'],
      'bio': 'Passionate about guiding new runners to discover their potential and love for running.',
      'avatarUrl': 'https://randomuser.me/api/portraits/women/44.jpg',
      'pricing': {'5km': 4000, '10km': 7000}
    },
    {
      'id': 'coach-3',
      '_id': 'coach-3',
      'name': 'Coach David',
      'specializations': ['Ultra Marathon', 'Trail Running'],
      'bio': 'Pushing boundaries in ultra-marathons. Let me help you conquer extreme distances.',
      'avatarUrl': 'https://randomuser.me/api/portraits/men/29.jpg',
      'pricing': {'21.1km': 18000, '42.2km': 30000, '50km': 40000}
    },
  ];
});

// ---------------------------------------------------------------------------
// RegisterScreen
// ---------------------------------------------------------------------------
class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialUserType;
  final String? selectedPlan;
  final String? selectedCoachId;

  const RegisterScreen({
    super.key,
    this.initialUserType,
    this.selectedPlan,
    this.selectedCoachId,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Scroll ──────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // GlobalKeys for each lifestyle question so we can auto-scroll to them
  final _q1Key = GlobalKey();
  final _q2Key = GlobalKey();
  final _q3Key = GlobalKey();
  final _q4Key = GlobalKey();
  final _q5Key = GlobalKey();

  // ── Role ────────────────────────────────────────────────────────────────
  String _selectedType = "athlete";
  String? _selectedCoachId;

  // ── Lifestyle answers ───────────────────────────────────────────────────
  String? _workRoutine;
  String? _sleepHours;
  String? _stressLevel;
  String? _eatingHabits;
  List<String> _energyFactors = [];
  bool _showLifestyleErrors = false; // ← add this

  // ── Common field controllers ─────────────────────────────────────────────
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _countryCode = "+91";
  bool _termsAccepted = false;

  // ── Athlete-specific ─────────────────────────────────────────────────────
  String? _selectedDay;
  String? _selectedMonth;
  String? _selectedYear;
  String? _gender;
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String? _selectedCountry;
  String? _selectedCity;
  String _hasMedicalIssues = "no";
  final TextEditingController _medicalDetailsController = TextEditingController();
  final TextEditingController _stravaIdController = TextEditingController();
  String? _experience;
  String? _weeklyMileage;
  final TextEditingController _goalsController = TextEditingController();

  // ── Coach-specific ───────────────────────────────────────────────────────
  final TextEditingController _certificationsController = TextEditingController();
  final TextEditingController _coachExperienceController = TextEditingController();
  List<String> _specializations = [];
  final TextEditingController _bioController = TextEditingController();

  bool _isLoading = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.initialUserType != null) _selectedType = widget.initialUserType!;
    if (widget.selectedCoachId != null) {
      _selectedType = "athlete";
      _selectedCoachId = widget.selectedCoachId;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicalDetailsController.dispose();
    _stravaIdController.dispose();
    _goalsController.dispose();
    _certificationsController.dispose();
    _coachExperienceController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Smoothly scrolls the widget attached to [key] into view.
  /// The 150 ms delay lets setState finish rebuilding first so the
  /// selected-state animation is already visible before we scroll.
  void _scrollToKey(GlobalKey key) {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.05, // tiny top gap so the label isn't clipped
        );
      }
    });
  }

  void _handleSpecializationChange(String spec) {
    setState(() {
      if (_specializations.contains(spec)) {
        _specializations.remove(spec);
      } else {
        _specializations.add(spec);
      }
    });
  }

  // ── Registration submit ──────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == 'coach' && _specializations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one specialization.')),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions.')),
      );
      return;
    }

    if (_selectedType == 'athlete') {
      if (_workRoutine == null ||
          _sleepHours == null ||
          _stressLevel == null ||
          _eatingHabits == null ||
          _energyFactors.isEmpty) {
        setState(() => _showLifestyleErrors = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete the lifestyle assessment.')),
        );

        if (_workRoutine == null) {
          _scrollToKey(_q1Key);
        } else if (_sleepHours == null) {
          _scrollToKey(_q2Key);
        } else if (_stressLevel == null) {
          _scrollToKey(_q3Key);
        } else if (_eatingHabits == null) {
          _scrollToKey(_q4Key);
        } else {
          _scrollToKey(_q5Key);
        }
        return;
      }
    }

    final Map<String, dynamic> payload = {
      'name': '${_firstNameController.text} ${_lastNameController.text}',
      'email': _emailController.text,
      'password': _passwordController.text,
      'phoneNumber': '$_countryCode ${_mobileController.text}',
      'role': _selectedType,
      'plan': 'Free',
      'gender': _gender,
      'height': _heightController.text,
      'weight': _weightController.text,
      'experienceLevel': _experience,
      'weeklyMileage': _weeklyMileage,
      'runningGoals': _goalsController.text,
      'stravaId': _stravaIdController.text.isEmpty ? null : _stravaIdController.text,
      'country': _selectedCountry,
      'city': _selectedCity,
      'termsAccepted': _termsAccepted,
    };

    if (_selectedType == 'athlete') {
      if (_selectedDay != null && _selectedMonth != null && _selectedYear != null) {
        payload['dateOfBirth'] =
        '$_selectedYear-${_selectedMonth!.padLeft(2, '0')}-${_selectedDay!.padLeft(2, '0')}';
      }
      payload['hasMedicalIssues'] = _hasMedicalIssues == 'yes';
      if (_hasMedicalIssues == 'yes') {
        payload['medicalDetails'] = _medicalDetailsController.text;
      }
      payload['selectedCoachId'] = _selectedCoachId;
      payload['workRoutine'] = _workRoutine;
      payload['sleepHours'] = _sleepHours;
      payload['stressLevel'] = _stressLevel;
      payload['eatingHabits'] = _eatingHabits;
      payload['energyFactors'] = _energyFactors;
    }

    if (_selectedType == 'coach') {
      payload['certifications'] = _certificationsController.text;
      payload['coachingExperienceYears'] = int.tryParse(_coachExperienceController.text);
      payload['specializations'] = _specializations;
      payload['bio'] = _bioController.text;
      payload['isApproved'] = false;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(registerProvider(payload).future);
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;
          final textTheme = Theme.of(dialogContext).textTheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade600, size: 48),
                ),
                const SizedBox(height: 20),
                Text(
                  'Registration Successful!',
                  style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedType == 'coach'
                      ? 'Your coach application has been submitted. You\'ll hear from us within 48 hours.'
                      : 'Welcome aboard! You can now sign in to start your training journey.',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurface.withOpacity(0.65)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LandingScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        side: BorderSide(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .outline
                                .withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const SignInScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                        foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Go to Login'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      // Clean up the error message — strip "Exception:" prefixes
      String rawMessage = e.toString();
      String cleanMessage = rawMessage
          .replaceAll('Exception: ', '')
          .replaceAll('exception: ', '')
          .trim();

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Icon(Icons.error_rounded, color: Colors.red.shade600, size: 48),
              ),
              const SizedBox(height: 20),
              Text(
                'Registration Failed',
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                cleanMessage,
                style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
    finally {
      if (mounted) setState(() => _isLoading = false); // ← always reset
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Account',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUserTypeRadioSelector(colorScheme, textTheme),
              const SizedBox(height: 16),
              Text(
                _selectedType == 'athlete'
                    ? 'Create your profile to start your running journey'
                    : 'Register as a run coach and start training athletes achieve their goals',
                style: textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildCommonFields(colorScheme, textTheme),
              if (_selectedType == 'athlete')
                _buildAthleteFields(colorScheme, textTheme),
              if (_selectedType == 'coach')
                _buildCoachFields(colorScheme, textTheme),
              const SizedBox(height: 24),
              _buildTermsAndConditions(colorScheme, textTheme),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : Text(
                  'Complete Registration',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Already have an account? Sign in here',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Role selector ────────────────────────────────────────────────────────
  Widget _buildUserTypeRadioSelector(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: _RadioOptionTile(
              icon: FontAwesomeIcons.personRunning,
              label: 'Athlete',
              isSelected: _selectedType == 'athlete',
              color: colorScheme.primary,
              onTap: () => setState(() => _selectedType = 'athlete'),
            ),
          ),
          Expanded(
            child: _RadioOptionTile(
              icon: FontAwesomeIcons.award,
              label: 'Coach',
              isSelected: _selectedType == 'coach',
              color: colorScheme.secondary,
              onTap: () => setState(() => _selectedType = 'coach'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Common fields ────────────────────────────────────────────────────────
  Widget _buildCommonFields(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: _firstNameController,
                labelText: 'First Name *',
                validator: (val) =>
                val!.isEmpty ? 'Enter your first name' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextFormField(
                controller: _lastNameController,
                labelText: 'Last Name *',
                validator: (val) =>
                val!.isEmpty ? 'Enter your last name' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _emailController,
          labelText: 'Email *',
          keyboardType: TextInputType.emailAddress,
          validator: (val) =>
          val!.isEmpty || !val.contains('@') ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _passwordController,
          labelText: 'Password *',
          obscureText: true,
          validator: (val) => val!.isEmpty ? 'Enter a password' : null,
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Mobile *',
            border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.2),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Row(
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _countryCode,
                  onChanged: (String? newValue) =>
                      setState(() => _countryCode = newValue!),
                  items: <String>[
                    '+91', '+1', '+44', '+86', '+81', '+49', '+33', '+971'
                  ]
                      .map<DropdownMenuItem<String>>((String value) =>
                      DropdownMenuItem<String>(
                          value: value, child: Text(value)))
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Your mobile number',
                    counterText: '', // hides the little "0/10" counter Flutter adds automatically
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Enter your mobile number';
                    if (val.length != 10) return 'Enter a valid 10-digit mobile number';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Athlete fields ───────────────────────────────────────────────────────
  Widget _buildAthleteFields(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text('Date of Birth *', style: textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration:
                _inputDecoration(labelText: 'Day', colorScheme: colorScheme),
                value: _selectedDay,
                onChanged: (val) => setState(() => _selectedDay = val),
                items: List.generate(31, (i) => (i + 1).toString())
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                validator: (val) => val == null ? 'Select day' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    labelText: 'Month', colorScheme: colorScheme),
                value: _selectedMonth,
                onChanged: (val) => setState(() => _selectedMonth = val),
                items: List.generate(12, (i) => (i + 1).toString())
                    .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(DateFormat('MMM')
                        .format(DateTime(0, int.parse(m))))))
                    .toList(),
                validator: (val) => val == null ? 'Select month' : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    labelText: 'Year', colorScheme: colorScheme),
                value: _selectedYear,
                onChanged: (val) => setState(() => _selectedYear = val),
                items: List.generate(
                    100, (i) => (DateTime.now().year - i).toString())
                    .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                    .toList(),
                validator: (val) => val == null ? 'Select year' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration:
          _inputDecoration(labelText: 'Gender *', colorScheme: colorScheme),
          value: _gender,
          onChanged: (val) => setState(() => _gender = val),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
            DropdownMenuItem(
                value: 'prefer-not-to-say', child: Text('Prefer not to say')),
          ],
          validator: (val) => val == null ? 'Select gender' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTextFormField(
                controller: _heightController,
                labelText: 'Height (cm) *',
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Enter height' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextFormField(
                controller: _weightController,
                labelText: 'Weight (kg) *',
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Enter weight' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    labelText: 'Country *', colorScheme: colorScheme),
                value: _selectedCountry,
                onChanged: (val) => setState(() {
                  _selectedCountry = val;
                  _selectedCity = null;
                }),
                items: countryToCities.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                validator: (val) => val == null ? 'Select country' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    labelText: 'City *', colorScheme: colorScheme),
                value: _selectedCity,
                onChanged: (val) => setState(() => _selectedCity = val),
                items: _selectedCountry != null &&
                    countryToCities[_selectedCountry!] != null
                    ? countryToCities[_selectedCountry!]!
                    .map((city) =>
                    DropdownMenuItem(value: city, child: Text(city)))
                    .toList()
                    : [],
                validator: (val) => val == null ? 'Select city' : null,
                hint: const Text('Select city'),
                menuMaxHeight: 300,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Do you have any medical issues? *',
                style: textTheme.bodyLarge),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('No'),
                    value: 'no',
                    groupValue: _hasMedicalIssues,
                    onChanged: (val) =>
                        setState(() => _hasMedicalIssues = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Yes'),
                    value: 'yes',
                    groupValue: _hasMedicalIssues,
                    onChanged: (val) =>
                        setState(() => _hasMedicalIssues = val!),
                  ),
                ),
              ],
            ),
            if (_hasMedicalIssues == 'yes')
              _buildTextFormField(
                controller: _medicalDetailsController,
                labelText: 'Please describe your medical issues *',
                maxLines: 3,
                validator: (val) =>
                val!.isEmpty ? 'Provide medical details' : null,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _stravaIdController,
          labelText: 'Strava ID',
          helperText:
          'If available, please put your Strava ID to track using Strava',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    labelText: 'Running Experience *', colorScheme: colorScheme),
                value: _experience,
                onChanged: (val) => setState(() => _experience = val),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                      value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                  DropdownMenuItem(value: 'expert', child: Text('Expert')),
                ],
                validator: (val) => val == null ? 'Select experience' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: _inputDecoration(
                    labelText: 'Weekly Mileage *', colorScheme: colorScheme),
                value: _weeklyMileage,
                onChanged: (val) => setState(() => _weeklyMileage = val),
                items: const [
                  DropdownMenuItem(value: '0-10', child: Text('0-10 miles')),
                  DropdownMenuItem(value: '10-20', child: Text('10-20 miles')),
                  DropdownMenuItem(value: '20-30', child: Text('20-30 miles')),
                  DropdownMenuItem(value: '30-40', child: Text('30-40 miles')),
                  DropdownMenuItem(value: '40+', child: Text('40+ miles')),
                ],
                validator: (val) => val == null ? 'Select mileage' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _goalsController,
          labelText: 'Running Goals',
          maxLines: 4,
        ),
        // ── Lifestyle questionnaire (athletes only) ──
        _buildLifestyleQuestionnaire(colorScheme, textTheme),
      ],
    );
  }

  // ── Coach fields ─────────────────────────────────────────────────────────
  Widget _buildCoachFields(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _certificationsController,
          labelText: 'Certifications *',
          maxLines: 3,
          validator: (val) => val!.isEmpty ? 'Enter certifications' : null,
        ),
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _coachExperienceController,
          labelText: 'Coaching Experience (Years) *',
          keyboardType: TextInputType.number,
          validator: (val) {
            if (val!.isEmpty) return 'Enter coaching experience';
            if (int.tryParse(val) == null) return 'Enter a valid number';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specializations *', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: specializationOptions.map((spec) {
                final isSelected = _specializations.contains(spec);
                return FilterChip(
                  label: Text(spec),
                  selected: isSelected,
                  onSelected: (_) => _handleSpecializationChange(spec),
                  backgroundColor: isSelected
                      ? colorScheme.secondary.withOpacity(0.2)
                      : colorScheme.surfaceVariant,
                  selectedColor: colorScheme.secondary,
                  labelStyle: textTheme.bodyMedium?.copyWith(
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
            if (_specializations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Select at least one specialization',
                  style:
                  textTheme.bodySmall?.copyWith(color: colorScheme.error),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextFormField(
          controller: _bioController,
          labelText: 'Coaching Philosophy & Bio *',
          maxLines: 5,
          validator: (val) => val!.isEmpty ? 'Enter coaching bio' : null,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border:
            Border.all(color: colorScheme.secondary.withOpacity(0.3)),
          ),
          child: Text(
            'Note: Coach applications are reviewed by our team. You\'ll receive an email within 48 hours about your application status.',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }

  // ── Lifestyle questionnaire ──────────────────────────────────────────────
  Widget _buildLifestyleQuestionnaire(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Divider(color: colorScheme.outline.withOpacity(0.3)),
        const SizedBox(height: 16),

        // Section header
        Row(
          children: [
            Icon(Icons.self_improvement_rounded,
                color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Lifestyle Assessment',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Helps us personalise your training plan',
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
        ),
        const SizedBox(height: 20),

        // Q1 — Work routine
        _buildSingleSelectQuestion(
          questionKey: _q1Key,
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: 'How would you describe your work routine? *',
          options: const [
            'Mostly sitting',
            'Mixed movement',
            'Physically active',
            'Shift-based/unpredictable',
          ],
          selectedValue: _workRoutine,
          showError: _showLifestyleErrors && _workRoutine == null, // ← add this
          onChanged: (val) {
            setState(() => _workRoutine = val);
            _scrollToKey(_q2Key); // ← auto-scroll to Q2
          },
        ),
        const SizedBox(height: 20),

        // Q2 — Sleep hours
        _buildSingleSelectQuestion(
          questionKey: _q2Key,
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: 'How many hours do you usually sleep? *',
          options: const ['Less than 5', '5–6', '6–7', '7–8', '8+'],
          selectedValue: _sleepHours,
          showError: _showLifestyleErrors && _sleepHours == null, // ← add this
          onChanged: (val) {
            setState(() => _sleepHours = val);
            _scrollToKey(_q3Key); // ← auto-scroll to Q3
          },
        ),
        const SizedBox(height: 20),

        // Q3 — Stress level
        _buildSingleSelectQuestion(
          questionKey: _q3Key,
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: 'How often do you feel stressed or mentally drained? *',
          options: const ['Rarely', 'Sometimes', 'Often', 'Almost daily'],
          selectedValue: _stressLevel,
          showError: _showLifestyleErrors && _stressLevel == null, // ← add this
          onChanged: (val) {
            setState(() => _stressLevel = val);
            _scrollToKey(_q4Key); // ← auto-scroll to Q4
          },
        ),
        const SizedBox(height: 20),

        // Q4 — Eating habits
        _buildSingleSelectQuestion(
          questionKey: _q4Key,
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: 'Which best describes your eating habits? *',
          options: const [
            'Structured & healthy',
            'Mostly balanced',
            'Irregular meal timings',
            'Frequent takeout/snacking',
            'Emotional/stress eating',
          ],
          selectedValue: _eatingHabits,
          showError: _showLifestyleErrors && _eatingHabits == null, //eating habits error
          onChanged: (val) {
            setState(() => _eatingHabits = val);
            _scrollToKey(_q5Key); // ← auto-scroll to Q5
          },
        ),
        const SizedBox(height: 20),

        // Q5 — Energy factors (multi-select — no auto-scroll, last question)
        Container(
          key: _q5Key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What usually affects your energy levels the most? *',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Select all that apply',
                style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Poor sleep',
                  'Work stress',
                  'Lack of movement',
                  'Food habits',
                  'Hormonal/health issues',
                  'Not sure',
                ].map((opt) {
                  final isSelected = _energyFactors.contains(opt);
                  return FilterChip(
                    label: Text(opt),
                    selected: isSelected,
                    onSelected: (_) => setState(() {
                      if (isSelected) {
                        _energyFactors.remove(opt);
                      } else {
                        _energyFactors.add(opt);
                      }
                    }),
                    backgroundColor: colorScheme.surfaceVariant,
                    selectedColor: colorScheme.primary.withOpacity(0.85),
                    labelStyle: textTheme.bodyMedium?.copyWith(
                      color:
                      isSelected ? Colors.white : colorScheme.onSurface,
                    ),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              if (_showLifestyleErrors && _energyFactors.isEmpty) // ← add this
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Please select at least one option',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Single-select question tile ──────────────────────────────────────────
  Widget _buildSingleSelectQuestion({
    required GlobalKey questionKey,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String label,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String?> onChanged,
    bool showError = false, // ← add this
  }) {
    return Container(
      key: questionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          ...options.map((opt) {
            final isSelected = selectedValue == opt;
            return GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.08)
                      : colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : showError
                        ? colorScheme.error
                        : colorScheme.outline.withOpacity(0.3),
                    width: isSelected || showError ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? colorScheme.primary : colorScheme.outline,
                          width: 1.5,
                        ),
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      opt,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (showError)
            Padding(
              padding: const EdgeInsets.only(top: 2.0, left: 4.0),
              child: Text(
                'Please select one',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  // ── Terms & conditions ───────────────────────────────────────────────────
  Widget _buildTermsAndConditions(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _termsAccepted,
          onChanged: (bool? newValue) =>
              setState(() => _termsAccepted = newValue ?? false),
          activeColor: colorScheme.primary,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text.rich(
              TextSpan(
                text: 'I agree to the ',
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface),
                children: [
                  TextSpan(
                    text: 'Terms of Service',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared form field helpers ────────────────────────────────────────────
  TextFormField _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      decoration: _inputDecoration(
        labelText: labelText,
        helperText: helperText,
        colorScheme: Theme.of(context).colorScheme,
      ),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? helperText,
    required ColorScheme colorScheme,
  }) {
    return InputDecoration(
      labelText: labelText,
      helperText: helperText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide:
        BorderSide(color: colorScheme.outline.withOpacity(0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide:
        BorderSide(color: colorScheme.outline.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      filled: true,
      fillColor: colorScheme.surfaceVariant.withOpacity(0.2),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle:
      TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
      hintStyle:
      TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
      helperStyle:
      TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
    );
  }
}

// ---------------------------------------------------------------------------
// _RadioOptionTile
// ---------------------------------------------------------------------------
class _RadioOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RadioOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(6),
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color:
          isSelected ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : colorScheme.outline,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            FaIcon(icon,
                size: 16,
                color: isSelected
                    ? color
                    : colorScheme.onSurface.withOpacity(0.6)),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                fontWeight:
                isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? color
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UserTypeCard — kept for backwards compatibility if referenced elsewhere
// ---------------------------------------------------------------------------
class _UserTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: isSelected ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected
            ? BorderSide(color: color, width: 3)
            : BorderSide.none,
      ),
      color: isSelected
          ? color.withOpacity(0.1)
          : Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}