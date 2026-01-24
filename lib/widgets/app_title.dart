import 'package:flutter/material.dart';

class AppTitle extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;

  const AppTitle({
    super.key,
    this.fontSize = 28,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        children: const [
          TextSpan(
            text: "OneStop",
            style: TextStyle(color: Colors.black),
          ),
          TextSpan(
            text: "Daily",
            style: TextStyle(color: Color(0xFF0E9553)), // your green #0E9553
          ),
        ],
      ),
    );
  }
}
