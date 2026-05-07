from __future__ import annotations

import base64
import json
import logging
import os
from pathlib import Path
from typing import Any

import requests

from services.schemas import normalize_medical_analysis_payload

LOGGER = logging.getLogger("smartscan.backend.gemini")

DEFAULT_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
FALLBACK_MODELS = ("gemini-2.5-flash", "gemini-2.0-flash")


class GeminiMedicalExtractionError(Exception):
    pass


def _infer_mime_type(file_name: str | None, provided_mime: str | None) -> str:
    if provided_mime and "/" in provided_mime:
        return provided_mime
    suffix = Path(file_name or "").suffix.lower()
    if suffix == ".pdf":
        return "application/pdf"
    if suffix in {".jpg", ".jpeg"}:
        return "image/jpeg"
    if suffix == ".png":
        return "image/png"
    if suffix == ".webp":
        return "image/webp"
    return "application/octet-stream"


def _medical_extraction_prompt() -> str:
    return """
Tu es un moteur d extraction fiable de comptes-rendus d analyses medicales.
Le document peut etre en francais, bilingue (francais/arabe ou francais/anglais), partiellement lisible, ou contenir du bruit OCR.

TACHE:
1) Identifier:
   - nom_patient
   - nom_medecin_demandeur
   - date
2) Detecter automatiquement TOUTES les analyses presentes.
3) Pour chaque analyse, extraire:
   - analyse (texte tel qu il apparait, sans invention)
   - valeur (texte exact de la valeur; null si absent)
   - unite (texte exact de l unite; null si absente)

CONTRAINTES:
- Ne rien inventer.
- Si incertain ou absent, mettre null.
- Si plusieurs valeurs/unites existent pour une meme analyse, creer plusieurs lignes.
- Conserver les analyses telles qu elles apparaissent dans le document.
- Si document flou/partiel, extraire seulement ce qui est fiable.
- Retourner STRICTEMENT un JSON valide, sans markdown, sans explication.

SCHEMA JSON OBLIGATOIRE:
{
  "document_type": "analyse_medicale",
  "patient_medecin": {
    "nom_patient": string|null,
    "nom_medecin_demandeur": string|null,
    "date": string|null
  },
  "resultats_analyses": [
    {
      "analyse": string,
      "valeur": string|null,
      "unite": string|null
    }
  ]
}
""".strip()


def _clean_json_payload(raw_text: str) -> str:
    cleaned = raw_text.replace("```json", "").replace("```", "").strip()
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise GeminiMedicalExtractionError("No valid JSON found in Gemini response.")
    return cleaned[start : end + 1]


def _build_parts(ocr_text: str, file_bytes: bytes | None, file_name: str | None, mime_type: str | None) -> list[dict[str, Any]]:
    parts: list[dict[str, Any]] = [{"text": _medical_extraction_prompt()}]
    if ocr_text.strip():
        parts.append({"text": f"Texte OCR fourni:\n{ocr_text.strip()}"})
    if file_bytes:
        final_mime = _infer_mime_type(file_name=file_name, provided_mime=mime_type)
        parts.append(
            {
                "inline_data": {
                    "mime_type": final_mime,
                    "data": base64.b64encode(file_bytes).decode("ascii"),
                }
            }
        )
    return parts


def _call_gemini(api_key: str, model: str, parts: list[dict[str, Any]]) -> dict[str, Any]:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    body = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "temperature": 0.0,
            "responseMimeType": "application/json",
            "maxOutputTokens": 2048,
        },
    }
    response = requests.post(url, json=body, timeout=50)
    if response.status_code != 200:
        raise GeminiMedicalExtractionError(
            f"Gemini HTTP error {response.status_code}: {response.text[:300]}"
        )
    try:
        return response.json()
    except json.JSONDecodeError as exc:
        raise GeminiMedicalExtractionError("Invalid JSON returned by Gemini API.") from exc


def _extract_candidate_text(response_json: dict[str, Any]) -> str:
    candidates = response_json.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        raise GeminiMedicalExtractionError("Gemini returned no candidates.")
    first = candidates[0] if isinstance(candidates[0], dict) else {}
    content = first.get("content") if isinstance(first, dict) else {}
    parts = content.get("parts") if isinstance(content, dict) else []
    if not isinstance(parts, list) or not parts:
        raise GeminiMedicalExtractionError("Gemini returned empty content.")
    text_parts = []
    for part in parts:
        if isinstance(part, dict) and isinstance(part.get("text"), str):
            text_parts.append(part["text"])
    output = "\n".join(text_parts).strip()
    if not output:
        raise GeminiMedicalExtractionError("Gemini output text is empty.")
    return output


def extract_medical_analysis_with_gemini(
    *,
    api_key: str,
    ocr_text: str,
    file_bytes: bytes | None = None,
    file_name: str | None = None,
    mime_type: str | None = None,
) -> dict[str, Any]:
    parts = _build_parts(
        ocr_text=ocr_text,
        file_bytes=file_bytes,
        file_name=file_name,
        mime_type=mime_type,
    )
    models = [DEFAULT_MODEL, *[m for m in FALLBACK_MODELS if m != DEFAULT_MODEL]]
    last_error: Exception | None = None

    for model in models:
        try:
            LOGGER.info("Trying Gemini model: %s", model)
            response_json = _call_gemini(api_key=api_key, model=model, parts=parts)
            candidate_text = _extract_candidate_text(response_json)
            parsed = json.loads(_clean_json_payload(candidate_text))
            return normalize_medical_analysis_payload(parsed)
        except (GeminiMedicalExtractionError, json.JSONDecodeError, ValueError) as exc:
            LOGGER.warning("Model %s extraction failed: %s", model, exc)
            last_error = exc

    raise GeminiMedicalExtractionError(
        f"Medical extraction failed after trying models {models}. Last error: {last_error}"
    )
