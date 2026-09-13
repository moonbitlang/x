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
test "of" {
  inspect(
    @time.Period::of(years=1000, months=24, days=365),
    content="P1000Y24M365D",
  )
}

///|
test "from_string" {
  inspect(@time.Period::parse_str("P10Y2M3D"), content="P10Y2M3D")
  inspect(@time.Period::parse_str("P-10Y-2M-3D"), content="P-10Y-2M-3D")
  inspect(@time.Period::parse_str("P2M3D10Y"), content="P2M3D")
  @test.assert_raise(() => @time.Period::parse_str("10Y"))
  @test.assert_raise(() => @time.Period::parse_str("10Y0M"))
  @test.assert_raise(() => @time.Period::parse_str("P10YT3H"))
  @test.assert_raise(() => @time.Period::parse_str("P2.5Y"))
}

///|
test "getters" {
  let p = @time.Period::of(years=1, months=2, days=3)
  inspect(p.years(), content="1")
  inspect(p.months(), content="2")
  inspect(p.days(), content="3")
  inspect(p.to_total_months(), content="14")
}

///|
test "is_zero" {
  inspect(@time.Period::zero().is_zero(), content="true")
  inspect(@time.Period::of().is_zero(), content="true")
  inspect(@time.Period::of(years=1).is_zero(), content="false")
  inspect(@time.Period::of(months=1).is_zero(), content="false")
  inspect(@time.Period::of(days=1).is_zero(), content="false")
}

///|
test "is_neg" {
  inspect(@time.Period::of().is_neg(), content="false")
  inspect(@time.Period::of(years=1, months=1).is_neg(), content="false")
  inspect(@time.Period::of(years=-1, months=1).is_neg(), content="true")
}

///|
test "add_years" {
  let p = @time.Period::of(years=10)
  inspect(p.add_years(0), content="P10Y")
  inspect(p.add_years(1), content="P11Y")
  inspect(p.add_years(-1), content="P9Y")
}

///|
test "add_months" {
  let p = @time.Period::of(months=10)
  inspect(p.add_months(0), content="P10M")
  inspect(p.add_months(1), content="P11M")
  inspect(p.add_months(-1), content="P9M")
}

///|
test "add_weeks" {
  let p = @time.Period::of(days=10)
  inspect(p.add_weeks(0), content="P10D")
  inspect(p.add_weeks(1), content="P17D")
  inspect(p.add_weeks(-1), content="P3D")
}

///|
test "add_days" {
  let p = @time.Period::of(days=10)
  inspect(p.add_days(0), content="P10D")
  inspect(p.add_days(1), content="P11D")
  inspect(p.add_days(-1), content="P9D")
}

///|
test "with_years" {
  inspect(@time.Period::of(years=1).with_years(1), content="P1Y")
  inspect(@time.Period::of(years=1).with_years(2), content="P2Y")
  inspect(@time.Period::of(years=1).with_years(-1), content="P-1Y")
}

///|
test "with_months" {
  inspect(@time.Period::of(months=1).with_months(1), content="P1M")
  inspect(@time.Period::of(months=1).with_months(2), content="P2M")
  inspect(@time.Period::of(months=1).with_months(-1), content="P-1M")
}

///|
test "with_days" {
  inspect(@time.Period::of(days=1).with_days(1), content="P1D")
  inspect(@time.Period::of(days=1).with_days(2), content="P2D")
  inspect(@time.Period::of(days=1).with_days(-1), content="P-1D")
}

///|
test "op_add" {
  let p1 = @time.Period::of(years=1, months=2, days=3)
  let p2 = @time.Period::of(years=-1, months=-2, days=-3)
  let p3 = @time.Period::of(
    years=@int.MAX_VALUE,
    months=@int.MAX_VALUE,
    days=@int.MAX_VALUE,
  )
  let p4 = @time.Period::of(
    years=@int.MIN_VALUE,
    months=@int.MIN_VALUE,
    days=@int.MIN_VALUE,
  )
  inspect(p1.op_add(@time.Period::zero()), content="P1Y2M3D")
  inspect(p1.op_add(p2), content="P0D")
  inspect(p1.op_add(p1), content="P2Y4M6D")
  inspect(p2.op_add(p2), content="P-2Y-4M-6D")
  @test.assert_raise(() => p1.op_add(p3))
  @test.assert_raise(() => p2.op_add(p4))
}

///|
test "op_sub" {
  let p1 = @time.Period::of(years=1, months=2, days=3)
  let p2 = @time.Period::of(years=-1, months=-2, days=-3)
  let p3 = @time.Period::of(
    years=@int.MAX_VALUE,
    months=@int.MAX_VALUE,
    days=@int.MAX_VALUE,
  )
  let p4 = @time.Period::of(
    years=@int.MIN_VALUE,
    months=@int.MIN_VALUE,
    days=@int.MIN_VALUE,
  )
  inspect(p1.op_sub(p1), content="P0D")
  inspect(p1.op_sub(p2), content="P2Y4M6D")
  inspect(p2.op_sub(p1), content="P-2Y-4M-6D")
  @test.assert_raise(() => p3.op_sub(p2))
  @test.assert_raise(() => p4.op_sub(p1))
}

///|
test "multiply" {
  let p = @time.Period::of(years=1, months=2, days=3)
  inspect(p.multiply(0), content="P0D")
  inspect(p.multiply(1), content="P1Y2M3D")
  inspect(p.multiply(-1), content="P-1Y-2M-3D")
  inspect(p.multiply(2), content="P2Y4M6D")
  @test.assert_raise(() => p.multiply(@int.MAX_VALUE))
  @test.assert_raise(() => p.multiply(@int.MIN_VALUE))
}

///|
test "negated" {
  let p = @time.Period::of(years=1, months=1, days=1)
  inspect(p.negated(), content="P-1Y-1M-1D")
  inspect(p.negated().negated() == p, content="true")
  let p = @time.Period::of(
    years=@int.MAX_VALUE,
    months=@int.MAX_VALUE,
    days=@int.MAX_VALUE,
  )
  inspect(p.negated(), content="P-2147483647Y-2147483647M-2147483647D")
  inspect(p.negated().negated() == p, content="true")
  let p = @time.Period::of(
    years=@int.MIN_VALUE,
    months=@int.MIN_VALUE,
    days=@int.MIN_VALUE,
  )
  @test.assert_raise(() => p.negated())
}

///|
test "parse_str errors" {
  @test.assert_raise(() => @time.Period::parse_str(""))
  @test.assert_raise(() => @time.Period::parse_str("p1y2m3d"))
  @test.assert_raise(() => @time.Period::parse_str("P1Y2MX"))
}

///|
test "period from_str" {
  inspect(
    (@string.FromStr::from_str("P10Y2M3D") : @time.Period),
    content="P10Y2M3D",
  )
  inspect(
    (@string.FromStr::from_str("P-10Y-2M-3D") : @time.Period),
    content="P-10Y-2M-3D",
  )
}

///|
test "from_years" {
  inspect(@time.Period::from_years(0), content="P0D")
  inspect(@time.Period::from_years(1), content="P1Y")
  inspect(@time.Period::from_years(-1), content="P-1Y")
}

///|
test "from_months" {
  inspect(@time.Period::from_months(0), content="P0D")
  inspect(@time.Period::from_months(13), content="P13M")
  inspect(@time.Period::from_months(-13), content="P-13M")
}

///|
test "from_weeks" {
  inspect(@time.Period::from_weeks(0), content="P0D")
  inspect(@time.Period::from_weeks(2), content="P14D")
  inspect(@time.Period::from_weeks(-1), content="P-7D")
  @test.assert_raise(() => @time.Period::from_weeks(@int.MAX_VALUE))
}

///|
test "from_days" {
  inspect(@time.Period::from_days(0), content="P0D")
  inspect(@time.Period::from_days(3), content="P3D")
  inspect(@time.Period::from_days(-3), content="P-3D")
}

///|
test "subtract_years" {
  let p = @time.Period::of(years=2)
  inspect(p.subtract_years(1), content="P1Y")
  inspect(p.subtract_years(2), content="P0D")
  inspect(p.subtract_years(3), content="P-1Y")
  inspect(p.subtract_years(-1), content="P3Y")
}

///|
test "subtract_months" {
  let p = @time.Period::of(years=1, months=2)
  inspect(p.subtract_months(2), content="P1Y")
  inspect(p.subtract_months(3), content="P1Y-1M")
  inspect(p.subtract_months(14), content="P1Y-12M")
  inspect(p.subtract_months(15).normalized(), content="P-1M")
  inspect(p.subtract_months(0), content="P1Y2M")
}

///|
test "subtract_weeks" {
  let p = @time.Period::of(days=14)
  inspect(p.subtract_weeks(1), content="P7D")
  inspect(p.subtract_weeks(2), content="P0D")
  inspect(p.subtract_weeks(3), content="P-7D")
}

///|
test "subtract_days" {
  let p = @time.Period::of(months=1, days=10)
  inspect(p.subtract_days(3), content="P1M7D")
  inspect(p.subtract_days(10), content="P1M")
  inspect(p.subtract_days(11), content="P1M-1D")
}

///|
test "subtract_period and op_sub" {
  let p = @time.Period::of(years=1, months=2, days=3)
  inspect(p.subtract_period(@time.Period::of(months=1)), content="P1Y1M3D")
  inspect(p.op_sub(@time.Period::of(months=1, days=4)), content="P1Y1M-1D")
  inspect(p.subtract_period(@time.Period::zero()), content="P1Y2M3D")
}

///|
test "abs" {
  inspect(@time.Period::zero().abs(), content="P0D")
  inspect(@time.Period::of(years=1, months=2, days=3).abs(), content="P1Y2M3D")
  inspect(
    @time.Period::of(years=-1, months=-2, days=-3).abs(),
    content="P1Y2M3D",
  )
  inspect(@time.Period::of(days=-1).abs(), content="P1D")
}

///|
test "is_positive" {
  inspect(@time.Period::zero().is_positive(), content="false")
  inspect(@time.Period::of(years=1).is_positive(), content="true")
  inspect(@time.Period::of(months=1).is_positive(), content="true")
  inspect(@time.Period::of(days=1).is_positive(), content="true")
  inspect(@time.Period::of(years=-1).is_positive(), content="false")
  inspect(@time.Period::of(days=-1).is_positive(), content="false")
}

///|
test "normalized" {
  inspect(@time.Period::from_months(13).normalized(), content="P1Y1M")
  inspect(@time.Period::from_months(12).normalized(), content="P1Y")
  inspect(@time.Period::from_months(11).normalized(), content="P11M")
  inspect(@time.Period::from_months(-13).normalized(), content="P-1Y-1M")
  inspect(@time.Period::from_months(-12).normalized(), content="P-1Y")
  inspect(@time.Period::of(years=1, months=12).normalized(), content="P2Y")
  // Days are preserved: they cannot be folded into months without a
  // reference date.
  inspect(
    @time.Period::of(years=1, months=13, days=5).normalized(),
    content="P2Y1M5D",
  )
  // Already-normalized periods are unchanged.
  let p = @time.Period::of(years=2, months=3, days=4)
  inspect(p.normalized() == p, content="true")
}

///|
test "eq compare and hash" {
  let a = @time.Period::of(years=1, months=2, days=3)
  let b = @time.Period::of(years=1, months=2, days=3)
  let c = @time.Period::of(years=1, months=2, days=4)
  inspect(a == b, content="true")
  inspect(a == c, content="false")
  inspect(a < c, content="true")
  inspect(Compare::compare(a, b), content="0")
  inspect(hash_of(a) == hash_of(b), content="true")
  // Structurally different periods are not equal, even when they would
  // resolve to the same length against a particular calendar.
  inspect(
    @time.Period::of(years=1) == @time.Period::from_months(12),
    content="false",
  )
  inspect(
    @time.Period::of(years=1).normalized() ==
    @time.Period::from_months(12).normalized(),
    content="true",
  )
}
