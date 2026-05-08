import 'package:flutter/material.dart';

/// Fond en dégradé pour les écrans principaux.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[Color(0xFF0F172A), Color(0xFF1E293B)]
              : const <Color>[Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
        ),
      ),
      child: child,
    );
  }
}

/// Panneau carte avec option tap / dégradé.
class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    super.key,
    this.padding,
    this.radius = 26,
    this.gradient,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;
  /// Bordure alternative (ex. traitillé visuel géré par parent).
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final side = border;
    final r = BorderRadius.circular(radius);
    final deco = gradient != null
        ? BoxDecoration(gradient: gradient, borderRadius: r)
        : BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: r,
            border: Border.fromBorderSide(
              side ?? BorderSide(color: outline),
            ),
          );

    final content = Padding(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: child,
    );

    final decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: deco,
      child: content,
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.eyebrow,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = subtitle;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: theme.textTheme.titleLarge),
              if (sub != null && sub.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  sub,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppStatTile extends StatelessWidget {
  const AppStatTile({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
    this.hint,
    this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? hint;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = accent ?? theme.colorScheme.primary;
    final h = hint;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: accentColor),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (h != null && h.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                h,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final act = action;
    return AppPanel(
      radius: 24,
      child: Column(
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (act != null) ...[
            const SizedBox(height: 16),
            act,
          ],
        ],
      ),
    );
  }
}
