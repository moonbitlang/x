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
fn validate_claim_types(claims : Json) -> Unit raise JwtError {
  // TODO: improve the moonfmt
  guard claims
    is {
      "exp"? : None
      | Some(Number(_, ..)),
      "nbf"? : None
      | Some(Number(_, ..)),
      "iat"? : None
      | Some(Number(_, ..)),
      "iss"? : None
      | Some(String(_)),
      "sub"? : None
      | Some(String(_)),
      "jti"? : None
      | Some(String(_)),
      "aud"? : None
      | Some(String(_) | [..]),
      ..
    } else {
    raise InvalidToken(
      "JWT claims must be an object with valid standard claim types",
    )
  }
  match claims {
    { "exp": Number(date, ..), .. } if date.is_nan() || date.is_inf() =>
      raise InvalidToken("JWT claim 'exp' must be finite")
    { "nbf": Number(date, ..), .. } if date.is_nan() || date.is_inf() =>
      raise InvalidToken("JWT claim 'nbf' must be finite")
    { "iat": Number(date, ..), .. } if date.is_nan() || date.is_inf() =>
      raise InvalidToken("JWT claim 'iat' must be finite")
    { "aud": [.. audiences], .. } if !audiences.all(value => value is String(_)) =>
      raise InvalidToken("JWT claim 'aud' must contain only strings")
    _ => ()
  }
}

///|
fn validate_claims(
  claims : Json,
  now : Double,
  leeway : Int,
  require_exp : Bool,
  issuer : String?,
  audience : String?,
) -> Unit raise JwtError {
  validate_claim_types(claims)
  if require_exp && !(claims is { "exp": _, .. }) {
    raise InvalidToken("JWT is missing the required 'exp' claim")
  }
  if issuer is Some(expected) {
    guard claims is { "iss": String(actual), .. } && actual == expected else {
      raise InvalidToken("JWT issuer does not match")
    }
  }
  if audience is Some(expected) {
    let matches = match claims {
      { "aud": String(actual), .. } => actual == expected
      { "aud": [.. audiences], .. } =>
        audiences.any(value => value is String(actual) && actual == expected)
      _ => false
    }
    if !matches {
      raise InvalidToken("JWT audience does not match")
    }
  } else if claims is { "aud": _, .. } {
    raise InvalidToken("JWT with an 'aud' claim requires an expected audience")
  }
  // Complete the non-time JWT checks before returning a time error.
  let skew = leeway.to_double()
  if claims is { "exp": Number(exp, ..), .. } && now - skew >= exp {
    raise Expired
  }
  if claims is { "nbf": Number(nbf, ..), .. } && now + skew < nbf {
    raise NotYetValid(not_before=nbf)
  }
}
