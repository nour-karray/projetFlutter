# smartscan_mlkit

Application Flutter **SmartScan ML Kit** : scan d’image, OCR, détection de langue, historique et paramètres (thème, langue UI, notifications).

## Documentation du projet

- **[DOCUMENTATION.md](DOCUMENTATION.md)** — guide complet : objectif, évolution, architecture, packages, services externes (OCR.Space, ML Kit), plateformes, lancement.
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — flux de données et rôle des stores.

## Démarrage rapide

```bash
flutter pub get
flutter run
```

## Backend Flask (extraction medicale Gemini)

Le projet inclut maintenant un backend Flask dans `backend/` pour extraire un JSON medical structure depuis une image, un PDF ou un texte OCR.

### Lancer le backend

```bash
cd backend
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python app.py
```

Endpoint principal: `POST /api/extract-medical-analysis`

- Accepte `multipart/form-data` avec:
  - `file` (image ou PDF, optionnel)
  - `ocr_text` (optionnel)
  - header `X-Gemini-Api-Key` (ou `gemini_api_key` en form field)
- Retourne:
  - `{"success": true, "data": {...}}` avec schema medical structure
  - ou `{"success": false, "error": "..."}` en cas d echec

## Ressources Flutter génériques

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Documentation Flutter](https://docs.flutter.dev/)
