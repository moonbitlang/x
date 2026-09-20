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
test "footer defaults, offset signs, and all date syntaxes" {
  let examples = [
    (b"UTC0", 0),
    (b"EST5", -18000),
    (b"IST-5:30", 19800),
    (b"<-0930>9:30", -34200),
    (b"<+125959>-12:59:59", 46799),
    (b"ABC+24:59:59", -89999),
    (b"ABC-24:59:59", 89999),
    (b"ABC0000000000000000000000000000000000000000000000", 0),
  ]
  for (footer, expected) in examples {
    guard @tzif.parse(fixture(footer~)).future_rule is Some(rule) else {
      fail("missing footer")
    }
    assert_eq(rule.standard_offset, expected)
    assert_eq(rule.daylight, None)
  }
  guard @tzif.parse(fixture(footer=b"EST5EDT")).future_rule is Some(rule) else {
    fail("missing footer")
  }
  debug_inspect(
    rule,
    content=(
      #|{
      #|  standard_designation: "EST",
      #|  standard_offset: -18000,
      #|  daylight: Some({ designation: "EDT", offset: -14400, rules: None }),
      #|}
    ),
  )
  guard @tzif.parse(fixture(footer=b"ABC0DEF-2,J60,365/24:59:59")).future_rule
    is Some(rule) else {
    fail("missing footer")
  }
  debug_inspect(
    rule,
    content=(
      #|{
      #|  standard_designation: "ABC",
      #|  standard_offset: 0,
      #|  daylight: Some(
      #|    {
      #|      designation: "DEF",
      #|      offset: 7200,
      #|      rules: Some(
      #|        (
      #|          { day: JulianNoLeap(60), time: 7200 },
      #|          { day: DayOfYear(365), time: 89999 },
      #|        ),
      #|      ),
      #|    },
      #|  ),
      #|}
    ),
  )
  guard @tzif.parse(fixture(footer=b"AAA-24:59:59BBB")).future_rule
    is Some(rule) else {
    fail("missing footer")
  }
  assert_eq(rule.daylight.unwrap().offset, 93599)
}

///|
test "v3 and v4 extended transition times" {
  for version in [b'3', b'4'] {
    guard @tzif.parse(
        fixture(
          version~,
          footer=b"<-03>3<-02>,M3.5.0/-167:59:59,M10.5.0/+167:59:59",
        ),
      ).future_rule
      is Some(rule) else {
      fail("missing footer")
    }
    debug_inspect(
      rule,
      content=(
        #|{
        #|  standard_designation: "-03",
        #|  standard_offset: -10800,
        #|  daylight: Some(
        #|    {
        #|      designation: "-02",
        #|      offset: -7200,
        #|      rules: Some(
        #|        (
        #|          { day: MonthWeekDay(month=3, week=5, weekday=0), time: -604799 },
        #|          { day: MonthWeekDay(month=10, week=5, weekday=0), time: 604799 },
        #|        ),
        #|      ),
        #|    },
        #|  ),
        #|}
      ),
    )
  }
  for
    footer in [
      b"ABC0DEF,M3.1.0/-1,M10.1.0", b"ABC0DEF,M3.1.0/+1,M10.1.0", b"ABC0DEF,M3.1.0/25,M10.1.0",
    ] {
    @test.assert_raise(() => @tzif.parse(fixture(version=b'2', footer~)))
  }
  guard @tzif.parse(rfc_b4).future_rule is Some(rule) else {
    fail("missing RFC footer")
  }
  assert_eq(rule.daylight.unwrap().rules.unwrap().0.time, 93600)
}

///|
test "all-year DST footer remains a rule for later evaluation" {
  let data = @tzif.parse(fixture(version=b'2', footer=b"XXX3EDT4,0/0,J365/23"))
  debug_inspect(
    data.future_rule,
    content=(
      #|Some(
      #|  {
      #|    standard_designation: "XXX",
      #|    standard_offset: -10800,
      #|    daylight: Some(
      #|      {
      #|        designation: "EDT",
      #|        offset: -14400,
      #|        rules: Some(
      #|          (
      #|            { day: DayOfYear(0), time: 0 },
      #|            { day: JulianNoLeap(365), time: 82800 },
      #|          ),
      #|        ),
      #|      },
      #|    ),
      #|  },
      #|)
    ),
  )
}

///|
test "reject malformed footer syntax and numeric overflow" {
  for
    footer in [
      b"UTC", b"UT0", b"<>0", b"<AB>0", b"<ABC0", b"<A_B>0", b"ABC0 D", b"ABC25",
      b"ABC0:60", b"ABC0:0:60", b"ABC0:", b"ABC0:0:", b"ABC0::", b"ABC0:1:2:3", b"ABC99999999999999999999999999999999999999999999999999999999999",
      b"ABC0DEF25", b"ABC0DEF,", b"ABC0DEF,1", b"ABC0DEF,1,", b"ABC0DEF,1,2,3", b"ABC0DEF,J0,J365",
      b"ABC0DEF,J366,J365", b"ABC0DEF,366,365", b"ABC0DEF,-1,365", b"ABC0DEF,M0.1.0,M10.1.0",
      b"ABC0DEF,M13.1.0,M10.1.0", b"ABC0DEF,M3.0.0,M10.1.0", b"ABC0DEF,M3.6.0,M10.1.0",
      b"ABC0DEF,M3.1.7,M10.1.0", b"ABC0DEF,M3.1,M10.1.0", b"ABC0DEF,1/168,2", b"ABC0DEF,1/-168,2",
      b"ABC0DEF,1/1:60,2", b"ABC0DEF,1/1:1:60,2", b"ABC0DEF,1/,2", b"ABC0DEF,1/1u,2",
      b"ABC0\x00", b"ABC0\n", b"ABC0\xff", b":UTC",
    ] {
    @test.assert_raise(() => @tzif.parse(fixture(footer~)))
  }
}

///|
test "footer errors retain byte offsets for ASCII, non-ASCII, and subviews" {
  for
    (footer, expected) in [
      (b"UTC", 3),
      (b"ABC0:60", 5),
      (b"UTC0DEF,M3x1.0,M10.1.0", 10),
      (b"ABC0DEF,1/168,2", 10),
      (b"UTC0\xff", 4),
      (b"UTC0\xc3\xa9", 4),
    ] {
    let file = fixture(footer~)
    let base = file.length() - footer.length() - 1
    let padded = b"prefix" + file + b"suffix"
    for view in [file[:], padded[6:6 + file.length()]] {
      try @tzif.parse(view) catch {
        ParseError(offset, _) => assert_eq(offset, base + expected)
      } noraise {
        _ => fail("expected invalid footer")
      }
    }
  }
}
