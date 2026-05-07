import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  StreamSubscription<User?>? _authSub;
  User? _currentUser;
  bool _isReady = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isReady => _isReady;
  bool get isSignedIn => _currentUser != null;
  String? get uid => _currentUser?.uid;
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
    _authSub = auth.authStateChanges().listen((user) {
      _currentUser = user;
      notifyListeners();
    });

    try {
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      } else {
        _currentUser = auth.currentUser;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  Future<void> reconnectAnonymous() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
