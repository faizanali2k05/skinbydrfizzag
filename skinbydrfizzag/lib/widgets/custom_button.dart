import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';

/// Branded primary button used across the app.
///
/// Falls back to a clean outline variant when [isOutlined] is true so we get a
/// consistent look without each screen re-rolling button styling.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 54,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = isLoading;
    final Widget label = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: isOutlined ? AppColors.primary : Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: textColor ??
                      (isOutlined ? AppColors.primary : Colors.white),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: AppStyles.buttonText.copyWith(
                  color: textColor ??
                      (isOutlined ? AppColors.primary : Colors.white),
                ),
              ),
            ],
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isDisabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: backgroundColor ?? AppColors.primary,
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                foregroundColor: textColor ?? AppColors.primary,
              ),
              child: label,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: backgroundColor == null
                    ? AppColors.primaryGradient
                    : null,
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: (backgroundColor ?? AppColors.primary)
                              .withAlpha(64),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: isDisabled ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: label,
              ),
            ),
    );
  }
}
