"""Vérification d'une attestation App Attest (Apple) : la requête vient bien de l'app Badge Crèche,
non modifiée, sur un vrai iPhone.

Étapes de « Validating apps that connect to your server » (Apple) :
chaîne de certificats jusqu'à la racine App Attest d'Apple, nonce = SHA-256(authData || clientDataHash)
dans le certificat, empreinte de la clé = identifiant de clé, identifiant de l'app, compteur à 0,
environnement (production ou développement), identifiant de credential = identifiant de clé.
"""
import hashlib
from datetime import datetime

import cbor2
from cryptography import x509
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

NONCE_OID = x509.ObjectIdentifier("1.2.840.113635.100.8.2")
AAGUID = {
    "production": b"appattest" + b"\x00" * 7,
    "development": b"appattestdevelop",
}


class AttestationError(Exception):
    """Attestation refusée ; le message n'est jamais renvoyé tel quel au client."""


def verify(attestation: bytes, key_id: bytes, client_data_hash: bytes, app_id: str,
           root: x509.Certificate, environment: str, now: datetime) -> None:
    try:
        statement = cbor2.loads(attestation)
        if statement.get("fmt") != "apple-appattest":
            raise AttestationError("format")
        chain = [x509.load_der_x509_certificate(der) for der in statement["attStmt"]["x5c"]]
        auth_data = statement["authData"]
    except AttestationError:
        raise
    except Exception as error:
        raise AttestationError("illisible") from error
    if not chain:
        raise AttestationError("chaîne vide")

    _verify_chain(chain, root, now)
    credential = chain[0]

    nonce = hashlib.sha256(auth_data + client_data_hash).digest()
    if _nonce(credential) != nonce:
        raise AttestationError("nonce")

    public_key = credential.public_key().public_bytes(Encoding.X962, PublicFormat.UncompressedPoint)
    if hashlib.sha256(public_key).digest() != key_id:
        raise AttestationError("clé")

    # authData : rpIdHash (32) | flags (1) | compteur (4) | aaguid (16) | longueur (2) | credentialId
    if len(auth_data) < 55:
        raise AttestationError("authData")
    if auth_data[:32] != hashlib.sha256(app_id.encode()).digest():
        raise AttestationError("app")
    if int.from_bytes(auth_data[33:37], "big") != 0:
        raise AttestationError("compteur")
    if auth_data[37:53] != AAGUID[environment]:
        raise AttestationError("environnement")
    length = int.from_bytes(auth_data[53:55], "big")
    if auth_data[55:55 + length] != key_id:
        raise AttestationError("credential")


def _verify_chain(chain: list[x509.Certificate], root: x509.Certificate, now: datetime) -> None:
    for certificate, issuer in zip(chain, chain[1:] + [root]):
        if not certificate.not_valid_before_utc <= now <= certificate.not_valid_after_utc:
            raise AttestationError("certificat expiré")
        try:
            certificate.verify_directly_issued_by(issuer)
        except Exception as error:
            raise AttestationError("chaîne") from error


def _nonce(certificate: x509.Certificate) -> bytes:
    """Extension 1.2.840.113635.100.8.2 : SEQUENCE { [1] { OCTET STRING nonce } }."""
    try:
        value = certificate.extensions.get_extension_for_oid(NONCE_OID).value.value
    except x509.ExtensionNotFound as error:
        raise AttestationError("extension nonce absente") from error
    tag, content, _ = _tlv(value)
    if tag != 0x30:
        raise AttestationError("extension nonce")
    tag, content, _ = _tlv(content)
    if tag != 0xA1:
        raise AttestationError("extension nonce")
    tag, content, _ = _tlv(content)
    if tag != 0x04:
        raise AttestationError("extension nonce")
    return content


def _tlv(data: bytes) -> tuple[int, bytes, bytes]:
    """Un élément DER : (balise, contenu, reste)."""
    if len(data) < 2:
        raise AttestationError("DER")
    tag, length, offset = data[0], data[1], 2
    if length & 0x80:
        count = length & 0x7F
        length = int.from_bytes(data[2:2 + count], "big")
        offset = 2 + count
    if len(data) < offset + length:
        raise AttestationError("DER")
    return tag, data[offset:offset + length], data[offset + length:]
