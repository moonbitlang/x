# Timing side channels

[`verify`](bcrypt.mbt) compares all 60 hash characters with XOR/OR accumulation
and no mismatch early exit, but [`blowfish_f`](blowfish.mbt) uses
password-dependent S-box indices, so the full algorithm is not constant-time.

[Shared-cache attackers](https://yuval.yarom.org/pdfs/LiuYGHL15.pdf) can probe
cache-set activity, while
[remote attackers](https://www.bearssl.org/constanttime.html#execution-model) may
extract cache-related timing correlations from whole requests despite network
noise.

During verification, Blowfish processes the submitted password with the stored
salt and cost, so timing an attacker's own attempts does not directly observe
computations on the account's original password.
Observing another user's hashing or login operation is a different threat.

[`pyca/bcrypt`](https://github.com/pyca/bcrypt) is widely used for Python password
authentication, with integrations such as
[Django](https://docs.djangoproject.com/en/5.2/topics/auth/passwords/#using-bcrypt-with-django).
Its [4.3.0 dependency chain](https://github.com/pyca/bcrypt/blob/4.3.0/src/_bcrypt/Cargo.lock)
is `pyca/bcrypt → Keats/rust-bcrypt 0.17.0 → RustCrypto/blowfish 0.9.1`.

[RustCrypto's Blowfish](https://github.com/RustCrypto/block-ciphers/blob/blowfish-v0.9.1/blowfish/README.md)
does not claim constant-time execution, and
[Keats/rust-bcrypt uses `subtle`](https://github.com/Keats/rust-bcrypt/pull/74)
only for the final comparison.

Cache-side-channel hardening is currently deferred.
This review has not demonstrated a practical password-recovery attack against
this implementation.
