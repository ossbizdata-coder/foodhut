import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double height;

  const AppLogo({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: height,
        child: Image.asset(
          "assets/images/logo.png",
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

