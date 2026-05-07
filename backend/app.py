import logging
import os

from flask import Flask, jsonify, request
from flask_cors import CORS

from services.gemini_extractor import GeminiMedicalExtractionError, extract_medical_analysis_with_gemini
from services.ocr_proxy_service import OcrProxyError, extract_text_with_ocr_space


def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)
    app.config["MAX_CONTENT_LENGTH"] = 15 * 1024 * 1024  # 15 MB

    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s - %(message)s",
    )
    logger = logging.getLogger("smartscan.backend")

    @app.post("/api/extract-medical-analysis")
    def extract_medical_analysis() -> tuple:
        logger.info("Medical extraction request received")
        try:
            uploaded_file = request.files.get("file")
            ocr_text = (request.form.get("ocr_text") or "").strip()
            api_key = (
                request.headers.get("X-Gemini-Api-Key")
                or request.form.get("gemini_api_key")
                or os.getenv("GEMINI_API_KEY", "")
            ).strip()

            if not api_key:
                return jsonify({"success": False, "error": "Gemini API key is missing."}), 400

            file_bytes = None
            file_name = None
            mime_type = None
            if uploaded_file:
                file_bytes = uploaded_file.read()
                file_name = uploaded_file.filename
                mime_type = uploaded_file.mimetype

            if not file_bytes and not ocr_text:
                return (
                    jsonify(
                        {
                            "success": False,
                            "error": "No input provided. Send a file (image/pdf) or ocr_text.",
                        }
                    ),
                    400,
                )

            data = extract_medical_analysis_with_gemini(
                api_key=api_key,
                ocr_text=ocr_text,
                file_bytes=file_bytes,
                file_name=file_name,
                mime_type=mime_type,
            )
            logger.info("Medical extraction succeeded")
            return jsonify({"success": True, "data": data}), 200
        except GeminiMedicalExtractionError as exc:
            logger.warning("Medical extraction failed: %s", exc)
            return jsonify({"success": False, "error": str(exc)}), 422
        except Exception:
            logger.exception("Unhandled extraction error")
            return jsonify({"success": False, "error": "Internal server error."}), 500

    @app.post("/api/ocr/extract")
    def ocr_extract() -> tuple:
        logger.info("OCR extraction request received")
        try:
            uploaded_file = request.files.get("file")
            if uploaded_file is None:
                return jsonify({"success": False, "error": "Missing file field."}), 400

            file_bytes = uploaded_file.read()
            if not file_bytes:
                return jsonify({"success": False, "error": "Uploaded file is empty."}), 400

            text = extract_text_with_ocr_space(
                file_bytes=file_bytes,
                filename=uploaded_file.filename or "scan.jpg",
            )
            return jsonify({"success": True, "text": text}), 200
        except OcrProxyError as exc:
            logger.warning("OCR proxy failed: %s", exc)
            return jsonify({"success": False, "error": str(exc)}), 422
        except Exception:
            logger.exception("Unhandled OCR error")
            return jsonify({"success": False, "error": "Internal server error."}), 500

    @app.get("/health")
    def health() -> tuple:
        return jsonify({"status": "ok"}), 200

    return app


if __name__ == "__main__":
    flask_app = create_app()
    flask_app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=False)
