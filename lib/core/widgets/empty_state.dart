import 'package:flutter/material.dart';

import '../design/app_dimens.dart';
import '../design/app_theme.dart';
import 'app_button.dart';

/// Friendly empty state: icon, title, message, optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Icon(icon, size: 34, color: c.textTertiary),
            ),
            Gap.h20,
            Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
            Gap.h8,
            Text(message,
                style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              Gap.h24,
              AppButton(label: actionLabel!, onPressed: onAction, expand: false, size: AppButtonSize.medium),
            ],
          ],
        ),
      ),
    );
  }
}
