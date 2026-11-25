"""UNPUBLISHED App Attest certificate prototype.

This is not a complete registration implementation. Apple receipt verification,
atomic challenge consumption/key registration and live-device tests are still
required. Do not use this module to authorize production requests.
"""
import base64
import hashlib
import hmac
import io
import json
import cbor2
from OpenSSL import crypto
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ObjectIdentifier
from attest_extensions import validation_category


def enrollment_data(challenge, app_proof):
    return json.dumps({'challenge': challenge, 'appProofSHA256': hashlib.sha256(app_proof.encode('utf-8')).hexdigest()},
                      sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii')


def verify_attestation(attestation, key_id, challenge, app_proof, app_id, root_der, environment, allowed_categories, allowed_versions):
    """Return (public key DER, receipt); does NOT verify the receipt itself."""
    if not isinstance(attestation, bytes) or not 1 <= len(attestation) <= 65536:
        raise ValueError('invalid attestation size')
    if not isinstance(challenge, str) or not 1 <= len(challenge) <= 128:
        raise ValueError('invalid challenge')
    if not isinstance(app_proof, str) or not 1 <= len(app_proof) <= 16384:
        raise ValueError('invalid app proof')
    if environment not in ('development', 'production') or not allowed_categories or not allowed_versions:
        raise ValueError('invalid verification configuration')
    try:
        key_bytes = base64.b64decode(key_id, validate=True)
        if len(key_bytes) != 32: raise ValueError('invalid key identifier')
        stream = io.BytesIO(attestation)
        obj = cbor2.CBORDecoder(stream).decode()
        if stream.read(1) or not isinstance(obj, dict) or obj.get('fmt') != 'apple-appattest':
            raise ValueError('invalid attestation format')
        statement, auth = obj['attStmt'], obj['authData']
        certs, receipt = statement['x5c'], statement['receipt']
        if not isinstance(certs, list) or len(certs) != 2 or not all(isinstance(c, bytes) for c in certs):
            raise ValueError('invalid certificate chain')
        if not isinstance(receipt, bytes) or not receipt or len(receipt) > 32768:
            raise ValueError('missing receipt')
        store = crypto.X509Store()
        store.add_cert(crypto.load_certificate(crypto.FILETYPE_ASN1, root_der))
        leaf = crypto.load_certificate(crypto.FILETYPE_ASN1, certs[0])
        intermediate = crypto.load_certificate(crypto.FILETYPE_ASN1, certs[1])
        crypto.X509StoreContext(store, leaf, [intermediate]).verify_certificate()
        cert = x509.load_der_x509_certificate(certs[0])
        public = cert.public_key()
        if not isinstance(public, ec.EllipticCurvePublicKey) or not isinstance(public.curve, ec.SECP256R1):
            raise ValueError('invalid public key')
        point = public.public_bytes(serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint)
        if not hmac.compare_digest(hashlib.sha256(point).digest(), key_bytes):
            raise ValueError('key identifier mismatch')
        if not isinstance(auth, bytes) or len(auth) < 88 or len(auth) > 8192:
            raise ValueError('invalid authenticator data')
        if not hmac.compare_digest(auth[:32], hashlib.sha256(app_id.encode('utf-8')).digest()):
            raise ValueError('app identifier mismatch')
        if auth[32] & 0x40 == 0 or int.from_bytes(auth[33:37], 'big') != 0:
            raise ValueError('invalid attestation flags or counter')
        expected_aaguid = b'appattestdevelop' if environment == 'development' else b'appattest' + bytes(7)
        if auth[37:53] != expected_aaguid or int.from_bytes(auth[53:55], 'big') != 32 or not hmac.compare_digest(auth[55:87], key_bytes):
            raise ValueError('invalid credential or environment')
        auth_stream = io.BytesIO(auth[87:])
        decoder = cbor2.CBORDecoder(auth_stream)
        cose, extensions = decoder.decode(), decoder.decode()
        if auth_stream.read(1) or not isinstance(cose, dict) or not isinstance(extensions, dict):
            raise ValueError('invalid authenticator extensions')
        if cose.get(1) != 2 or cose.get(3) != -7 or cose.get(-1) != 1 or cose.get(-2) != point[1:33] or cose.get(-3) != point[33:65]:
            raise ValueError('COSE key mismatch')
        category = validation_category(extensions.get('apple_validation_category_01'))
        version = extensions.get('apple_bundle_version_01')
        if category not in allowed_categories or version not in allowed_versions:
            raise ValueError('invalid app version or validation category')
        nonce = hashlib.sha256(auth + hashlib.sha256(enrollment_data(challenge, app_proof)).digest()).digest()
        extension = cert.extensions.get_extension_for_oid(ObjectIdentifier('1.2.840.113635.100.8.2')).value.value
        # Apple encodes SEQUENCE { [1] EXPLICIT OCTET STRING(32) }.
        if not hmac.compare_digest(extension, bytes.fromhex('3024a1220420') + nonce):
            raise ValueError('attestation nonce mismatch')
        return public.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo), receipt
    except (KeyError, TypeError, EOFError, UnicodeEncodeError, cbor2.CBORDecodeError, crypto.Error, crypto.X509StoreContextError, x509.ExtensionNotFound) as exc:
        raise ValueError('invalid attestation') from exc
