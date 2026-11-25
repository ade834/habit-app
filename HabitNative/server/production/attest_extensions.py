"""Decode the signed App Attest launch-validation category."""


def validation_category(value):
    # Real iOS authenticator data encodes the UInt32 as four little-endian
    # bytes. Keep CBOR integers for compatibility with existing fixtures.
    if isinstance(value, bytes) and len(value) == 4:
        return int.from_bytes(value, 'little')
    if type(value) is int and 0 <= value <= 0xffffffff:
        return value
    return None
