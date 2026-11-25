"""UNPUBLISHED App Attest receipt verifier prototype.

Requires real Apple receipt fixtures and review before production. CMS signatures
are checked by OpenSSL; the signer chain is separately checked against the caller's
pinned Apple root. Receipt bytes stay in memory; only public signer certs use a
private temporary directory. Never log receipt bytes or decoded device metadata.
"""
from datetime import datetime, timezone
import hmac
from pathlib import Path
import subprocess
import tempfile
import asn1
from OpenSSL import crypto
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import pkcs7


def _one(data, expected):
    decoder = asn1.Decoder(); decoder.start(data)
    tag, value = decoder.read()
    if tag is None or tag.nr != expected or not decoder.eof(): raise ValueError('invalid ASN.1 value')
    return value


def _fields(payload):
    if not isinstance(payload, bytes) or not 1 <= len(payload) <= 65536: raise ValueError('invalid receipt payload')
    decoder=asn1.Decoder(); decoder.start(payload)
    if decoder.peek() is None or decoder.peek().nr != asn1.Numbers.Set: raise ValueError('invalid receipt set')
    decoder.enter(); fields={}
    while not decoder.eof():
        if decoder.peek().nr != asn1.Numbers.Sequence: raise ValueError('invalid receipt field')
        decoder.enter()
        typ, version, data = decoder.read(), decoder.read(), decoder.read()
        if (typ[0].nr != asn1.Numbers.Integer or version[0].nr != asn1.Numbers.Integer or
            data[0].nr != asn1.Numbers.OctetString or not decoder.eof() or typ[1] in fields):
            raise ValueError('invalid receipt field contents')
        fields[typ[1]]=data[1]
        decoder.leave()
    decoder.leave()
    if not decoder.eof(): raise ValueError('trailing receipt content')
    return fields


def _text(data):
    # Apple's live App Attest receipts put UTF-8 text directly in the outer
    # OCTET STRING. Accept nested ASN.1 strings as well for existing fixtures.
    try:
        raw = data.decode('utf-8')
        if raw and all(character.isprintable() for character in raw):
            return raw
    except UnicodeDecodeError:
        pass
    decoder=asn1.Decoder(); decoder.start(data)
    tag,value=decoder.read()
    if tag is None or tag.nr not in (asn1.Numbers.UTF8String, asn1.Numbers.IA5String, asn1.Numbers.PrintableString) or not decoder.eof() or not isinstance(value,str):
        raise ValueError('invalid receipt text')
    return value


def verify_receipt(receipt, app_id, expected_public_key_der, now, root_der, openssl='/usr/bin/openssl'):
    """Return True only after signature, pinned chain, fields, key and time pass."""
    if not isinstance(receipt, bytes) or not 1 <= len(receipt) <= 32768: return False
    try:
        # -noverify skips OpenSSL's default system trust store only. We then verify
        # the returned signer explicitly against the pinned Apple root below.
        with tempfile.TemporaryDirectory(prefix='maybii-attest-') as directory:
            signer_path=Path(directory)/'signers.pem'
            result=subprocess.run([openssl,'cms','-verify','-inform','DER','-binary','-noverify','-signer',str(signer_path)],
                                  input=receipt,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=10,check=False)
            if result.returncode != 0 or len(result.stdout) > 65536 or not signer_path.is_file(): return False
            signer_pem=signer_path.read_bytes()
            if signer_pem.count(b'-----BEGIN CERTIFICATE-----') != 1: return False
            signer=crypto.load_certificate(crypto.FILETYPE_PEM,signer_pem)
            root=crypto.load_certificate(crypto.FILETYPE_ASN1,root_der)
            certificates=pkcs7.load_der_pkcs7_certificates(receipt)
            chain=[]
            for certificate in certificates:
                encoded=certificate.public_bytes(serialization.Encoding.DER)
                if encoded != crypto.dump_certificate(crypto.FILETYPE_ASN1,signer):
                    chain.append(crypto.load_certificate(crypto.FILETYPE_ASN1,encoded))
            store=crypto.X509Store(); store.add_cert(root)
            crypto.X509StoreContext(store,signer,chain).verify_certificate()
            fields=_fields(result.stdout)
            if _text(fields[2]) != app_id or _text(fields[6]) != 'ATTEST': return False
            created=datetime.fromisoformat(_text(fields[12]).replace('Z','+00:00'))
            if created.tzinfo is None: return False
            age=now-created.astimezone(timezone.utc).timestamp()
            if age < -60 or age > 300: return False
            key_data=fields[3]
            try:
                key=x509.load_der_x509_certificate(key_data).public_key()
            except ValueError:
                key=serialization.load_der_public_key(key_data)
            actual=key.public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)
            return hmac.compare_digest(actual,expected_public_key_der)
    except Exception:
        # Never include a receipt or exception details in logs or responses.
        return False
