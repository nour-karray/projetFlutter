import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({
    required this.localeCode,
    required this.authService,
    super.key,
  });

  final String localeCode;
  final AuthService authService;

  bool get _fr => localeCode != 'en' && localeCode != 'ar';

  Future<void> _action(
    BuildContext context,
    Future<AuthActionResult> Function() run,
  ) async {
    final res = await run();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message ?? ''),
        backgroundColor:
            res.success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = authService.email ?? '—';

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: authService,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  AppPanel(
                    gradient: AppThemePalette.heroGradient(
                      theme.brightness == Brightness.dark,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fr
                              ? 'Verifiez votre email'
                              : 'Verify your email',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_fr ? 'Lien envoye à' : 'Link sent to'} $email',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (authService.isBusy)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    FilledButton.icon(
                      onPressed: () => _action(
                        context,
                        () => authService.reloadCurrentUser(),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        _fr
                            ? 'J ai verifie, actualiser'
                            : 'I verified, refresh state',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _action(
                        context,
                        () => authService.sendEmailVerification(),
                      ),
                      icon: const Icon(Icons.forward_to_inbox_rounded),
                      label: Text(
                        _fr
                            ? 'Renvoyer le mail'
                            : 'Resend verification email',
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextButton(
                      onPressed: authService.isBusy
                          ? null
                          : () => authService.signOut(),
                      child: Text(_fr ? 'Utiliser un autre compte' : 'Use another account'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
