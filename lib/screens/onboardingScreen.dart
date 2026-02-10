import 'package:flutter/material.dart';
import '../services/cacheService.dart';
import 'dashboardScreen.dart';
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (page) => setState(() => _currentPage = page),
          children: [
            _buildIntroPage('Welcome To SASL', 'Master The Art Of Sign Language With Real-Time AI Detection', Icons.waving_hand, 'Step 1 Of 4'),
            _buildIntroPage('Interactive Practice', 'Challenge Yourself With Speed Tests, Quizzes, And Daily Drills', Icons.sports_esports, 'Step 2 Of 4'),
            _buildIntroPage('Track Your Proficiency', 'Visualize Your Growth With Detailed Analytics And Achievement Badges', Icons.insights, 'Step 3 Of 4'),
            _buildNameInputPage(),
          ],
        ),
      ),
    );
  }
  Widget _buildIntroPage(String title, String subtitle, IconData icon, String step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(step, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 100, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 48),
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87), textAlign: TextAlign.center),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                ElevatedButton.icon(
                  onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), backgroundColor: Colors.grey[200], foregroundColor: Colors.black87, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              if (_currentPage > 0) const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, elevation: 2, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                label: const Text('Next'),
                icon: const Icon(Icons.arrow_forward, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildNameInputPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Final Step', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.2)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.badge, size: 80),
                    ),
                    const SizedBox(height: 40),
                    const Text('Let\'s Personalize Your Experience', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    const Text('What Should We Call You?', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person),
                        labelText: 'Enter Your Full Name',
                        hintText: 'VAK',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_nameController.text.trim().isEmpty) return;
                          await CacheService().saveUser(_nameController.text.trim());
                          if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Complete Setup & Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}