> Application Flutter Android de scan et d'analyse de documents médicaux.  
> Version documentée : 1.0.0

## Table des matières

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture du projet](#2-architecture-du-projet)
3. [Flux de données complet](#3-flux-de-données-complet)
4. [Fichiers — rôle de chacun](#4-fichiers--rôle-de-chacun)
5. [Firebase — comment c'est branché](#5-firebase--comment-cest-branché)
6. [Internationalisation](#6-internationalisation)
7. [Ce qui fonctionne vs ce qui ne fonctionne pas](#7-ce-qui-fonctionne-vs-ce-qui-ne-fonctionne-pas)
8. [Dépendances pubspec expliquées](#8-dépendances-pubspec-expliquées)
9. [Backend Python](#9-backend-python)
10. [Lancer le projet](#10-lancer-le-projet)

---

## 1. Vue d'ensemble

SmartScan ML Kit permet à l'utilisateur de :

1. **Scanner** un document médical (photo caméra ou galerie)
2. **Extraire le texte** automatiquement via OCR (Google ML Kit, offline sur Android)
3. **Détecter la langue** du texte (français, anglais, arabe)
4. **Analyser médicalement** le rapport via Gemini AI (clé API utilisateur)
5. **Exporter** un PDF du rapport analysé (partagé via Android share sheet)
6. **Consulter l'historique** des scans précédents (local + synchronisé Firestore)

---

## 2. Architecture du projet

```
smartscan_mlkit/
├── lib/
│   ├── main.dart                  # Point d'entrée + FirebaseBootstrap
│   ├── firebase_options.dart      # Config Firebase (auto-généré)
│   ├── app.dart                   # Root widget + navigation
│   │
│   ├── core/                        # Logique métier (sans UI)
│   │   ├── app_localizations.dart   # Traductions fr/en/ar
│   │   ├── auth_service.dart        # Firebase Auth (anonyme)
│   │   ├── firebase_bootstrap.dart  # Initialisation Firebase
│   │   ├── image_thumbnail.dart     # Compression image → PNG miniature
│   │   ├── language_detector.dart   # Détection langue par score lexical
│   │   ├── medical_ai_service.dart  # Appels Gemini AI (HTTP direct)
│   │   ├── medical_analysis_api_service.dart  # [DÉSACTIVÉ] Backend Python
│   │   ├── medical_ocr_postprocessor.dart     # Nettoyage texte OCR
│   │   ├── medical_report_pdf_service.dart    # Génération PDF + partage
│   │   ├── ocr_service.dart         # OCR via ML Kit (Android/iOS, hors Web)
│   │   ├── scan_history_store.dart  # Historique local + Firestore
│   │   └── scan_result_store.dart   # État du scan en cours
│   │
│   ├── features/                    # Écrans de l'application
│   │   ├── home/home_screen.dart    # Accueil
│   │   ├── scan/scan_screen.dart    # Capture + lancement OCR
│   │   ├── result/result_screen.dart# Résultat OCR + analyse Gemini
│   │   ├── history/history_screen.dart  # Historique des scans
│   │   └── settings/settings_screen.dart # Paramètres
│   │
│   ├── models/medical_report.dart   # Modèle de données (rapport médical)
│   ├── parsers/medical_report_parser.dart  # Parser regex du texte OCR
│   ├── services/
│   │   ├── document_classifier_service.dart  # Classifie le type de doc
│   │   └── medical_report_pipeline_service.dart  # Orchestre classifier+parser
│   ├── utils/
│   │   ├── medical_dictionary.dart  # Listes de mots-clés médicaux
│   │   └── medical_regex.dart       # Expressions régulières médicales
│   └── widgets/medical_report_widgets.dart  # Widgets d'affichage rapport
│
├── backend/                         # Serveur Python Flask (optionnel)
│   ├── app.py                       # Routes Flask
│   └── services/
│       ├── gemini_extractor.py      # Extraction Gemini côté serveur
│       └── ocr_proxy_service.py     # Proxy OCR.Space
│
└── android/                         # Config Android native
```

Un flux OCR condensé (aligné sur le code actuel) est aussi dans [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## 3. Flux de données complet

### 3.1 — Scan d'une image (flux principal)

```
[ScanScreen]
    │
    ├─ Utilisateur appuie sur "Prendre une photo" ou "Galerie"
    │
    ├─► image_picker.pickImage() → XFile
    │
    ├─► image.readAsBytes() → Uint8List (bytes bruts)
    │
    ├─► ScanResultStore.startProcessing()
    │       → État : isProcessing = true
    │       → ResultScreen se rafraîchit (AnimatedBuilder)
    │
    ├─► (PDF) Si extension .pdf → échec explicite + SnackBar, pas d'OCR bytes
    │
    ├─► OcrService.extractText(imagePath, imageBytes)
    │       → TextRecognizer (ML Kit) sur le fichier local (hors Web)
    │       → Retourne OcrServiceResult { success, text }
    │
    ├─► MedicalOcrPostprocessor.normalize(text)
    │       → Corrige erreurs OCR courantes (ex: "CHOLESTER0L" → "CHOLESTEROL")
    │       → Nettoie espaces, sauts de ligne multiples
    │
    ├─► LanguageDetector.detectLanguages(cleanedText)
    │       → Score lexical sur mots fr/en/ar
    │       → Retourne { primaryCode: 'fr', rankedCodes: ['fr', 'en'] }
    │
    ├─► MedicalReportPipelineService.parseFromRawText()
    │       │
    │       ├─► DocumentClassifierService.detectDocumentType()
    │       │       → Score sur mots-clés médicaux (MedicalDictionary)
    │       │       → DocumentType.medicalReport si score ≥ 0.22
    │       │
    │       └─► MedicalReportParser.parse()
    │               → Extrait : LabInfo, PatientInfo, DoctorInfo, ReportInfo
    │               → Extrait les sections (ex: "BIOCHIMIE", "HEMATOLOGIE")
    │               → Extrait les analyses avec valeur, unité, référence
    │               → Retourne MedicalReport complet
    │
    ├─► ScanResultStore.complete(text, languageCode, languageCodes, report)
    │       → État : isProcessing = false, hasResult = true
    │
    ├─► encodeThumbnailPng(bytes) → PNG miniature 320px → base64 (optionnel)
    │
    ├─► ScanHistoryStore.addEntry(text, imageBase64)
    │       → Sauvegarde locale : SharedPreferences (JSON, clé v2)
    │       → Sauvegarde cloud : Firestore users/{uid}/scan_history/
    │       → Nouvelles entrées : texte OCR brut + miniature ; pas de réécriture
    │         des langues dans l'historique (champ `detectedLanguages` vide)
    │
    └─► Navigation automatique → onglet Résultat
```

### 3.2 — Analyse Gemini (optionnel, depuis ResultScreen)

```
[ResultScreen] Bouton d'analyse Gemini (section repliable)
    │
    ├─ Vérification : geminiApiKey non vide
    │
    ├─► MedicalAiService.analyzeMedicalText(ocrText)
    │       → POST https://generativelanguage.googleapis.com/v1beta/...
    │       → Prompt JSON : résumé + findings + recommandations
    │       → Retry x3 si erreur 429/500/503
    │       → Retourne MedicalAnalysisResult
    │
    ├─► MedicalAiService.extractMedicalReportEntities(ocrText)
    │       → 2ème appel Gemini : extrait nom patient, médecin, code patient
    │       → Met à jour ScanResultStore.medicalReport via copyWith()
    │
    ├─► MedicalReportPdfService.generateAnalysisPdf()
    │       → Génère PDF avec package `pdf`
    │       → Sauvegarde dans getTemporaryDirectory()
    │       → share_plus → menu partage Android natif
    │
    └─► Affichage résultat : résumé, findings, recommandations
```

> **Note :** `MedicalAnalysisApiService` (backend Python / extraction structurée) existe dans le code mais **n'est plus appelé depuis l'UI** ; l'analyse visible repose sur `MedicalAiService` uniquement.

### 3.3 — Chargement de l'historique au démarrage

```
[main.dart] → FirebaseBootstrap.initialize() → Firebase.initializeApp()
    │
[app.dart] → AuthService.initialize()
    │           → FirebaseAuth.signInAnonymously() si pas connecté
    │           → Écoute authStateChanges()
    │
    └─► ScanHistoryStore.load()
            → Lit SharedPreferences (clé scan_history_entries_v2)
            → Migration automatique depuis v1 si nécessaire
            → refreshFromCloud() : lit Firestore users/{uid}/scan_history/
            → Fusionne sans doublons (clé interne basée sur texte + date + langues)
            → Notifie HistoryScreen
---

## 4. Fichiers — rôle de chacun

### `lib/main.dart`

Point d'entrée unique. Initialise Firebase puis lance `SmartScanApp`.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const SmartScanApp());
}
```

### `lib/app.dart`

Contient notamment :

- **`SmartScanApp`** : gère `ThemeMode`, `Locale`, préférences (SharedPreferences), timer de rappel, clé Gemini. Instancie `ScanHistoryStore` et `AuthService`.
- **`MainNavigation`** : `NavigationBar` à plusieurs onglets. Instancie `ScanResultStore` et `OcrService`. Passe les dépendances aux écrans enfants.

### `lib/firebase_options.dart`

Auto-généré par `flutterfire configure`. Contient les clés Firebase par plateforme. **Ne jamais modifier manuellement.**

### `lib/core/auth_service.dart`

- Connexion **anonyme** uniquement (pas d'email/mot de passe)
- Écoute `authStateChanges()` → notifie les widgets via `ChangeNotifier`
- `uid` : identifiant unique Firebase utilisé pour isoler les données Firestore de chaque utilisateur
- Si `signInAnonymously()` échoue (ex: pas de réseau), l'app fonctionne toujours en local pour l'historique

### `lib/core/scan_history_store.dart`

- **ChangeNotifier** — les écrans qui utilisent `AnimatedBuilder(animation: store)` se rafraîchissent automatiquement
- Stockage local : JSON dans SharedPreferences, clé **`scan_history_entries_v2`**
- Stockage cloud : Firestore `users/{uid}/scan_history/` (documents individuels)
- Migration : lit aussi la clé **v1** pour ne pas perdre l'historique existant
- Limite : 50 entrées maximum (les plus récentes)
- **`addEntry({ text, imageBase64 })`** : persistance légère (texte brut + miniature base64 optionnelle). Les nouvelles entrées n'enregistrent pas les langues dans l'historique (`detectedLanguages` vide).

### `lib/core/scan_result_store.dart`

- **ChangeNotifier** — état du scan en cours
- Cycle : `startProcessing()` → `complete()` ou `fail()`
- Contient : `imageBytes` (pour afficher l'image dans ResultScreen), `extractedText`, `medicalReport`, codes de langue pour l'écran résultat

### `lib/core/ocr_service.dart`

- Sur plateformes non-Web : `TextRecognizer` de `google_mlkit_text_recognition` — **offline**
- `extractText()` : prend le chemin local du fichier image
- `extractTextFromBytes()` : **non implémenté** (stub avec message d'erreur ; PDF côté UI refusé explicitement dans `ScanScreen`)

### `lib/core/language_detector.dart`

Détection par **score lexical** : compte les mots caractéristiques de chaque langue dans le texte. Pas de ML, entièrement offline. Langues supportées : `fr`, `en`, `ar`.

### `lib/core/medical_ocr_postprocessor.dart`

Corrige les erreurs typiques des OCR sur documents médicaux algériens/français :

- `CHOLESTER0L` (zéro au lieu de O) → `CHOLESTEROL`
- Virgule décimale → point décimal
- Espaces multiples, retours à la ligne excessifs

### `lib/core/medical_ai_service.dart`

- Appels **HTTP directs** à l'API Gemini (sans backend)
- Deux méthodes : `analyzeMedicalText()` (résumé + findings) et `extractMedicalReportEntities()` (nom patient, médecin)
- Retry automatique x3 sur erreurs 429/500/503
- Modèles essayés : `gemini-2.5-flash` → `gemini-2.0-flash` en fallback
- **Nécessite une clé API Gemini** (configurée par l'utilisateur dans Paramètres)

### `lib/core/medical_analysis_api_service.dart`

**Désactivé côté UI** — Envoie des requêtes au backend Python local (`http://10.0.2.2:5000`). Ne fonctionne que sur émulateur Android, pas sur téléphone réel. Conservé pour usage futur.

### `lib/core/medical_report_pdf_service.dart`

- Génère des PDF avec le package `pdf`
- Deux types : `generateAnalysisPdf()` (résultat Gemini) et `generateStructuredReportPdf()` (données parsées)
- Sauvegarde dans `getTemporaryDirectory()`
- Partage via `share_plus` → menu natif Android (WhatsApp, Gmail, Drive...)

### `lib/core/image_thumbnail.dart`

Compresse une image en miniature PNG 320px via l'API `dart:ui`. Utilisée avant l'ajout à l'historique pour limiter la taille (base64 dans Firestore).

### `lib/core/firebase_bootstrap.dart`

Initialise Firebase une seule fois. Gère le cas où Firebase est déjà initialisé (protection contre double-init).

### `lib/models/medical_report.dart`

Modèle de données complet pour un rapport médical :

- `MedicalReport` : racine du rapport
- `LabInfo` : nom/adresse du laboratoire
- `PatientInfo` : nom patient, code, dossier, organisme
- `DoctorInfo` : médecin demandeur, médecin validateur
- `ReportInfo` : dates, numéro d'examen
- `MedicalSection` : section du rapport (ex: "BIOCHIMIE")
- `MedicalAnalysis` : une ligne d'analyse (nom, valeur, unité, référence, flag)
- `AbnormalFlag` : `low` / `high` / `normal` / `unknown`

### `lib/parsers/medical_report_parser.dart`

Parser **regex** du texte OCR. Extrait les informations structurées du texte brut :

- Utilise `MedicalDictionary` pour les listes de noms d'analyses connues
- Utilise `MedicalRegex` pour les patterns (valeurs numériques, dates, etc.)
- Résultat : `MedicalReport` avec toutes les sections remplies

### `lib/services/document_classifier_service.dart`

Classifie le type de document en comptant les mots-clés médicaux présents. Si le score dépasse 0.22, c'est un rapport médical.

### `lib/services/medical_report_pipeline_service.dart`

Orchestre `DocumentClassifierService` + `MedicalReportParser` en une seule méthode `parseFromRawText()`. C'est lui qui est appelé depuis `ScanScreen`.

### `lib/utils/medical_dictionary.dart`

Listes de :

- `knownAnalyses` : noms d'analyses biologiques connues (glycémie, cholestérol, TSH...)
- `sectionTitles` : titres de sections typiques (BIOCHIMIE, HEMATOLOGIE...)
- `medicalKeywords` : mots-clés pour la classification

### `lib/utils/medical_regex.dart`

Expressions régulières pour détecter :

- Valeurs numériques avec unités (`12.5 g/dL`)
- Plages de référence (`3.5 - 5.0`)
- Dates (`15/03/2024`)
- Noms de patients et médecins

### `lib/widgets/medical_report_widgets.dart`

Widgets réutilisables pour afficher un rapport :

- `MedicalSummaryCard` : résumé (type, confiance, nombre de sections)
- `MedicalInfoCard` : liste de champs label/valeur
- `MedicalSectionCard` : section avec tableau d'analyses
- `StatusBadge` : badge coloré Normal/Bas/Haut

---

## 5. Firebase — comment c'est branché

### Structure Firestore

```
users/
  {uid}/
    scan_history/
      {docId}/
        text: "texte OCR..."
        createdAtIso: "2024-03-15T10:30:00.000"
        imageBase64: "..."   # optionnel (miniature PNG)
        detectedLanguages: ["fr"]   # optionnel (anciennes entrées uniquement)
```

> Le package **`firebase_storage`** est présent dans `pubspec.yaml`, mais **aucun upload vers Storage n'est implémenté dans `lib/`** à ce stade : les miniatures vont dans le document Firestore en base64.

### Auth anonyme

- L'utilisateur reçoit automatiquement un UID Firebase dès le premier lancement
- Cet UID persiste tant que l'app est installée
- Si l'app est désinstallée/réinstallée, un nouvel UID est créé → perte des données cloud
- Pas d'écran de login — tout est transparent pour l'utilisateur

### Règles de sécurité recommandées

**Firestore** :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/scan_history/{doc} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

**Storage** (à activer si vous ajoutez plus tard des uploads fichier) :

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{uid}/scan_images/{file} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

---

## 6. Internationalisation

### Deux systèmes coexistent

| Système | Fichier | Usage |
|---------|---------|--------|
| Custom | `app_localizations.dart` | Tous les textes métier de l'app |
| Flutter Material | `flutter_localizations` | Composants système (DatePicker, etc.) |

### Ajouter une traduction

Dans `app_localizations.dart`, ajouter la clé dans les 3 blocs `'fr'`, `'en'`, `'ar'` :

```dart
'maCleNouvelle': 'Mon texte français',  // dans 'fr'
'maCleNouvelle': 'My English text',      // dans 'en'
'maCleNouvelle': 'نصي بالعربية',          // dans 'ar'
```

Utiliser avec : `AppLocalizations.t(localeCode, 'maCleNouvelle')`

### Passage de la locale

La locale est stockée dans `SharedPreferences` (clé `app_locale`). Elle est passée en `String localeCode` à chaque écran depuis `app.dart`. Pas de Provider/Riverpod dans le code actuel — passage manuel par constructeur.

---

## 7. Ce qui fonctionne vs ce qui ne fonctionne pas

| Fonctionnalité | Statut | Notes |
|----------------|--------|--------|
| OCR image (caméra/galerie) | Fonctionne | ML Kit offline sur Android (hors Web) |
| Détection de langue | Fonctionne | Score lexical, offline (écran résultat) |
| Parsing médical (regex) | Fonctionne | Résultats variables selon qualité OCR |
| Historique local | Fonctionne | SharedPreferences |
| Sync Firestore | Fonctionne | Nécessite connexion internet |
| Miniatures historique | Fonctionne | Base64 dans Firestore (pas d'upload Storage câblé) |
| Analyse Gemini | Fonctionne | Nécessite clé API dans Paramètres |
| Export PDF + partage | Fonctionne | Via share_plus |
| Vibration/Son | Fonctionne | Package `vibration` sur Android réel |
| Import / OCR PDF | Ne fonctionne pas | Stub `extractTextFromBytes` ; UI refuse le PDF avec message explicite |
| Backend Python | Ne fonctionne pas en prod | Uniquement sur émulateur (10.0.2.2) ; débranché de l'UI |
| Connexion Email/Google | Non implémenté | Auth anonyme uniquement |
| Mode sombre arabe (RTL) | Partiel | Locale arabe active mais layout non RTL |

---

## 8. Dépendances pubspec expliquées

| Package | Rôle | Critique |
|---------|------|----------|
| `google_mlkit_text_recognition` | OCR offline Android | Oui |
| `firebase_core` | Initialisation Firebase | Oui |
| `firebase_auth` | Auth anonyme | Oui |
| `cloud_firestore` | Base de données cloud | Oui |
| `firebase_storage` | Dépendance présente | Non câblée dans `lib/` actuellement |
| `flutter_riverpod` | State management | Installé, **non utilisé** dans le code |
| `image_picker` | Accès caméra et galerie | Oui |
| `shared_preferences` | Stockage local (préférences + historique) | Oui |
| `pdf` | Génération de fichiers PDF | Oui |
| `share_plus` | Menu de partage Android natif | Oui |
| `vibration` | Vibration sur Android réel | Oui |
| `path_provider` | Chemins de fichiers système | Oui |
| `file_picker` | Import fichiers | Installé ; **plus utilisé** dans `lib/` après retrait du flux PDF |
| `pdfx` | Rendu PDF en images | Installé ; **non utilisé** (TODO OCR bytes) |
| `image` | Manipulation d'images | Indirect |
| `http` | Appels HTTP vers Gemini API | Oui |
| `uuid` | Identifiants | Installé, **non utilisé** dans `lib/` |
| `path` | Manipulation de chemins | Oui |
| `package_info_plus` | Version de l'app dans Settings | Oui |
| `flutter_localizations` | Localisation Material widgets | Oui |
| `cupertino_icons` | Icônes iOS style | Optionnel |

---

## 9. Backend Python

### Ce que c'est

Un serveur Flask local qui expose des routes dont :

- `POST /api/extract-medical-analysis` : reçoit le texte OCR + la clé Gemini, appelle Gemini, retourne les données structurées
- `POST /api/ocr/extract` : proxy vers OCR.Space (OCR dans le cloud)
- `GET /health` : vérification de santé

### Pourquoi il n'est pas utilisé en production

L'adresse codée en dur côté client Flutter est `http://10.0.2.2:5000` — valable **uniquement sur émulateur Android** (l'émulateur voit la machine hôte via `10.0.2.2`). Sur un téléphone Samsung réel, cette adresse est inaccessible → timeout. De plus, l'**UI n'appelle plus** ce service pour l'extraction structurée.

### Comment le lancer (développement)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate       # Windows
pip install -r requirements.txt
python app.py
```

Puis lancer l'app sur **émulateur** (pas téléphone physique) si vous réactivez les appels client.

---

## 10. Lancer le projet

### Prérequis

- Flutter SDK ≥ 3.10
- Android SDK (API 34)
- Téléphone Samsung ou émulateur connecté

### Commandes

```bash
# Vérifier les devices connectés
flutter devices

# Installer les dépendances
flutter pub get

# Lancer sur le Samsung (utiliser l'ID, pas le nom)
flutter run -d R58R769N0QK

# Vérifier les erreurs de code
flutter analyze

# Build APK release
flutter build apk --release
```

### Configuration requise avant le premier lancement

1. Aller sur [console.firebase.google.com](https://console.firebase.google.com) → votre projet → **Authentication** → activer "Anonyme"
2. **Firestore** → Créer base de données → ajouter les règles de sécurité
3. **Storage** (optionnel tant qu'aucun upload n'est codé) → activer si besoin
4. Dans l'app → **Paramètres** → coller votre clé API Gemini (obtenue sur [aistudio.google.com](https://aistudio.google.com))

---

*Documentation mise à jour le 2 mai 2026 — SmartScan ML Kit v1.0.0*
