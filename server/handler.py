"""Point d'entrée Scaleway Serverless Functions (handler « handler.handle »).

GET  → défi, identifiants du type de pass et de l'équipe.
POST → {challenge, manifest, keyId, attestation} (base64) → {signature} (PKCS#7 DER en base64).

Aucun journal du contenu des requêtes : seuls les codes d'erreur sont écrits.
"""
import base64
import json
import os

from service import RequestError, SigningService

_service = None


def handle(event, context):
    global _service
    try:
        if _service is None:
            _service = SigningService.from_environment(os.path.dirname(os.path.abspath(__file__)))
        method = event.get("httpMethod", "GET")
        if method == "GET":
            return _response(200, _service.challenge())
        if method == "POST":
            body = event.get("body") or ""
            if event.get("isBase64Encoded"):
                body = base64.b64decode(body).decode()
            if len(body) > 64_000:
                raise RequestError(413, "requete_trop_grande")
            try:
                request = json.loads(body)
            except ValueError as error:
                raise RequestError(400, "requete_invalide") from error
            if not isinstance(request, dict):
                raise RequestError(400, "requete_invalide")
            return _response(200, _service.sign(request))
        return _response(405, {"error": "methode_non_autorisee"})
    except RequestError as error:
        print(f"refus {error.status} {error.code}")
        return _response(error.status, {"error": error.code})
    except Exception as error:  # noqa: BLE001
        print(f"erreur interne {type(error).__name__}")
        return _response(500, {"error": "erreur_interne"})


def _response(status: int, payload: dict) -> dict:
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json", "Cache-Control": "no-store"},
        "body": json.dumps(payload),
    }
