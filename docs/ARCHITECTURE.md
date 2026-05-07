# Architecture technique — SmartScan ML Kit

## Flux principal : un scan réussi

```
Utilisateur (ScanScreen)
    │
    ├─► image_picker → XFile + readAsBytes()
    │
    ├─► ScanResultStore.startProcessing(path, bytes)
    │       → image affichée, état « en cours »
    │
    ├─► OcrService.extractText(imagePath, imageBytes)
    │       ├─ Hors Web → google_mlkit_text_recognition (fichier local)
    │       └─ Web → erreur explicite (ML Kit non disponible)
    │
    ├─► LanguageDetector.detectLanguages(texte)
    │       → primaryCode + rankedCodes (fr, en, ar, unknown)
    │
    ├─► ScanResultStore.complete(texte, languageCode, languageCodes)
    │
    ├─► encodeThumbnailPng(bytes) → base64 (historique)
    │
    ├─► ScanHistoryStore.addEntry(...) → SharedPreferences (JSON)
    │
    ├─► Navigation → onglet Résultat (index 2)
    │
    └─► _feedback() : SystemSound + HapticFeedback (uniquement si !kIsWeb)
```

## Composants racine (`app.dart`)

- **`SmartScanApp`** : `ThemeMode`, `Locale` (code `fr` / `en` / `ar`), chargement/sauvegarde des préférences, timer de rappel « notifications ».
- **`MainNavigation`** : `IndexedStack` implicite via liste de pages + `NavigationBar`.
- Instances partagées : `ScanResultStore`, `ScanHistoryStore`, `OcrService`.

## Stores (ChangeNotifier)

| Store | Responsabilité |
|-------|----------------|
| `ScanResultStore` | Dernier scan : `imageBytes`, `extractedText`, `detectedLanguageCode`, `detectedLanguageCodes`, `errorMessage`, `isProcessing`. |
| `ScanHistoryStore` | Liste `ScanHistoryEntry` (texte, langues, date ISO, `imageBase64` optionnel), sérialisation JSON. |

Les écrans **Résultat** et **Historique** utilisent `AnimatedBuilder` / `Listenable` pour se rafraîchir quand les stores notifient.

## Couche OCR (`ocr_service.dart`)

- **Entrée unique** : `extractText({ imagePath, imageBytes })`.
- **Branche mobile** : `TextRecognizer` ML Kit + `InputImage.fromFilePath`.
- **Branche non mobile** : envoi des `imageBytes` à OCR.Space, parsing du JSON (`ParsedResults` / `ParsedText`).

## Internationalisation

- **UI custom** : `AppLocalizations` (map par code langue) pour libellés métiers.
- **Material** : `flutter_localizations` + `supportedLocales` pour composants système cohérents avec la locale choisie.

## Séparation des responsabilités

- **`features/*`** : Widgets, navigation locale, `SnackBar`, appels aux stores/services.
- **`core/*`** : Pas de dépendance aux écrans ; logique réutilisable et testable isolément (OCR, détection langue, persistance historique).

---

Retour au guide général : [`../DOCUMENTATION.md`](../DOCUMENTATION.md).
