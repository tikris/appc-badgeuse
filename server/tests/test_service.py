"""Tests du service de signature avec de fausses chaînes de certificats (App Attest et Wallet).

    python -m unittest discover -s server/tests
"""
import base64
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import unittest.mock
from datetime import datetime, timedelta, timezone

import cbor2
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import NameOID

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import attestation  # noqa: E402
import handler  # noqa: E402
from service import BUNDLE_ID, RequestError, SigningService, der_from_text  # noqa: E402

NOW = datetime.now(timezone.utc).replace(microsecond=0)
TEAM = "TEAM123456"
MANIFEST = json.dumps({"pass.json": "a" * 40, "icon.png": "b" * 40}).encode()


def certificate(subject, issuer_name, public_key, signing_key, ca, extensions=()):
    builder = (
        x509.CertificateBuilder()
        .subject_name(subject).issuer_name(issuer_name).public_key(public_key)
        .serial_number(x509.random_serial_number())
        .not_valid_before(NOW - timedelta(days=1)).not_valid_after(NOW + timedelta(days=365))
        .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True)
    )
    for extension in extensions:
        builder = builder.add_extension(extension, critical=False)
    return builder.sign(signing_key, hashes.SHA256())


def name(common_name, attributes=()):
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)]
                     + [x509.NameAttribute(oid, value) for oid, value in attributes])


class FakeApple:
    """Racine App Attest, intermédiaire, et appareil qui atteste ses clés comme le ferait iOS."""

    def __init__(self):
        self.root_key = ec.generate_private_key(ec.SECP384R1())
        self.root = certificate(name("Fausse racine App Attest"), name("Fausse racine App Attest"),
                                self.root_key.public_key(), self.root_key, ca=True)
        self.intermediate_key = ec.generate_private_key(ec.SECP384R1())
        self.intermediate = certificate(name("Faux intermédiaire"), self.root.subject,
                                        self.intermediate_key.public_key(), self.root_key, ca=True)

    def attest(self, client_data_hash, app_id=f"{TEAM}.{BUNDLE_ID}", aaguid=b"appattest" + b"\x00" * 7,
               counter=0, issuer=None):
        key = ec.generate_private_key(ec.SECP256R1())
        point = key.public_key().public_bytes(serialization.Encoding.X962,
                                              serialization.PublicFormat.UncompressedPoint)
        key_id = hashlib.sha256(point).digest()
        auth_data = (hashlib.sha256(app_id.encode()).digest() + b"\x40" + counter.to_bytes(4, "big")
                     + aaguid + len(key_id).to_bytes(2, "big") + key_id + b"\xa0")
        nonce = hashlib.sha256(auth_data + client_data_hash).digest()
        extension = x509.UnrecognizedExtension(attestation.NONCE_OID,
                                               bytes([0x30, 0x24, 0xA1, 0x22, 0x04, 0x20]) + nonce)
        issuer_cert, issuer_key = issuer or (self.intermediate, self.intermediate_key)
        credential = certificate(name("Clé attestée"), issuer_cert.subject, key.public_key(), issuer_key,
                                 ca=False, extensions=[extension])
        statement = {
            "fmt": "apple-appattest",
            "attStmt": {"x5c": [credential.public_bytes(serialization.Encoding.DER),
                                issuer_cert.public_bytes(serialization.Encoding.DER)], "receipt": b""},
            "authData": auth_data,
        }
        return key_id, cbor2.dumps(statement)


class SigningServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.apple = FakeApple()
        wwdr_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        cls.wwdr = certificate(name("Faux WWDR"), name("Faux WWDR"), wwdr_key.public_key(), wwdr_key, ca=True)
        cls.pass_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        pass_name = name("Pass Type ID: pass.test.badge", [(NameOID.USER_ID, "pass.test.badge"),
                                                          (NameOID.ORGANIZATIONAL_UNIT_NAME, TEAM)])
        cls.pass_certificate = certificate(pass_name, cls.wwdr.subject, cls.pass_key.public_key(),
                                           wwdr_key, ca=False)

    def service(self, clock=NOW.timestamp(), environment="production"):
        return SigningService(self.pass_certificate, self.pass_key, self.wwdr, self.apple.root,
                              environment, clock=lambda: clock)

    def request(self, service, manifest=MANIFEST, **attest_options):
        token = service.challenge()["challenge"]
        key_id, attestation_object = self.apple.attest(hashlib.sha256(token.encode() + manifest).digest(),
                                                       **attest_options)
        return {
            "challenge": token,
            "manifest": base64.b64encode(manifest).decode(),
            "keyId": base64.b64encode(key_id).decode(),
            "attestation": base64.b64encode(attestation_object).decode(),
        }

    def assertRefused(self, service, request, status, code):
        with self.assertRaises(RequestError) as caught:
            service.sign(request)
        self.assertEqual((caught.exception.status, caught.exception.code), (status, code))

    def test_challenge_gives_pass_identifiers_from_certificate(self):
        challenge = self.service().challenge()
        self.assertEqual(challenge["passTypeIdentifier"], "pass.test.badge")
        self.assertEqual(challenge["teamIdentifier"], TEAM)
        self.assertNotEqual(challenge["challenge"], self.service().challenge()["challenge"])

    @unittest.skipUnless(shutil.which("openssl"), "OpenSSL absent")
    def test_signature_is_a_valid_detached_pkcs7_of_the_manifest(self):
        service = self.service()
        signature = base64.b64decode(service.sign(self.request(service))["signature"])
        with tempfile.TemporaryDirectory() as folder:
            paths = {name: os.path.join(folder, name) for name in ("manifest.json", "signature", "wwdr.pem")}
            with open(paths["manifest.json"], "wb") as file:
                file.write(MANIFEST)
            with open(paths["signature"], "wb") as file:
                file.write(signature)
            with open(paths["wwdr.pem"], "wb") as file:
                file.write(self.wwdr.public_bytes(serialization.Encoding.PEM))
            result = subprocess.run(
                ["openssl", "cms", "-verify", "-binary", "-inform", "DER", "-in", paths["signature"],
                 "-content", paths["manifest.json"], "-CAfile", paths["wwdr.pem"], "-purpose", "any",
                 "-out", os.devnull],
                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_expired_or_forged_challenge_is_refused(self):
        request = self.request(self.service())
        self.assertRefused(self.service(clock=NOW.timestamp() + 301), request, 400, "defi_expire")
        payload, mac = request["challenge"].split(".")
        forged = dict(request, challenge=payload + "." + ("A" if mac[0] != "A" else "B") + mac[1:])
        self.assertRefused(self.service(), forged, 400, "defi_invalide")

    def test_manifest_changed_after_attestation_is_refused(self):
        service = self.service()
        request = self.request(service)
        other = json.dumps({"pass.json": "c" * 40}).encode()
        self.assertRefused(service, dict(request, manifest=base64.b64encode(other).decode()),
                           403, "attestation_refusee")

    def test_attestation_from_another_app_root_environment_or_key_is_refused(self):
        service = self.service()
        self.assertRefused(service, self.request(service, app_id=f"{TEAM}.autre.app"), 403, "attestation_refusee")
        self.assertRefused(service, self.request(service, aaguid=b"appattestdevelop"), 403, "attestation_refusee")
        self.assertRefused(service, self.request(service, counter=1), 403, "attestation_refusee")
        other = FakeApple()
        self.assertRefused(service, self.request(service, issuer=(other.intermediate, other.intermediate_key)),
                           403, "attestation_refusee")
        request = self.request(service)
        self.assertRefused(service, dict(request, keyId=base64.b64encode(b"\x00" * 32).decode()),
                           403, "attestation_refusee")

    def test_development_environment_accepts_development_builds_only(self):
        service = self.service(environment="development")
        service.sign(self.request(service, aaguid=b"appattestdevelop"))
        self.assertRefused(service, self.request(service), 403, "attestation_refusee")

    def test_only_pass_manifests_are_signed(self):
        service = self.service()
        for manifest in [b"pas du json", b"[]", json.dumps({"icon.png": "b" * 40}).encode(),
                         json.dumps({"pass.json": "pas une empreinte"}).encode(),
                         json.dumps({"../pass.json": "a" * 40, "pass.json": "a" * 40}).encode()]:
            self.assertRefused(service, self.request(service, manifest=manifest), 400, "manifest_invalide")

    def test_certificate_and_key_survive_a_damaged_paste(self):
        der = self.pass_certificate.public_bytes(serialization.Encoding.DER)
        pem = self.pass_certificate.public_bytes(serialization.Encoding.PEM).decode()
        key = self.pass_key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                          serialization.NoEncryption()).decode()
        for text in [pem, pem.replace("\n", " "), pem.replace("\n", ""), base64.b64encode(der).decode()]:
            self.assertEqual(der_from_text(text), der)
        loaded = serialization.load_der_private_key(der_from_text(key.replace("\n", " ")), None)
        self.assertEqual(loaded.private_numbers(), self.pass_key.private_numbers())

    def test_configuration_from_scaleway_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            with open(os.path.join(folder, "AppleWWDRCAG4.cer"), "wb") as file:
                file.write(self.wwdr.public_bytes(serialization.Encoding.DER))
            with open(os.path.join(folder, "Apple_App_Attestation_Root_CA.pem"), "wb") as file:
                file.write(self.apple.root.public_bytes(serialization.Encoding.PEM))
            key = self.pass_key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8,
                                              serialization.NoEncryption())
            variables = {
                "PASS_CERTIFICATE_PEM": base64.b64encode(
                    self.pass_certificate.public_bytes(serialization.Encoding.DER)).decode(),
                "PASS_PRIVATE_KEY_PEM": base64.b64encode(key).decode(),
            }
            with unittest.mock.patch.dict(os.environ, variables):
                service = SigningService.from_environment(folder)
        self.assertEqual((service.pass_type_identifier, service.environment), ("pass.test.badge", "production"))

    def test_http_handler(self):
        handler._service = self.service()
        challenge = handler.handle({"httpMethod": "GET"}, {})
        self.assertEqual(challenge["statusCode"], 200)
        self.assertEqual(challenge["headers"]["Cache-Control"], "no-store")
        ok = handler.handle({"httpMethod": "POST", "body": json.dumps(self.request(handler._service))}, {})
        self.assertEqual(ok["statusCode"], 200)
        self.assertIn("signature", json.loads(ok["body"]))
        refused = handler.handle({"httpMethod": "POST", "body": "{}"}, {})
        self.assertEqual((refused["statusCode"], json.loads(refused["body"])), (400, {"error": "requete_invalide"}))
        self.assertEqual(handler.handle({"httpMethod": "DELETE"}, {})["statusCode"], 405)


if __name__ == "__main__":
    unittest.main()
