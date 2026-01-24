import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: isDisabled ? 0 : 2,
          backgroundColor: isDisabled
              ? Colors.grey.shade200
              : Theme.of(context).primaryColor,
          foregroundColor:
          isDisabled ? Colors.grey.shade600 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color:
              isDisabled ? Colors.grey.shade600 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
