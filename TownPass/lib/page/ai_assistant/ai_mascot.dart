import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The mascot artwork is adapted from the supplied HTML prototype's SVG.
class AiMascot extends StatelessWidget {
  const AiMascot({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/svg/ai_mascot.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
