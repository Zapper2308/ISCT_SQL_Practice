"""Lets accounts imported from the Flask version keep their passwords.

Flask stored werkzeug hashes such as ``scrypt:32768:8:1$<salt>$<hex>`` or
``pbkdf2:sha256:600000$<salt>$<hex>``. The import command prefixes them with ``werkzeug$`` so Django
routes them to this hasher; on the user's next successful login Django re-hashes the password with
the default (PBKDF2) hasher.
"""
import hashlib
import hmac

from django.contrib.auth.hashers import BasePasswordHasher, mask_hash


class WerkzeugPasswordHasher(BasePasswordHasher):
    algorithm = "werkzeug"

    def encode(self, password, salt):
        raise NotImplementedError("Only used to verify passwords imported from the Flask app.")

    def salt(self):
        return ""

    def decode(self, encoded):
        algorithm, method, salt, hash_hex = encoded.split("$", 3)
        assert algorithm == self.algorithm
        return {"algorithm": algorithm, "method": method, "salt": salt, "hash": hash_hex}

    @staticmethod
    def _hash(method, salt, password):
        kind, *args = method.split(":")
        if kind == "scrypt":
            n, r, p = (int(a) for a in args) if args else (2 ** 15, 8, 1)
            return hashlib.scrypt(password.encode(), salt=salt.encode(), n=n, r=r, p=p,
                                  maxmem=132 * n * r * p, dklen=64).hex()
        if kind == "pbkdf2":
            digest = args[0] if args else "sha256"
            iterations = int(args[1]) if len(args) > 1 else 600_000
            return hashlib.pbkdf2_hmac(digest, password.encode(), salt.encode(), iterations).hex()
        raise ValueError(f"Unsupported werkzeug hash method: {method}")

    def verify(self, password, encoded):
        try:
            d = self.decode(encoded)
            return hmac.compare_digest(self._hash(d["method"], d["salt"], password), d["hash"])
        except (ValueError, AssertionError):
            return False

    def safe_summary(self, encoded):
        d = self.decode(encoded)
        return {"algorithm": d["algorithm"], "method": d["method"],
                "salt": mask_hash(d["salt"], show=2), "hash": mask_hash(d["hash"])}

    def must_update(self, encoded):
        return True

    def harden_runtime(self, password, encoded):
        pass
