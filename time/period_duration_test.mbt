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
test "of and zero" {
  inspect(@time.PeriodDuration::zero(), content="P0D")
  inspect(@time.PeriodDuration::of(), content="P0D")
  inspect(
    @time.PeriodDuration::from_period(@time.Period::zero()),
    content="P0D",
  )
  inspect(
    @time.PeriodDuration::from_duration(@time.Duration::zero()),
    content="P0D",
  )
  let pd = @time.PeriodDuration::of(
    period=@time.Period::of(years=1),
    duration=@time.Duration::of(seconds=2L),
  )
  inspect(pd, content="P1YT2S")
  inspect(pd.period(), content="P1Y")
  inspect(pd.duration(), content="PT2S")
  inspect(
    @time.PeriodDuration::from_period(@time.Period::of(days=1)),
    content="P1D",
  )
  inspect(
    @time.PeriodDuration::from_duration(@time.Duration::of(minutes=1L)),
    content="PT1M",
  )
}

///|
test "to_string" {
  let pd = @time.PeriodDuration::of(
    period=@time.Period::of(years=1, months=2, days=3),
    duration=@time.Duration::of(hours=4L, minutes=5L, seconds=6L),
  )
  inspect(pd, content="P1Y2M3DT4H5M6S")
  inspect(
    @time.PeriodDuration::of(period=@time.Period::of(days=-1)),
    content="P-1D",
  )
  inspect(
    @time.PeriodDuration::of(duration=@time.Duration::of(nanoseconds=1L)),
    content="PT0.000000001S",
  )
  // A sub-second duration is printed with its fraction.
  inspect(
    @time.PeriodDuration::of(
      duration=@time.Duration::of(seconds=-1L, nanoseconds=500_000_000L),
    ),
    content="PT-0.5S",
  )
  // Each time component carries its own sign.
  inspect(
    @time.PeriodDuration::of(duration=@time.Duration::of(seconds=-3661L)),
    content="PT-1H-1M-1S",
  )
  // Only non-zero components are printed.
  inspect(
    @time.PeriodDuration::of(
      period=@time.Period::of(years=1),
      duration=@time.Duration::of(hours=2L),
    ),
    content="P1YT2H",
  )
}

///|
test "parse_str" {
  inspect(
    @time.PeriodDuration::parse_str("P1Y2M3DT4H5M6S").to_string(),
    content="P1Y2M3DT4H5M6S",
  )
  inspect(@time.PeriodDuration::parse_str("P1D").to_string(), content="P1D")
  inspect(
    @time.PeriodDuration::parse_str("PT1H30M").to_string(),
    content="PT1H30M",
  )
  inspect(
    @time.PeriodDuration::parse_str("PT0.5S").to_string(),
    content="PT0.5S",
  )
  inspect(@time.PeriodDuration::parse_str("P0D").is_zero(), content="true")
  let pd = @time.PeriodDuration::parse_str("P1Y2M3DT4H5M6.000000789S")
  inspect(pd.period(), content="P1Y2M3D")
  inspect(pd.duration(), content="PT4H5M6.000000789S")
  // Negative components keep their sign.
  inspect(
    @time.PeriodDuration::parse_str("PT-1H-2M-3.456789S").to_string(),
    content="PT-1H-2M-3.456789S",
  )
  inspect(
    @time.PeriodDuration::parse_str("P-1Y-2M-3D").to_string(),
    content="P-1Y-2M-3D",
  )
  // A negative fractional second is negative even when the whole-seconds
  // field is `-0`.
  inspect(
    @time.PeriodDuration::parse_str("PT-0.5S").to_string(),
    content="PT-0.5S",
  )
}

///|
test "from_str" {
  inspect(
    (@string.FromStr::from_str("P1DT2H") : @time.PeriodDuration),
    content="P1DT2H",
  )
}

///|
test "parse_str errors" {
  let invalid : Array[String] = [
    "", "P", "PT", "1Y", "P1X", "P1Y2", "PT1H2", "P1YT", "P1H", "P1S", "PT1D", "P1Y2M3DT",
    "PT.S", "P1YT1H2",
  ]
  for s in invalid {
    @test.assert_raise(() => @time.PeriodDuration::parse_str(s))
  }
}

///|
test "with_period and with_duration" {
  let pd = @time.PeriodDuration::of(
    period=@time.Period::of(days=1),
    duration=@time.Duration::of(hours=1L),
  )
  inspect(pd.with_period(@time.Period::of(days=2)), content="P2DT1H")
  inspect(pd.with_duration(@time.Duration::of(hours=2L)), content="P1DT2H")
  inspect(pd.with_period(pd.period()) == pd, content="true")
  inspect(pd.with_duration(pd.duration()) == pd, content="true")
}

///|
test "add, subtract and negated" {
  let a = @time.PeriodDuration::of(
    period=@time.Period::of(years=1, days=1),
    duration=@time.Duration::of(hours=1L),
  )
  let b = @time.PeriodDuration::of(
    period=@time.Period::of(days=2),
    duration=@time.Duration::of(minutes=30L),
  )
  inspect(a.add(b), content="P1Y3DT1H30M")
  inspect(a.op_add(b), content="P1Y3DT1H30M")
  inspect(a.subtract(b), content="P1Y-1DT30M")
  inspect(a.op_sub(b), content="P1Y-1DT30M")
  inspect(a.negated(), content="P-1Y-1DT-1H")
  inspect(a.op_neg(), content="P-1Y-1DT-1H")
  inspect(a.negated().negated(), content="P1Y1DT1H")
  // Subtraction undoes a matching addition.
  inspect(a.add(b).subtract(b) == a, content="true")
  inspect(a.is_zero(), content="false")
  inspect(@time.PeriodDuration::zero().is_zero(), content="true")
}

///|
test "estimated_compare" {
  let day = @time.PeriodDuration::from_period(@time.Period::of(days=1))
  let hours23 = @time.PeriodDuration::from_duration(
    @time.Duration::of(hours=23L),
  )
  inspect(day.estimated_compare(hours23), content="1")
  inspect(hours23.estimated_compare(day), content="-1")
  inspect(day.estimated_compare(day), content="0")
  // Estimates a month as 30 days and a year as 12 such months.
  inspect(
    @time.PeriodDuration::from_period(@time.Period::of(months=1)).estimated_compare(
      @time.PeriodDuration::from_period(@time.Period::of(days=30)),
    ),
    content="0",
  )
  inspect(
    @time.PeriodDuration::from_period(@time.Period::of(years=1)).estimated_compare(
      @time.PeriodDuration::from_period(@time.Period::of(months=12)),
    ),
    content="0",
  )
  inspect(
    @time.PeriodDuration::from_period(@time.Period::of(years=1)).estimated_compare(
      @time.PeriodDuration::from_period(@time.Period::of(days=360)),
    ),
    content="0",
  )
  // The estimate is a function of the represented period rather than of its
  // spelling: one year is 360 estimated days, fewer than 365.
  inspect(
    @time.PeriodDuration::from_period(@time.Period::of(years=1)).estimated_compare(
      @time.PeriodDuration::from_period(@time.Period::of(days=365)),
    ),
    content="-1",
  )
}

///|
test "eq and hash" {
  let a = @time.PeriodDuration::of(
    period=@time.Period::of(days=1),
    duration=@time.Duration::of(seconds=1L),
  )
  let b = @time.PeriodDuration::of(
    period=@time.Period::of(days=1),
    duration=@time.Duration::of(seconds=1L),
  )
  inspect(a == b, content="true")
  inspect(hash_of(a) == hash_of(b), content="true")
  // The same combination can be stored with different secs/nanos splits.
  let c = @time.PeriodDuration::of(
    duration=@time.Duration::of(seconds=-1L, nanoseconds=500_000_000L),
  )
  let d = @time.PeriodDuration::of(
    duration=@time.Duration::of(nanoseconds=-500_000_000L),
  )
  inspect(c == d, content="true")
  inspect(hash_of(c) == hash_of(d), content="true")
  inspect(a == c, content="false")
}
