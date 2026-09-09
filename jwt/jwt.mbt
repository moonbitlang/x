// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Algorithms supported for HMAC-signed JWTs.
pub(all) enum HmacAlgorithm {
  HS256
} derive(Eq, Debug)

///|
/// Errors from encoding or decoding a JWT.
///
/// `InvalidArgument` reports invalid keys, claims to encode, or validation options.
/// `InvalidToken` reports failed verification or claims conversion.
///
/// `Expired` means the token has expired. `NotYetValid` means its `nbf` time
/// has not been reached, allowing for leeway. `not_before` is that Unix timestamp
/// in seconds.
///
/// Time errors follow signature and other JWT checks, but precede type conversion.
/// String messages are diagnostics, not stable error codes.
pub suberror JwtError {
  InvalidArgument(String)
  InvalidToken(String)
  Expired
  NotYetValid(not_before~ : Double)
} derive(Debug)

///|
/// Signs claims as a compact JWT. No claims are added automatically.
///
/// * `claims`: must serialize to a JSON object through `ToJson`.
/// * `key`: a random secret of at least 32 bytes for HS256.
/// * `algorithm`: the signing algorithm. Currently supports HS256.
///
/// Use `Double` (Unix seconds) for `exp`, `nbf`, and `iat` fields:
/// 64-bit integers serialize as JSON strings.
/// Invalid keys or claims raise `InvalidArgument`. Tokens are limited to 64 KiB.
///
/// ```mbt check
/// test {
///   // Example key. Use a random secret in applications.
///   let key = b"0123456789abcdef0123456789abcdef"
///   let exp = @env.now().to_double() / 1000.0 + 3600.0
///   let claims : Json = { "sub": "alice", "exp": exp }
///   let _token = @jwt.encode(claims, key~, algorithm=HS256)
/// }
/// ```
pub fn[T : ToJson] encode(
  claims : T,
  key~ : Bytes,
  algorithm~ : HmacAlgorithm,
) -> String raise JwtError {
  if key.length() < 32 {
    raise InvalidArgument("HS256 requires a key of at least 32 bytes")
  }
  let text = claims.to_json().stringify()
  if !is_valid_utf16(text) {
    raise InvalidArgument("JWT claims contain invalid UTF-16")
  }
  let payload_bytes = try {
    // Validate the serialized claims because Json numbers may override their repr.
    validate_claim_types(@json.parse(text))
    @utf8.encode(text)
  } catch {
    // Claims come from the caller here, rather than an untrusted token.
    InvalidToken(message) => raise InvalidArgument(message)
    _ => raise InvalidArgument("JWT claims contain invalid JSON")
  }
  let header_text = match algorithm {
    HS256 => "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
  }
  let header = encode_segment(@utf8.encode(header_text))
  let payload = encode_segment(payload_bytes)
  let signing_input = "\{header}.\{payload}"
  // A HS256 signature occupies 43 Base64URL characters plus one dot.
  if signing_input.length() > 65536 - 44 {
    raise InvalidArgument("JWT exceeds the 64 KiB size limit")
  }
  let signature = match algorithm {
    HS256 =>
      @crypto.hmac(@crypto.SHA256::new(), key, @utf8.encode(signing_input))
  }
  "\{signing_input}.\{encode_segment(signature.unsafe_reinterpret_as_bytes())}"
}

///|
/// Verifies a compact JWT, then converts its claims using `FromJson`.
/// Use `Json` as the result type to keep all claims.
///
/// * `token`: a compact JWT of at most 64 KiB.
/// * `key`: the raw verification key. HS256 requires at least 32 bytes.
/// * `algorithm`: the expected algorithm. Must match the token's `alg`.
/// * `leeway`: nonnegative clock tolerance in seconds. Defaults to zero.
/// * `require_exp`: requires `exp` by default. Set to `false` to allow it to be absent.
///   An existing `exp` is still checked.
/// * `issuer`: requires an equal `iss` claim when supplied.
/// * `audience`: must match the `aud` string or one of its array entries.
///   Required when the token contains `aud`. Supplying it also requires `aud`.
///
/// Time checks use the system clock. An existing `nbf` is always checked.
/// Raises `JwtError` on failure, including `InvalidToken` for type conversion errors.
///
/// ```mbt check
/// test {
///   // Example key. Use a random secret in applications.
///   let key = b"0123456789abcdef0123456789abcdef"
///   let exp = @env.now().to_double() / 1000.0 + 3600.0
///   let claims : Json = { "sub": "alice", "exp": exp, "aud": "api" }
///   let token = @jwt.encode(claims, key~, algorithm=HS256)
///   let decoded : Json = @jwt.decode(token, key~, algorithm=HS256, audience="api")
///   assert_eq(decoded, claims)
/// }
/// ```
pub fn[T : @json.FromJson] decode(
  token : String,
  key~ : Bytes,
  algorithm~ : HmacAlgorithm,
  leeway? : Int = 0,
  require_exp? : Bool = true,
  issuer? : String,
  audience? : String,
) -> T raise JwtError {
  decode_at(
    token,
    key~,
    algorithm~,
    now=@env.now().to_double() / 1000.0,
    leeway~,
    require_exp~,
    issuer?,
    audience?,
  )
}

///|
fn[T : @json.FromJson] decode_at(
  token : String,
  key~ : Bytes,
  algorithm~ : HmacAlgorithm,
  now~ : Double,
  leeway? : Int = 0,
  require_exp? : Bool = true,
  issuer? : String,
  audience? : String,
) -> T raise JwtError {
  if key.length() < 32 {
    raise InvalidArgument("HS256 requires a key of at least 32 bytes")
  }
  if leeway < 0 {
    raise InvalidArgument("JWT leeway must be nonnegative")
  }
  if token.length() > 65536 {
    raise InvalidToken("JWT exceeds the 64 KiB size limit")
  }
  // Check code units before slicing or UTF-8 encoding, which assume valid
  // UTF-16. JWT compact serialization is ASCII even when its claims are not.
  for unit in token.code_units() {
    guard unit is ('A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.') else {
      raise InvalidToken("JWT contains invalid characters")
    }
  }
  let parts = token.split(".").to_array()
  guard parts is [header_segment, payload_segment, signature_segment] else {
    raise InvalidToken("JWT must contain exactly three segments")
  }
  let header = parse_jwt_json(decode_base64url(header_segment))
  let expected_algorithm = match algorithm {
    HS256 => "HS256"
  }
  guard header is { "alg": String(actual_algorithm), .. } &&
    actual_algorithm == expected_algorithm else {
    raise InvalidToken(
      "JWT header must specify the expected \{expected_algorithm} algorithm",
    )
  }
  match header {
    { "b64": true, "crit": ["b64"], .. } => ()
    { "crit": _, .. } =>
      raise InvalidToken(
        "JWT header has unsupported or invalid critical extensions",
      )
    { "b64": true, .. } => ()
    { "b64": _, .. } => raise InvalidToken("JWT header 'b64' must be true")
    _ => ()
  }
  if header is { "typ": typ, .. } {
    guard typ is String(['J' | 'j', 'W' | 'w', 'T' | 't']) else {
      raise InvalidToken("JWT header typ must be JWT")
    }
  }

  let signature = decode_base64url(signature_segment)
  if signature.length() != 32 {
    raise InvalidToken("HS256 signature must contain 32 bytes")
  }
  let payload_bytes = decode_base64url(payload_segment)
  // Authenticate exactly the received bytes, including JSON whitespace/order.
  let signing_input = @utf8.encode("\{header_segment}.\{payload_segment}")
  let expected = match algorithm {
    HS256 => @crypto.hmac(@crypto.SHA256::new(), key, signing_input)
  }
  // Compare every byte without stopping at the first differing signature byte.
  // Generated machine code is not guaranteed constant-time on every backend.
  let mut difference = 0
  for index, byte in expected {
    difference = difference | (byte.to_int() ^ signature[index].to_int())
  }
  if difference != 0 {
    raise InvalidToken("JWT signature verification failed")
  }
  let claims = parse_jwt_json(payload_bytes)
  validate_claims(claims, now, leeway, require_exp, issuer, audience)
  @json.from_json(claims) catch {
    _ => raise InvalidToken("JWT claims do not match the requested type")
  }
}
