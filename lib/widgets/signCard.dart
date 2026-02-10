import 'package:flutter/material.dart';
class SignCard extends StatelessWidget {
  final String letter;
  final VoidCallback? onTap;
  const SignCard({super.key, required this.letter, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/signs/${letter.toLowerCase()}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => Icon(
                      Icons.sign_language,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(letter, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}