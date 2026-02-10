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
            _buildIntroPage('Welcome To SASL', 'Learn Sign Language With AI-Powered Recognition', Icons.waving_hand),
            _buildIntroPage('Practice Modes', 'Practice, Test, Speed Challenge & More!', Icons.sports_score),
            _buildIntroPage('Track Progress', 'Monitor Your Learning Journey With Streaks & Scores', Icons.trending_up),
            _buildNameInputPage(),
          ],
        ),
      ),
    );
  }
  Widget _buildIntroPage(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: Theme.of(context).primaryColor),
          const SizedBox(height: 40),
          Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0) TextButton(onPressed: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Back')),
              if (_currentPage > 0) const Spacer(),
              ElevatedButton(onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut), child: const Text('Next')),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildNameInputPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 120),
          const SizedBox(height: 40),
          const Text('What\'s Your Name?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          TextField(controller: _nameController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Enter Your Name', hintText: 'VAK')),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty) return;
                await CacheService().saveUser(_nameController.text.trim());
                if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
              },
              child: const Padding(padding: EdgeInsets.all(16), child: Text('Get Started', style: TextStyle(fontSize: 18))),
            ),
          ),
        ],
      ),
    );
  }
}