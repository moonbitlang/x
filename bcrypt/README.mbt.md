# bcrypt

Pure MoonBit implementation of bcrypt password hashing. `hash` generates `$2b$`
hashes, and `verify` accepts `$2b$` and `$2y$`.

Import `moonbitlang/x/bcrypt` and `moonbitlang/core/env` in `moon.pkg` for this
example.

```mbt nocheck
///|
test "bcrypt example" {
  guard @env.rand(16) is Some(salt) else {
    fail("Secure randomness is unavailable")
  }
  let hashed = @bcrypt.hash(password=b"password", salt~, cost=12)
  assert_true(@bcrypt.verify(password=b"password", hashed~))
  assert_false(@bcrypt.verify(password=b"wrong", hashed~))
}
```

## Validation

The test suite checks correctness against independent reference results:

- Blowfish encryption and variable key lengths use
  [Eric Young's reference vectors](https://www.schneier.com/wp-content/uploads/2015/12/vectors-2.txt).
  Salted key expansion uses
  [Go's Blowfish vectors](https://github.com/golang/crypto/blob/master/blowfish/blowfish_test.go).
- bcrypt hashing and verification use fixed vectors adapted from
  [pyca/bcrypt](https://github.com/pyca/bcrypt/blob/main/tests/test_bcrypt.py) and
  [Go bcrypt](https://github.com/golang/crypto/blob/master/bcrypt/bcrypt_test.go).
- Additional tests cover embedded NUL bytes, 71/72/73-byte passwords, digest
  tampering, and invalid salts, hash formats, costs, and Base64 characters.
