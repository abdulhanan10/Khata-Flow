import 'package:flutter/material.dart';

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'lib/assets/images/app_logo.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          semanticLabel: 'Khata Flow logo',
          errorBuilder: (context, error, stackTrace) => const SizedBox(
            width: 200,
            height: 200,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 72,
              color: Color(0xFF176B5B),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        ),
      ],
    );
  }
}
