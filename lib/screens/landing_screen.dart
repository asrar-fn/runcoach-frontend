// lib/screens/landing_screen.dart (MODIFIED)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' as vector;
import './sign_in_screen.dart';
import './register_screen.dart';
import './membership_selection_screen.dart';
import '../widgets/app_logo.dart';

// Conceptual providers (replace with actual logic)
final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) => AuthNotifier());

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false);
  void login() { state = true; }
  void logout() { state = false; }
}

final Color kPrimaryBlue = const Color(0xFF4285F4);
final Color kAccentOrange = const Color(0xFFFF964F);

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  Timer? _carouselTimer;
  int _currentPage = 0;

  late AnimationController _heroTextController;
  late Animation<Offset> _heroTextSlideAnimation;
  late Animation<double> _heroTextFadeAnimation;

  late AnimationController _runnerSparkleController;
  late Animation<double> _runnerSparkleAnimation;

  final List<Map<String, dynamic>> _features = const [
    {
      'icon': FontAwesomeIcons.chartLine,
      'title': 'Advanced Analytics',
      'description': 'Visualize every metric: pace, heart rate, calories, and progress trends.',
      'colors': [Color(0xFFFF5C39), Color(0xFFFF964F)],
    },
    {
      'icon': FontAwesomeIcons.comments,
      'title': 'Expert Coach Access',
      'description': 'Chat directly with certified coaches for tailored guidance.',
      'colors': [Color(0xFF26C6DA), Color(0xFF80DEEA)],
    },
    {
      'icon': FontAwesomeIcons.trophy,
      'title': 'Race Day Mastery',
      'description': 'Strategize and optimize your training for peak performance on race day.',
      'colors': [Color(0xFF66BB6A), Color(0xFFA5D6A7)],
    },
    {
      'icon': FontAwesomeIcons.heartbeat,
      'title': 'Health & Recovery',
      'description': 'Monitor key health indicators and recovery insights to prevent overtraining.',
      'colors': [Color(0xFFFF7043), Color(0xFFFFAB91)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();

    _heroTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _heroTextSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroTextController,
      curve: Curves.easeOutCubic,
    ));
    _heroTextFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroTextController,
        curve: Curves.easeIn,
      ),
    );

    _runnerSparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      animationBehavior: AnimationBehavior.preserve,
    )..repeat();
    _runnerSparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _runnerSparkleController,
        curve: const _FlashingCurve(),
      ),
    );

    _heroTextController.forward();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _heroTextController.dispose();
    _runnerSparkleController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _features.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _showRegistrationModal({String? initialUserType, String? selectedPlan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return RegisterScreen(
              initialUserType: initialUserType,
              selectedPlan: selectedPlan,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white, colorScheme.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 0.8],
              ),
            ),
          ),
          // Sparkle animation
          Positioned(
            top: screenSize.height * 0.1,
            right: -screenSize.width * 0.2,
            child: AnimatedBuilder(
              animation: _runnerSparkleAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.08 + (_runnerSparkleAnimation.value * 0.1),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateY(vector.radians(_runnerSparkleAnimation.value * 10))
                      ..scale(1.0 + (_runnerSparkleAnimation.value * 0.03)),
                    child: SizedBox(
                      width: screenSize.width * 1.0,
                      height: screenSize.height * 0.8,
                      child: CustomPaint(
                        painter: _AbstractRunnerSparklePainter(
                          primaryColor: kPrimaryBlue,
                          accentColor: kAccentOrange,
                          animationValue: _runnerSparkleAnimation.value,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // ✅ Scrollable content with top padding to clear fixed header
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 70), // ← space for fixed header
                _buildHeroSection(screenSize, context, textTheme, colorScheme),
                _buildFeaturesSection(screenSize, textTheme, colorScheme),
                _buildFooterSection(textTheme, colorScheme),
              ],
            ),
          ),
          // ✅ FIXED HEADER - always on top, doesn't scroll
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        height: 70,
        color: Colors.grey.withOpacity(0.85),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✅ Fixed width, not Expanded — gives logo room to breathe
            SizedBox(
              width: 160,
              height: 62,
              child: AppLogo(
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            // LOG IN button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [kPrimaryBlue, kAccentOrange]),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignInScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25)),
                ),
                child: Text('LOG IN',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(Size screenSize, BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
      child: FadeTransition(
        opacity: _heroTextFadeAnimation,
        child: SlideTransition(
          position: _heroTextSlideAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '⚡️ Ignite Your Performance',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  text: 'Train Smarter ',
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: screenSize.width * 0.10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF964F),
                    height: 1.1,
                  ),
                  children: [
                    TextSpan(
                      text: 'Reach Your Peak',
                      style: TextStyle(color: kPrimaryBlue),

                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock your true running potential with personalized coaching, cutting-edge analytics, and a vibrant community.',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.black.withOpacity(0.85),
                  height: 1.6,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 48),
              // ✅ Single CTA button replacing the two role-based buttons
              _GradientButton(
                text: "Get Started",
                onPressed: () {
                  _showRegistrationModal();
                },
                gradient: LinearGradient(
                  colors: [
                    kPrimaryBlue,
                    kAccentOrange,
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(Size screenSize, TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Core Features',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              fontSize: screenSize.width * 0.08,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Text(
              'Power your training with tools designed for every runner, from beginner to elite.',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: screenSize.height * 0.45,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _features.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final feature = _features[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _AnimatedFeatureCard(
                    icon: feature['icon'] as IconData,
                    title: feature['title'] as String,
                    description: feature['description'] as String,
                    iconGradient: LinearGradient(colors: feature['colors'] as List<Color>),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildPageIndicator(colorScheme),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_features.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _currentPage == index ? 24.0 : 10.0,
          height: 10.0,
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: _currentPage == index ? kAccentOrange : Colors.grey.withOpacity(0.4),
            boxShadow: _currentPage == index
                ? [
              BoxShadow(
                color: kAccentOrange.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ]
                : [],
          ),
        );
      }),
    );
  }

  Widget _buildFooterSection(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      color: Colors.black,
      child: Column(
        children: [
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: [
          //     Image.asset(
          //       'assets/images/endurepeak_logo.jpeg',
          //       height: 36,
          //       width: 36,
          //       fit: BoxFit.contain,
          //     ),
          //     const SizedBox(width: 12),
          //     Text(
          //       'endurepeak',
          //       style: textTheme.headlineSmall?.copyWith(
          //         fontWeight: FontWeight.w900,
          //         color: Colors.white,
          //         letterSpacing: 1.2,
          //         fontSize: 26,
          //       ),
          //     ),
          //   ],
          // ),
          // In _buildFooterSection, replace the Image.asset with:
          LayoutBuilder(
            builder: (context, constraints) {
              return Image.asset(
                'assets/images/endurepeak_logo.png',
                width: constraints.maxWidth * 0.6,  // 60% of footer width
                fit: BoxFit.fitWidth,
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'endurepeak empowers every runner to push their limits and achieve greatness. Join our community today!',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: Colors.white,
              fontSize: 17,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 35),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _FooterLink(text: 'About Us', onPressed: () {}),
              _FooterLink(text: 'Features', onPressed: () {}),
              _FooterLink(text: 'Contact', onPressed: () {}),
              _FooterLink(text: 'Privacy Policy', onPressed: () {}),
              _FooterLink(text: 'Terms of Service', onPressed: () {}),
            ],
          ),
          const SizedBox(height: 35),
          Divider(color: Colors.white.withOpacity(0.4)),
          const SizedBox(height: 20),
          Text(
            '© 2026 endurepeak. All rights reserved.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// --- CustomAppBar Widget ---
// class _CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
//   const _CustomAppBar();
//
//   @override
//   Size get preferredSize => const Size.fromHeight(70); // ← reduced header height
//
//   @override
//   Widget build(BuildContext context) {
//     return AppBar(
//       backgroundColor: Colors.black.withOpacity(0.2),
//       elevation: 0,
//       toolbarHeight: 70,
//       automaticallyImplyLeading: false,
//       flexibleSpace: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // ← small padding
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // Logo fills available height minus padding
//               Image.asset(
//                 'assets/images/endurepeak_logo.png',
//                 height: 54, // ← 70 (toolbar) - 16 (8+8 vertical padding)
//                 fit: BoxFit.fitHeight,
//               ),
//               // LOG IN button
//               Container(
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [kPrimaryBlue, kAccentOrange],
//                   ),
//                   borderRadius: BorderRadius.circular(25),
//                 ),
//                 child: ElevatedButton(
//                   onPressed: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => const SignInScreen()),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.transparent,
//                     shadowColor: Colors.transparent,
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(25),
//                     ),
//                   ),
//                   child: Text(
//                     'LOG IN',
//                     style: Theme.of(context).textTheme.labelLarge?.copyWith(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// --- GradientButton Widget ---
class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final LinearGradient gradient;
  final Icon? icon;
  final EdgeInsetsGeometry padding;

  const _GradientButton({
    required this.text,
    required this.onPressed,
    required this.gradient,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.6),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 10),
                  icon!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- AnimatedFeatureCard Widget ---
class _AnimatedFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final LinearGradient iconGradient;

  const _AnimatedFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconGradient,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 15,
      shadowColor: Colors.black.withOpacity(0.25),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: iconGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: iconGradient.colors.first.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 35, color: Colors.white),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.75),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Abstract Runner Sparkle CustomPainter ---
class _AbstractRunnerSparklePainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final double animationValue;

  _AbstractRunnerSparklePainter({required this.primaryColor, required this.accentColor, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withOpacity(0.1),
          accentColor.withOpacity(0.15 + (0.1 * (1 - animationValue))),
          primaryColor.withOpacity(0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.0, 0.5 + (0.3 * animationValue), 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + (5 * animationValue));

    final accentPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accentColor.withOpacity(0.0),
          accentColor.withOpacity(0.7),
          primaryColor.withOpacity(0.7),
          accentColor.withOpacity(0.0),
        ],
        begin: Alignment(-1.0 + (2 * animationValue), -1.0 + (2 * animationValue)),
        end: Alignment(1.0 - (2 * animationValue), 1.0 - (2 * animationValue)),
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (1 * (1 - animationValue))
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + (3 * animationValue));

    Path runnerPath = Path();
    runnerPath.moveTo(w * 0.4, h * 0.1);
    runnerPath.quadraticBezierTo(w * 0.7, h * 0.05, w * 0.8, h * 0.3);
    runnerPath.quadraticBezierTo(w * 0.9, h * 0.6, w * 0.7, h * 0.8);
    runnerPath.quadraticBezierTo(w * 0.5, h * 0.95, w * 0.3, h * 0.7);
    runnerPath.quadraticBezierTo(w * 0.1, h * 0.4, w * 0.4, h * 0.1);
    runnerPath.close();

    canvas.drawPath(runnerPath, glowPaint);

    final pathMetrics = runnerPath.computeMetrics();
    for (final metric in pathMetrics) {
      final length = metric.length;
      final dashLength = length * 0.2;
      final gapLength = length * 0.3;
      final totalDashAndGap = dashLength + gapLength;
      final offset = (length * animationValue * 1.5) % totalDashAndGap;

      final Path dashedPath = Path();
      for (double i = 0; i < length; i += totalDashAndGap) {
        dashedPath.addPath(metric.extractPath(i + offset, i + offset + dashLength), Offset.zero);
      }
      canvas.drawPath(dashedPath, accentPaint);
    }

    final accentPath2 = Path();
    accentPath2.moveTo(w * 0.2, h * 0.6);
    accentPath2.quadraticBezierTo(w * 0.4, h * 0.4, w * 0.6, h * 0.6);
    accentPath2.quadraticBezierTo(w * 0.8, h * 0.8, w * 0.6, h * 0.9);
    accentPath2.quadraticBezierTo(w * 0.4, h * 0.7, w * 0.2, h * 0.6);

    final pathMetrics2 = accentPath2.computeMetrics();
    for (final metric in pathMetrics2) {
      final length = metric.length;
      final dashLength = length * 0.1;
      final gapLength = length * 0.4;
      final totalDashAndGap = dashLength + gapLength;
      final offset = (length * (1 - animationValue) * 2) % totalDashAndGap;

      final Path dashedPath = Path();
      for (double i = 0; i < length; i += totalDashAndGap) {
        dashedPath.addPath(metric.extractPath(i + offset, i + offset + dashLength), Offset.zero);
      }
      canvas.drawPath(dashedPath, accentPaint..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant _AbstractRunnerSparklePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.animationValue != animationValue;
  }
}

// Custom Curve for non-linear flashing/pulsing effect
class _FlashingCurve extends Curve {
  const _FlashingCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.25) {
      return Curves.easeOutQuad.transform(t * 4);
    } else if (t < 0.75) {
      return 1.0 - Curves.easeInQuad.transform((t - 0.25) * 2);
    } else {
      return Curves.easeOutQuad.transform((t - 0.75) * 4);
    }
  }
}

// Footer link helper
class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _FooterLink({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}