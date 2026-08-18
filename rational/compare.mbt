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
/// Returns the unsigned magnitude of an `Int64`.
///
/// Unlike `Int64::abs`, this also represents `Int64::MIN_VALUE` exactly: its
/// magnitude is `2^63`, which fits in `UInt64` but not in `Int64`.
fn Int64::unsigned_abs(self : Int64) -> UInt64 {
  let bits = self.reinterpret_as_uint64()
  guard self < 0L else { bits }
  0UL - bits
}

///|
/// Reports whether the exact product of two `Int64` values fits in `Int64`.
///
/// The signed limit is `2^63 - 1` for a non-negative product and `2^63` for a
/// negative product. A leading-zero check accepts products whose combined bit
/// length is unconditionally safe. Borderline cases use division against the
/// appropriate limit, avoiding the overflowing multiplication itself.
fn int64_product_fits(x : Int64, y : Int64) -> Bool {
  let x_abs = x.unsigned_abs()
  let y_abs = y.unsigned_abs()
  guard x_abs != 0UL && y_abs != 0UL && y != 1L else { true }
  let limit = {
    guard (x < 0L) == (y < 0L) else { 0x8000_0000_0000_0000UL }
    0x7FFF_FFFF_FFFF_FFFFUL
  }
  guard x_abs.clz() + y_abs.clz() < 65 else { true }
  x_abs <= limit / y_abs
}

///|
/// Compares two non-negative fractions without cross-multiplication.
/// Denominators must be positive.
///
/// Cross-multiplication is normally the cheapest exact comparison, but the two
/// products may not fit in `Int64`. Converting every comparison to `BigInt`
/// avoids overflow but adds arbitrary-precision work and possible allocation.
/// This function is therefore used only as the overflow fallback after the
/// fixed-width fast path has been ruled out.
///
/// Each Euclidean step writes a fraction as `n / d = q + r / d`. If the two
/// quotients differ, their order decides the result. If the quotients are equal
/// and both remainders are non-zero, comparing `r1 / d1` with `r2 / d2` is
/// equivalent to comparing `d1 / r1` with `d2 / r2` in the opposite direction.
/// Replacing `(n, d)` with `(d, r)` and reversing the order repeatedly compares
/// the continued-fraction coefficients. A zero remainder terminates the exact
/// comparison.
///
/// The method cannot overflow and performs no `BigInt` allocation. Its cost is
/// `O(log(max(n, d)))`, like the Euclidean algorithm. Integer division and
/// branching make it slower than a safe cross-product in the common case, and
/// consecutive Fibonacci values require the most iterations. These tradeoffs
/// are why it remains a fallback rather than the default comparison path.
fn compare_positive_fractions(
  numerator1 : UInt64,
  denominator1 : UInt64,
  numerator2 : UInt64,
  denominator2 : UInt64,
) -> Int {
  for numerator1 = numerator1, denominator1 = denominator1, numerator2 = numerator2, denominator2 = denominator2, reverse = false {
    let quotient1 = numerator1 / denominator1
    let remainder1 = numerator1 % denominator1
    let quotient2 = numerator2 / denominator2
    let remainder2 = numerator2 % denominator2
    let quotient_order = quotient1.compare(quotient2)
    guard quotient_order == 0 else {
      let order = {
        guard reverse else { quotient_order }
        -quotient_order
      }
      break order
    }
    let remainder_order = remainder1.compare(remainder2)
    guard remainder1 != 0UL && remainder2 != 0UL else {
      let order = {
        guard reverse else { remainder_order }
        -remainder_order
      }
      break order
    }
    continue denominator1, remainder1, denominator2, remainder2, !reverse
  }
}

///|
/// Compares two `Int64` fractions using the cheapest exact available path.
///
/// The generic comparison has already established positive denominators and
/// equal numerator signs. Safe cross-products stay in `Int64`; otherwise the
/// unsigned magnitudes use continued fractions. Comparing two negative values
/// reverses the magnitude ordering.
pub impl Integral for Int64 with fn compare_fraction(
  numerator1 : Int64,
  denominator1 : Int64,
  numerator2 : Int64,
  denominator2 : Int64,
) -> Int {
  guard !(int64_product_fits(numerator1, denominator2) &&
    int64_product_fits(numerator2, denominator1)) else {
    Compare::compare(numerator1 * denominator2, numerator2 * denominator1)
  }
  let order = compare_positive_fractions(
    numerator1.unsigned_abs(),
    denominator1.reinterpret_as_uint64(),
    numerator2.unsigned_abs(),
    denominator2.reinterpret_as_uint64(),
  )
  guard numerator1 < 0L else { order }
  -order
}

///|
/// Compares two `Int` fractions after losslessly widening their products.
///
/// MoonBit `Int` is 32-bit, so every product of two `Int` values fits in
/// `Int64` and needs neither overflow detection nor arbitrary precision.
pub impl Integral for Int with fn compare_fraction(
  numerator1 : Int,
  denominator1 : Int,
  numerator2 : Int,
  denominator2 : Int,
) -> Int {
  Compare::compare(
    numerator1.to_int64() * denominator2.to_int64(),
    numerator2.to_int64() * denominator1.to_int64(),
  )
}

///|
/// Compares two `BigInt` fractions by exact cross-multiplication.
///
/// `BigInt` products do not overflow, so no fixed-width fast path or continued
/// fraction fallback is necessary.
pub impl Integral for BigInt with fn compare_fraction(
  numerator1 : BigInt,
  denominator1 : BigInt,
  numerator2 : BigInt,
  denominator2 : BigInt,
) -> Int {
  Compare::compare(numerator1 * denominator2, numerator2 * denominator1)
}

///|
/// Compares two rational numbers and returns their ordering.
///
/// Parameters:
///
/// * `self` : The first rational number to compare.
/// * `other` : The second rational number to compare.
///
/// Returns an integer indicating the relative order: negative if `self` is less
/// than `other`, zero if they are equal, and positive if `self` is greater than
/// `other`.
///
/// Example:
///
/// ```moonbit check
/// test {
///   let a = @rational.new(1L, 2L).unwrap() // 1/2
///   let b = @rational.new(2L, 3L).unwrap() // 2/3
///   inspect(Compare::compare(a, b), content="-1") // 1/2 < 2/3
///   let c = @rational.new(3L, 4L).unwrap() // 3/4
///   let d = @rational.new(3L, 4L).unwrap() // 3/4
///   inspect(Compare::compare(c, d), content="0") // 3/4 == 3/4
///   let e = @rational.new(5L, 6L).unwrap() // 5/6
///   let f = @rational.new(1L, 2L).unwrap() // 1/2
///   inspect(Compare::compare(e, f), content="1") // 5/6 > 1/2
/// }
/// ```
///
pub impl[T : Integral] Compare for Rational[T] with fn compare(
  self : Rational[T],
  other : Rational[T],
) -> Int {
  guard self.denominator.signum() > 0 && other.denominator.signum() > 0 else {
    let left = self.numerator.to_bigint() * other.denominator.to_bigint()
    let right = other.numerator.to_bigint() * self.denominator.to_bigint()
    return Compare::compare(left, right)
  }
  let self_sign = self.numerator.signum()
  let other_sign = other.numerator.signum()
  guard self_sign == other_sign else { return self_sign.compare(other_sign) }
  guard self.denominator != other.denominator else {
    return Compare::compare(self.numerator, other.numerator)
  }
  T::compare_fraction(
    self.numerator,
    self.denominator,
    other.numerator,
    other.denominator,
  )
}

///|
#deprecated
pub extend Rational with Compare::{op_lt, op_le, op_ge, compare, op_gt}
