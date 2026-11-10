import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 56});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo.png', height: height);
  }
}