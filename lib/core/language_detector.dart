class LanguageDetectionResult {
  const LanguageDetectionResult({
    required this.primaryCode,
    required this.rankedCodes,
  });

  final String primaryCode;
  final List<String> rankedCodes;
}

class LanguageDetector {
  /// Mots / fragments typiques FR (UI, formulaires) — l OCR peut oter les accents.
  static const List<String> _frenchUiWords = [
    'accueil',
    'bienvenue',
    'connexion',
    'deconnexion',
    'déconnexion',
    'identifiant',
    'motdepasse',
    'mot de passe',
    'soumettre',
    'valider',
    'annuler',
    'retour',
    'menu',
    'parametres',
    'paramètres',
    'inscription',
    'email',
    'courriel',
    'merci',
    'bonjour',
    'salut',
    'oui',
    'non',
    'erreur',
    'chargement',
    'rechercher',
    'recherche',
  ];

  static const List<String> _englishUiWords = [
    'welcome',
    'logout',
    'login',
    'sign in',
    'sign out',
    'password',
    'username',
    'submit',
    'cancel',
    'settings',
    'home',
    'loading',
    'search',
    'error',
    'email',
  ];

  static LanguageDetectionResult detectLanguages(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const LanguageDetectionResult(
        primaryCode: 'unknown',
        rankedCodes: ['unknown'],
      );
    }

    final score = <String, int>{'fr': 0, 'en': 0, 'ar': 0};
    final arabicCharRegex = RegExp(r'[\u0600-\u06FF]');
    final frenchAccentRegex = RegExp(r'[éèêàùâîôç]');

    final arabicCharCount = arabicCharRegex.allMatches(normalized).length;
    if (arabicCharCount > 0) {
      score['ar'] = score['ar']! + arabicCharCount * 3;
    }

    if (frenchAccentRegex.hasMatch(normalized)) {
      score['fr'] = score['fr']! + 4;
    }

    for (final w in _frenchUiWords) {
      if (w.contains(' ')) {
        if (normalized.contains(w)) score['fr'] = score['fr']! + 5;
      } else {
        if (RegExp(
          r'(^|[^a-zàâäéèêëïîôùûüç])' +
              RegExp.escape(w) +
              r'([^a-zàâäéèêëïîôùûüç]|$)',
        ).hasMatch(normalized)) {
          score['fr'] = score['fr']! + 5;
        }
      }
    }
    for (final w in _englishUiWords) {
      if (w.contains(' ')) {
        if (normalized.contains(w)) score['en'] = score['en']! + 5;
      } else {
        if (RegExp(
          r'(^|[^a-z])' + RegExp.escape(w) + r'([^a-z]|$)',
        ).hasMatch(normalized)) {
          score['en'] = score['en']! + 5;
        }
      }
    }

    const frenchHints = [
      ' le ',
      ' la ',
      ' les ',
      ' des ',
      ' une ',
      ' un ',
      ' est ',
      ' avec ',
      ' pour ',
      ' et ',
      ' dans ',
      ' sur ',
      ' pas ',
      ' plus ',
      ' vous ',
      ' nous ',
    ];
    const englishHints = [
      ' the ',
      ' and ',
      ' with ',
      ' this ',
      ' that ',
      ' for ',
      ' from ',
      ' is ',
      ' are ',
      ' of ',
      ' to ',
      ' in ',
      ' not ',
      ' you ',
      ' we ',
    ];
    const arabicHints = [' من ', ' في ', ' على ', ' هذا ', ' هذه ', ' الى '];

    final padded = ' $normalized ';
    score['fr'] =
        score['fr']! + frenchHints.where((w) => padded.contains(w)).length * 2;
    score['en'] =
        score['en']! + englishHints.where((w) => padded.contains(w)).length * 2;
    score['ar'] =
        score['ar']! + arabicHints.where((w) => padded.contains(w)).length * 2;

    final ranked = score.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topScore = ranked.first.value;
    if (topScore == 0) {
      return const LanguageDetectionResult(
        primaryCode: 'unknown',
        rankedCodes: ['unknown'],
      );
    }

    final rankedCodes = ranked
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList(growable: false);

    return LanguageDetectionResult(
      primaryCode: rankedCodes.first,
      rankedCodes: rankedCodes,
    );
  }
}
