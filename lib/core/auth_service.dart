import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthActionResult {
  const AuthActionResult._({required this.success, this.message});

  final bool success;
  final String? message;

  factory AuthActionResult.success([String? message]) =>
      AuthActionResult._(success: true, message: message);

  factory AuthActionResult.failure(String message) =>
      AuthActionResult._(success: false, message: message);
}

class AuthService extends ChangeNotifier {
  StreamSubscription<User?>? _authSub;
  User? _currentUser;
  bool _isReady = false;
  bool _isBusy = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isReady => _isReady;
  bool get isBusy => _isBusy;
  bool get isSignedIn => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  String? get uid => _currentUser?.uid;
  String? get email => _currentUser?.email;
  String get displayName {
    final rawName = _currentUser?.displayName?.trim();
    if (rawName != null && rawName.isNotEmpty) return rawName;
    final rawEmail = _currentUser?.email?.trim();
    if (rawEmail != null && rawEmail.isNotEmpty) {
      return rawEmail.split('@').first;
    }
    return 'Workspace user';
  }

  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_isReady) return;

    if (Firebase.apps.isEmpty) {
      _errorMessage = 'Firebase non configure.';
      _isReady = true;
      notifyListeners();
      return;
    }

    final auth = FirebaseAuth.instance;
    _currentUser = auth.currentUser;
    _authSub = auth.userChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });
    _errorMessage = null;
    _isReady = true;
    notifyListeners();
  }

  Future<AuthActionResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthActionResult.success();
    });
  }

  Future<AuthActionResult> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    return _runAuthAction(() async {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final trimmedName = fullName.trim();
      if (trimmedName.isNotEmpty) {
        await credential.user?.updateDisplayName(trimmedName);
      }

      await credential.user?.sendEmailVerification();
      await credential.user?.reload();
      _currentUser = FirebaseAuth.instance.currentUser;
      return AuthActionResult.success(
        'Compte cree. Verifiez votre email pour continuer.',
      );
    });
  }

  Future<AuthActionResult> sendPasswordResetEmail({
    required String email,
  }) async {
    return _runAuthAction(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return AuthActionResult.success('Email de reinitialisation envoye.');
    });
  }

  Future<AuthActionResult> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AuthActionResult.failure('Aucun utilisateur connecte.');
    }
    if (user.emailVerified) {
      return AuthActionResult.success('Adresse email deja verifiee.');
    }

    return _runAuthAction(() async {
      await user.sendEmailVerification();
      return AuthActionResult.success(
        'Email de verification envoye. Pensez a verifier vos spams.',
      );
    });
  }

  Future<AuthActionResult> reloadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return AuthActionResult.failure('Aucun utilisateur connecte.');
    }

    return _runAuthAction(() async {
      await user.reload();
      _currentUser = FirebaseAuth.instance.currentUser;
      notifyListeners();
      return AuthActionResult.success(
        _currentUser?.emailVerified == true
            ? 'Email verifie avec succes.'
            : 'Email non verifie pour le moment.',
      );
    });
  }

  Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<AuthActionResult> _runAuthAction(
    Future<AuthActionResult> Function() action,
  ) async {
    if (Firebase.apps.isEmpty) {
      _errorMessage = 'Firebase non configure.';
      notifyListeners();
      return AuthActionResult.failure(_errorMessage!);
    }

    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await action();
      _errorMessage = result.success ? null : result.message;
      return result;
    } on FirebaseAuthException catch (e) {
      final message = _mapFirebaseError(e);
      _errorMessage = message;
      return AuthActionResult.failure(message);
    } catch (e) {
      final message = 'Operation impossible: $e';
      _errorMessage = message;
      return AuthActionResult.failure(message);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'invalid-credential':
        return 'Identifiants invalides. Verifiez l email et le mot de passe.';
      case 'user-disabled':
        return 'Ce compte a ete desactive.';
      case 'user-not-found':
        return 'Aucun compte trouve avec cette adresse email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Cette adresse email est deja utilisee.';
      case 'operation-not-allowed':
        return 'La methode de connexion email/mot de passe n est pas activee sur Firebase.';
      case 'weak-password':
        return 'Le mot de passe est trop faible.';
      case 'too-many-requests':
        return 'Trop de tentatives. Reessayez un peu plus tard.';
      case 'network-request-failed':
        return 'Connexion reseau indisponible. Verifiez Internet.';
      default:
        return error.message ?? 'Erreur d authentification Firebase.';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
