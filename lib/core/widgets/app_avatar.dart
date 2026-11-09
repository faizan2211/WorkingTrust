import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  /// Bytes of a photo chosen on this device; wins over [imageUrl].
  final Uint8List? imageBytes;
  final double radius;
  final bool online;

  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.imageBytes,
    this.radius = 20,
    this.online = false,
  });

  String get _initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  Widget get _fallback => Container(
    width: radius * 2,
    height: radius * 2,
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.1),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Text(
      _initial,
      style: TextStyle(
        fontSize: radius,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    ),
  );

  Widget get _image {
    final bytes = imageBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallback,
      );
    }
    final url = imageUrl;
    if (url == null) return _fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => _fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: ClipOval(child: _image)),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: radius * 0.55,
                height: radius * 0.55,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
