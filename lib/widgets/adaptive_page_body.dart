import 'package:flutter/material.dart';

/// Centers phone-first screens on wider displays without changing their flow.
class AdaptivePageBody extends StatelessWidget {
  const AdaptivePageBody({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
