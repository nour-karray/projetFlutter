import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_surfaces.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.localeCode,
    required this.authService,
    super.key,
  });

  final String localeCode;
  final AuthService authService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  bool _registerMode = false;

  String get _lc => widget.localeCode;
  bool get _fr => _lc != 'en' && _lc != 'ar';

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final res = await widget.authService.signInWithEmail(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    final msg = res.message;
    _toast(
      msg ??
          (_fr ? 'Connexion reussie.' : 'Signed in.'),
      error: !res.success,
    );
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final res = await widget.authService.registerWithEmail(
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    _toast(res.message ?? (_fr ? 'Compte cree.' : 'Account created.'),
        error: !res.success);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast(
        _fr
            ? 'Saisissez une adresse email valide.'
            : 'Enter a valid email.',
        error: true,
      );
      return;
    }
    final res =
        await widget.authService.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    _toast(res.message ??
        (_fr ? 'Si le compte existe, un email a ete envoye.' : 'If the account exists, email was sent.'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.authService,
            builder: (_, __) => ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              children: [
                const SizedBox(height: 28),
                AppPanel(
                  gradient: AppThemePalette.heroGradient(
                    theme.brightness == Brightness.dark,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fr ? 'SmartScan DocTranslate' : 'SmartScan DocTranslate',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fr
                            ? 'Connectez votre espace securise pour synchroniser vos documents.'
                            : 'Secure sign-in keeps your OCR history in sync.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if ((widget.authService.errorMessage ?? '')
                          .trim()
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            widget.authService.errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(_fr ? 'Connexion' : 'Sign in'),
                      selected: !_registerMode,
                      onSelected: (_) =>
                          setState(() => _registerMode = false),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: Text(_fr ? 'Inscription' : 'Register'),
                      selected: _registerMode,
                      onSelected: (_) =>
                          setState(() => _registerMode = true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_registerMode)
                  Form(
                    key: _registerFormKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _fullNameCtrl,
                          decoration: InputDecoration(
                            labelText:
                                _fr ? 'Nom complet' : 'Full name',
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? (_fr ? 'Requis.' : 'Required.')
                                  : null,
                        ),
                        _emailField(loginForm: false),
                        _passwordField(loginForm: false),
                        _submitButton(onPressed: _submitRegister),
                      ],
                    ),
                  )
                else
                  Form(
                    key: _loginFormKey,
                    child: Column(
                      children: [
                        _emailField(loginForm: true),
                        _passwordField(loginForm: true),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                widget.authService.isBusy ? null : _forgotPassword,
                            child:
                                Text(_fr ? 'Mot de passe oublie?' : 'Forgot password?'),
                          ),
                        ),
                        _submitButton(onPressed: _submitLogin),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailField({required bool loginForm}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: _fr ? 'Email' : 'Email',
        ),
        validator: (v) {
          final t = v?.trim() ?? '';
          if (!t.contains('@')) {
            return _fr ? 'Email invalide.' : 'Invalid email.';
          }
          return null;
        },
      ),
    );
  }

  Widget _passwordField({required bool loginForm}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: TextFormField(
        controller: _passwordCtrl,
        obscureText: true,
        autofillHints: loginForm
            ? const [AutofillHints.password]
            : const [AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: _fr ? 'Mot de passe' : 'Password',
        ),
        validator: (v) {
          final t = v ?? '';
          if (t.length < 6) {
            return _fr
                ? 'Au moins 6 caracteres.'
                : 'At least 6 characters.';
          }
          return null;
        },
      ),
    );
  }

  Widget _submitButton({required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed:
              widget.authService.isBusy ? null : onPressed,
          child: widget.authService.isBusy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_fr ? 'Continuer' : 'Continue'),
        ),
      ),
    );
  }
}
