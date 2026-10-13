import 'package:flutter/material.dart';

import 'auth_brand_header.dart';

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({super.key, required this.subtitle, required this.child});

  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  AuthBrandHeader(subtitle: subtitle),
                  const SizedBox(height: 28),
                  child,
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 15, color: Colors.grey),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Secure authentication powered by Firebase',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
