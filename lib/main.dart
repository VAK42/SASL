import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/cacheService.dart';
import 'screens/dashboardScreen.dart';
import 'screens/onboardingScreen.dart';
const kBrandPurple = Color(0xFF9C27B0);
const kBrandPurpleDark = Color(0xFFCE93D8);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cacheService = CacheService();
  await cacheService.initialize();
  runApp(MyApp(cacheService: cacheService));
}
class MyApp extends StatelessWidget {
  final CacheService cacheService;
  const MyApp({super.key, required this.cacheService});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settingsBox').listenable(),
      builder: (context, box, _) {
        final isDark = cacheService.isDarkMode();
        return MaterialApp(
          title: 'SASL',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.purple,
            primaryColor: kBrandPurple,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primarySwatch: Colors.purple,
            primaryColor: kBrandPurpleDark,
            useMaterial3: true,
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: cacheService.getUser() == null ? const OnboardingScreen() : const DashboardScreen(),
        );
      },
    );
  }
}