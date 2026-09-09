# JWT

Sign and verify compact JSON Web Tokens with an explicitly selected algorithm.
The initial implementation supports `HS256` (HMAC-SHA-256).

Claims are fields in the JWT payload, which must be a JSON object. The header
describes how the token is signed.

```mbt check
///|
struct LoginClaims {
  username : String
  exp : Double
} derive(ToJson, @json.FromJson, Eq, Debug)

///|
test "encode and decode a JWT" {
  // A deterministic test key. Applications must supply a random secret key.
  let key = b"0123456789abcdef0123456789abcdef"
  // env.now() returns milliseconds. JWT timestamps use seconds.
  let now = @env.now().to_double() / 1000.0
  let claims : LoginClaims = { username: "alice", exp: now + 3600.0, }
  let token = @jwt.encode(claims, key~, algorithm=HS256)
  let decoded : LoginClaims = @jwt.decode(token, key~, algorithm=HS256)
  assert_eq(decoded, claims)
}
```

Custom claims such as `username` can contain any JSON value, including nested
objects, arrays and `null`. Standard claims have defined meanings and types:

- [`exp`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.4): expiration time. The token is rejected at or after this time.
- [`nbf`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.5): not before. The token is rejected before this time.
- [`iat`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.6): issued at. Records when the token was issued. This package checks its type without limiting the token's age.
- [`iss`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.1): issuer. A string identifying who issued the token.
- [`sub`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.2): subject. A string identifying who or what the token is about, such as a user ID.
- [`jti`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.7): JWT ID. A unique string identifying the token. Applications can track it to detect replay.
- [`aud`](https://www.rfc-editor.org/rfc/rfc7519.html#section-4.1.3): audience. Identifies the intended recipients as a string or an array of strings.

When present, `exp`, `nbf` and `iat` must be finite numbers of seconds since the
Unix epoch. Fractional seconds are allowed.

`encode` requires your type's `ToJson` result to be an object satisfying these
rules. `decode` validates the complete claims object before converting it to
your requested type through `FromJson`.

The JWT standard makes `exp` optional. This package requires it by default when
decoding. Set `require_exp=false` to allow it to be absent. An existing `exp`
is still checked. To omit `exp` in this example, also remove it from `LoginClaims`.

Applications provide the secret key, then apply their account and authorization
rules to the verified claims. JWT payloads are encoded, not encrypted.
