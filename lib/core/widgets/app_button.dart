import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final IconData? icon;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.icon,
    this.leading,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = AppDimensions.radius,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primary;
    final txtColor = textColor ?? Colors.white;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(txtColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppDimensions.sm),
              ] else if (icon != null) ...[
                Icon(icon, color: txtColor, size: 20),
                const SizedBox(width: AppDimensions.sm),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: txtColor,
                    ),
                  ),
                ),
              ),
            ],
          );

    final buttonWidget = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.md,
                horizontal: AppDimensions.lg,
              ),
              side: BorderSide(color: bgColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.md,
                horizontal: AppDimensions.lg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            child: child,
          );

    if (width != null) {
      return SizedBox(width: width, child: buttonWidget);
    }
    return SizedBox(width: double.infinity, child: buttonWidget);
  }
}
