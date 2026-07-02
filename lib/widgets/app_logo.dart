import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  static const String _logoUrl =
      'https://raw.githubusercontent.com/asrar-fn/runcoach-frontend/main/web/icons/endurepeak_logo.png';

  // ✅ Remove 'const' from constructor — network widgets can't be const
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _logoUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      loadingBuilder: (context, child, progress) =>
      progress == null ? child : const SizedBox.shrink(),
      errorBuilder: (context, error, stack) => Image.asset(
        'assets/images/endurepeak_logo.png',
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
      ),
    );
  }
}