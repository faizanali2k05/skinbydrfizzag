import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double width;
  final double height;
  
  const AppLogo({
    super.key, 
    this.width = 200,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'lib/assets/logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
