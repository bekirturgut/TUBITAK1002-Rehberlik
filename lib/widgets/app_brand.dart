import 'package:flutter/material.dart';

const appName = 'LactiGen';
const appTagline = 'Akıllı Emzirme Asistanı';

class AppBrand extends StatelessWidget {
  const AppBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          appName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A628A),
          ),
        ),
        SizedBox(height: 4),
        Text(
          appTagline,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Color(0xFF4A628A)),
        ),
      ],
    );
  }
}
