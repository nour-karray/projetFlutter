from __future__ import annotations

from typing import Any


def _clean_nullable_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() in {"null", "none", "n/a", "na", "absent", "unknown"}:
        return None
    return text


def _normalize_analysis_row(raw_row: Any) -> dict[str, Any] | None:
    if not isinstance(raw_row, dict):
        return None
    analyse = _clean_nullable_text(raw_row.get("analyse"))
    valeur = _clean_nullable_text(raw_row.get("valeur"))
    unite = _clean_nullable_text(raw_row.get("unite"))
    if analyse is None:
        return None
    return {
        "analyse": analyse,
        "valeur": valeur,
        "unite": unite,
    }


def normalize_medical_analysis_payload(raw_payload: Any) -> dict[str, Any]:
    if not isinstance(raw_payload, dict):
        raise ValueError("Gemini output is not a JSON object.")

    patient_medecin_raw = raw_payload.get("patient_medecin")
    patient_medecin = patient_medecin_raw if isinstance(patient_medecin_raw, dict) else {}
    rows_raw = raw_payload.get("resultats_analyses")

    normalized_rows = []
    if isinstance(rows_raw, list):
        for row in rows_raw:
            normalized = _normalize_analysis_row(row)
            if normalized is not None:
                normalized_rows.append(normalized)

    return {
        "document_type": "analyse_medicale",
        "patient_medecin": {
            "nom_patient": _clean_nullable_text(patient_medecin.get("nom_patient")),
            "nom_medecin_demandeur": _clean_nullable_text(
                patient_medecin.get("nom_medecin_demandeur")
            ),
            "date": _clean_nullable_text(patient_medecin.get("date")),
        },
        "resultats_analyses": normalized_rows,
    }
