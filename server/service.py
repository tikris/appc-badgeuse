"""Service de signature des badges Wallet : la clé du certificat Pass Type ID reste ici, jamais dans l'app.

1. L'app demande un défi (valable 5 minutes, sans base de données : signé par HMAC).
2. Elle construit le badge sur l'iPhone, puis envoie seulement le manifest.json (empreintes SHA-1 des
   fichiers, rien de lisible) avec une attestation App Attest portant sur le défi et ce manifest.
3. Le service vérifie l'attestation et renvoie la signature PKCS#7 détachée du manifest.

Rien n'est enregistré : ni manifest, ni appareil, ni adresse IP.
"""
import base64
import hashlib
import hmac
import json
import os
import re
import time
from datetime import datetime, timezone

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.serialization import pkcs7
from cryptography.x509.oid import NameOID

import attestation

BUNDLE_ID = "fr.parentsapariscentre.badgecreche"
CHALLENGE_SECONDS = 300
MANIFEST_MAX_BYTES = 4096
MANIFEST_FILE = re.compile(r"^[A-Za-z0-9@._-]{1,64}$")
SHA1_HEX = re.compile(r"^[0-9a-f]{40}$")


class RequestError(Exception):
    """Requête refusée : (code HTTP, code d'erreur court renvoyé au client)."""

    def __init__(self, status: int, code: str):
        super().__init__(code)
        self.status, self.code = status, code


class SigningService:
    def __init__(self, certificate: x509.Certificate, private_key, wwdr: x509.Certificate,
                 attest_root: x509.Certificate, environment: str = "production", clock=time.time):
        if environment not in attestation.AAGUID:
            raise ValueError(f"environnement App Attest inconnu : {environment}")
        self.certificate, self.private_key, self.wwdr = certificate, private_key, wwdr
        self.attest_root, self.environment, self.clock = attest_root, environment, clock
        subject = certificate.subject
        self.pass_type_identifier = _attribute(subject, NameOID.USER_ID)
        self.team_identifier = _attribute(subject, NameOID.ORGANIZATIONAL_UNIT_NAME)
        # Clé des défis dérivée de la clé privée : pas de secret supplémentaire à gérer.
        key_der = private_key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8,
                                            serialization.NoEncryption())
        self.challenge_key = hashlib.sha256(b"badge-creche/defi" + key_der).digest()

    @classmethod
    def from_environment(cls, folder: str) -> "SigningService":
        """Configuration Scaleway : certificat et clé en variables secrètes, racines Apple dans le paquet."""
        certificate = x509.load_der_x509_certificate(der_from_text(os.environ["PASS_CERTIFICATE_PEM"]))
        private_key = serialization.load_der_private_key(der_from_text(os.environ["PASS_PRIVATE_KEY_PEM"]), None)
        with open(os.path.join(folder, "AppleWWDRCAG4.cer"), "rb") as file:
            wwdr = x509.load_der_x509_certificate(file.read())
        with open(os.path.join(folder, "Apple_App_Attestation_Root_CA.pem"), "rb") as file:
            attest_root = x509.load_pem_x509_certificate(file.read())
        return cls(certificate, private_key, wwdr, attest_root,
                   os.environ.get("APP_ATTEST_ENVIRONMENT", "production"))

    # Défi

    def challenge(self) -> dict:
        payload = int(self.clock()).to_bytes(8, "big") + os.urandom(16)
        return {
            "challenge": _b64(payload) + "." + _b64(self._mac(payload)),
            "passTypeIdentifier": self.pass_type_identifier,
            "teamIdentifier": self.team_identifier,
        }

    def _check_challenge(self, token: str) -> None:
        try:
            payload_text, mac_text = token.split(".")
            payload, mac = _unb64(payload_text), _unb64(mac_text)
        except Exception as error:
            raise RequestError(400, "defi_invalide") from error
        if len(payload) != 24 or not hmac.compare_digest(mac, self._mac(payload)):
            raise RequestError(400, "defi_invalide")
        age = self.clock() - int.from_bytes(payload[:8], "big")
        if not -60 <= age <= CHALLENGE_SECONDS:
            raise RequestError(400, "defi_expire")

    def _mac(self, payload: bytes) -> bytes:
        return hmac.new(self.challenge_key, payload, hashlib.sha256).digest()[:16]

    # Signature

    def sign(self, request: dict) -> dict:
        try:
            token = request["challenge"]
            manifest = _unb64(request["manifest"])
            key_id = _unb64(request["keyId"])
            attestation_object = _unb64(request["attestation"])
        except Exception as error:
            raise RequestError(400, "requete_invalide") from error
        self._check_challenge(token)
        _check_manifest(manifest)
        client_data_hash = hashlib.sha256(token.encode() + manifest).digest()
        try:
            attestation.verify(
                attestation_object, key_id, client_data_hash,
                app_id=f"{self.team_identifier}.{BUNDLE_ID}", root=self.attest_root,
                environment=self.environment, now=datetime.fromtimestamp(self.clock(), timezone.utc),
            )
        except attestation.AttestationError as error:
            raise RequestError(403, "attestation_refusee") from error
        signature = (
            pkcs7.PKCS7SignatureBuilder()
            .set_data(manifest)
            .add_signer(self.certificate, self.private_key, hashes.SHA256())
            .add_certificate(self.wwdr)
            .sign(serialization.Encoding.DER, [pkcs7.PKCS7Options.DetachedSignature,
                                               pkcs7.PKCS7Options.Binary,
                                               pkcs7.PKCS7Options.NoCapabilities])
        )
        return {"signature": base64.b64encode(signature).decode()}


def _check_manifest(manifest: bytes) -> None:
    """Un manifest de pass, et rien d'autre : le service ne signe pas des données arbitraires."""
    if len(manifest) > MANIFEST_MAX_BYTES:
        raise RequestError(400, "manifest_invalide")
    try:
        entries = json.loads(manifest)
    except ValueError as error:
        raise RequestError(400, "manifest_invalide") from error
    if (not isinstance(entries, dict) or "pass.json" not in entries or len(entries) > 20
            or not all(isinstance(name, str) and MANIFEST_FILE.match(name)
                       and isinstance(digest, str) and SHA1_HEX.match(digest)
                       for name, digest in entries.items())):
        raise RequestError(400, "manifest_invalide")


def der_from_text(text: str) -> bytes:
    """PEM ou base64 seul, mise en forme perdue au copier-coller comprise (champ d'une ligne, espaces)."""
    body = re.sub(r"-----(BEGIN|END)[A-Z ]*-----", "", text)
    return base64.b64decode(re.sub(r"[^A-Za-z0-9+/=]", "", body), validate=True)


def _attribute(name: x509.Name, oid: x509.ObjectIdentifier) -> str:
    values = name.get_attributes_for_oid(oid)
    if not values:
        raise ValueError(f"certificat Pass Type ID sans {oid._name}")
    return values[0].value


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _unb64(text: str) -> bytes:
    """Base64 standard ou « URL », avec ou sans remplissage."""
    if not isinstance(text, str):
        raise ValueError("texte attendu")
    text = text.replace("-", "+").replace("_", "/")
    return base64.b64decode(text + "=" * (-len(text) % 4), validate=True)
