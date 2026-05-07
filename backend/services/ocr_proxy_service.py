from __future__ import annotations

import json
from typing import Any

import requests


class OcrProxyError(Exception):
    pass


OCR_SPACE_URL = "https://api.ocr.space/parse/image"
OCR_SPACE_API_KEY = "helloworld"


def _extract_error_message(payload: dict[str, Any]) -> str:
    messages = payload.get("ErrorMessage")
    if isinstance(messages, list) and messages:
        return str(messages[0])
    if isinstance(messages, str) and messages.strip():
        return messages.strip()
    return "OCR web provider failed."


def extract_text_with_ocr_space(*, file_bytes: bytes, filename: str) -> str:
    files = {"file": (filename, file_bytes)}
    data = {
        "apikey": OCR_SPACE_API_KEY,
        "language": "fre",
        "isOverlayRequired": "false",
    }
    try:
        response = requests.post(
            OCR_SPACE_URL,
            data=data,
            files=files,
            timeout=40,
        )
    except requests.RequestException as exc:
        raise OcrProxyError("Unable to reach OCR provider.") from exc

    if response.status_code != 200:
        raise OcrProxyError(f"OCR provider HTTP {response.status_code}.")

    try:
        payload = response.json()
    except json.JSONDecodeError as exc:
        raise OcrProxyError("Invalid OCR provider response.") from exc

    if payload.get("IsErroredOnProcessing") is True:
        raise OcrProxyError(_extract_error_message(payload))

    parsed_results = payload.get("ParsedResults")
    if not isinstance(parsed_results, list) or not parsed_results:
        raise OcrProxyError("No OCR result returned.")

    first = parsed_results[0] if isinstance(parsed_results[0], dict) else {}
    text = str(first.get("ParsedText") or "").strip()
    if not text:
        raise OcrProxyError("No text detected in provided file.")
    return text
