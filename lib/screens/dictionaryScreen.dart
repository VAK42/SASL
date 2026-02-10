import 'package:flutter/material.dart';
import '../widgets/signCard.dart';
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}
class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _allLetters = List.generate(26, (i) => String.fromCharCode(65 + i));
  List<String> _filteredLetters = [];
  @override
  void initState() {
    super.initState();
    _filteredLetters = _allLetters;
    _searchController.addListener(_filterLetters);
  }
  void _filterLetters() {
    final query = _searchController.text.toUpperCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLetters = _allLetters;
      } else {
        _filteredLetters = _allLetters.where((letter) => letter.contains(query)).toList();
      }
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: scaffoldColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Dictionary', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search For A Letter...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                  : null,
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Expanded(
            child: _filteredLetters.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text('No Letters Found', style: TextStyle(fontSize: 18, color: theme.hintColor)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _filteredLetters.length,
                  itemBuilder: (context, index) => SignCard(
                    letter: _filteredLetters[index],
                    onTap: () => _showSignDetail(context, _filteredLetters[index]),
                  ),
                ),
          ),
        ],
      ),
    );
  }
  void _showSignDetail(BuildContext context, String letter) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Letter $letter', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.disabledColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Image.asset(
                  'assets/images/signs/${letter.toLowerCase()}.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Icon(Icons.front_hand, size: 100, color: theme.primaryColor.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How To Sign "$letter"',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Position Your Hand As Shown Above In Front Of The Camera!',
                style: TextStyle(fontSize: 14, color: theme.hintColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}