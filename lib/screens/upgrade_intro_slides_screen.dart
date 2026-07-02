import 'package:flutter/material.dart';
import '../screens/select_plan_screen.dart'; // Import your SelectPlanScreen

class UpgradeIntroSlidesScreen extends StatefulWidget {
  const UpgradeIntroSlidesScreen({super.key});

  @override
  State<UpgradeIntroSlidesScreen> createState() => _UpgradeIntroSlidesScreenState();
}

class _UpgradeIntroSlidesScreenState extends State<UpgradeIntroSlidesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = const [
    {
      'title': 'Personalized Coaching',
      'description': 'Get a customized training plan from a real run coach tailored to your goals and performance.',
      'image': 'assets/images/coach_interaction.png', // Placeholder image path
    },
    {
      'title': 'Customized Training Plans',
      'description': 'No more generic workouts. Your coach designs plans that adapt to your progress and schedule.',
      'image': 'assets/images/custom_plan.png', // Placeholder image path
    },
    {
      'title': 'Daily 1-on-1 Chat Support',
      'description': 'Direct communication with your coach for instant feedback, motivation, and adjustments.',
      'image': 'assets/images/chat_support.png', // Placeholder image path
    },
    {
      'title': 'Weekly Performance Calls',
      'description': 'Deep dive into your weekly performance, discuss challenges, and strategize for the next week.',
      'image': 'assets/images/weekly_call.png', // Placeholder image path
    },
    {
      'title': 'Recovery & Injury Prevention',
      'description': 'Receive expert guidance on recovery techniques and injury prevention to keep you running strong.',
      'image': 'assets/images/recovery_guidance.png', // Placeholder image path
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Or a suitable background
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _IntroSlide(slideData: _slides[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _currentPage > 0
                    ? TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Back'),
                )
                    : const SizedBox.shrink(),
                _buildPageIndicator(),
                _currentPage == _slides.length - 1
                    ? ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const SelectPlanScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // Use your primary color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  ),
                  child: const Text('Get Started'),
                )
                    : ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent, // Use your primary color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  ),
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      children: List.generate(_slides.length, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          width: _currentPage == index ? 24.0 : 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.blueAccent : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  final Map<String, String> slideData;

  const _IntroSlide({required this.slideData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // You'll need to add assets/images/coach_interaction.png etc.
          // For now, let's use a placeholder icon
          Icon(Icons.star, size: 120, color: Colors.blueAccent), // Replace with Image.asset(slideData['image']!)
          const SizedBox(height: 40),
          Text(
            slideData['title']!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            slideData['description']!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}