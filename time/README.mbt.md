# Moonbit/Core Time

## Overview

Package time provides functionality for measuring and manipulating time.

The calendrical calculations always assume a ISO 8601 calendar, with no leap seconds.

To create a datatime that represents the current time, you need to obtain the unix second and time zone offset from the [wasi](https://mooncakes.io/docs/#/peter-jerry-ye/wasi/) package (wasm-gc backend) or other FFI functions, and manually create a datetime.

```moonbit check
///|
test {
  // creates a UTC+8 fixed time zone.
  let zone = @time.fixed_zone("Asia/Shanghai", 8 * 60 * 60)

  // creates a ZonedDateTime from unix second and time zone.
  let date_time = @time.unix(1714227729L, nanosecond=1000, zone~)
  inspect(date_time, content="2024-04-27T22:22:09.000001+08:00[Asia/Shanghai]")
}
```

Use `@time.Zone::from_tzif(id, data)` to load a caller-supplied TZif v1–v4 file.
`data` is a `BytesView`; complete `Bytes` values can also be passed. The `id`
labels the zone; the constructor does not look up timezone database files.
`Zone::from_tzif2` is deprecated in favor of this interface.

TZif loading uses explicit transitions for recorded history and evaluates the
footer's recurring rules from the last transition onward. When there are no
transitions, the footer governs all timestamps. Evaluation is portable across
backends and does not consult the host's timezone settings. A daylight footer
without explicit transition rules raises an error instead of assuming defaults.
A footer that disagrees with the final transition's offset, DST flag, or
designation also raises an error.
Adjacent or overlapping annual daylight periods are treated as continuous
daylight time.
Without a footer, the final recorded offset continues indefinitely.
Leap-bearing transition times are converted to Unix seconds.
For v4, transitions needing missing earlier leap history raise an error;
after leap-table expiration, the last known correction is retained.

`PlainDateTime` holds calendar and clock fields without a time zone: 01:00
means a clock reading, not one elapsed hour since midnight. A zone can map
that reading to one instant, multiple instants when clocks move backward, or
no instant when clocks skip forward.

`ZonedDateTime::from_plain`, `ZonedDateTime::of`, and `date_time` accept an optional
`disambiguation` argument when resolving those readings:

| Policy | Repeated reading (overlap) | Skipped reading (gap) |
| --- | --- | --- |
| `Compatible` (default) | Choose the earlier instant | Shift forward by the gap |
| `Earlier` | Choose the earlier instant | Shift backward by the gap |
| `Later` | Choose the later instant | Shift forward by the gap |
| `Reject` | Raise an error | Raise an error |

For a jump from 02:00 to 03:00, a requested 02:30 becomes 03:30 under
`Compatible` or `Later`, 01:30 under `Earlier`, and raises under `Reject`.
Unambiguous readings are preserved under every policy. These rules apply to
both recorded and recurring changes.

Field edits (`with_year`, `with_month`, `with_day`, `with_ordinal`, `with_hour`,
`with_minute`, `with_second`, and `with_nanosecond`) also accept `disambiguation`
and a separate `offset : OffsetPolicy` option, following Temporal's rules:

| Offset policy | Treatment of the original offset at the edited local time |
| --- | --- |
| `Prefer` (default) | Use it if valid; otherwise resolve using the zone and `disambiguation` |
| `Ignore` | Resolve using the zone and `disambiguation`, ignoring the original offset |
| `Use` | Compute the instant using the original offset, then project it into the zone; local fields can change |
| `Reject` | Use it if valid; otherwise raise, even if the edited local time is unambiguous |

An accepted offset already selects an instant, so `disambiguation` is not used.
The default `Prefer` plus `Compatible` preserves existing behavior: editing the
second occurrence of 01:30 to 01:45 retains the second occurrence. To choose the
first explicitly, use `offset=Ignore, disambiguation=Earlier`. Similarly,
`Prefer` plus `Reject` accepts an overlap if the original offset is still valid,
whereas `Ignore` plus `Reject` raises for that overlap.

```moonbit check
///|
test {
  let plain = @time.PlainDateTime::of(2040, 1, 1, hour=1)
  let zone = @time.fixed_zone("Example", 3600)
  let value = @time.ZonedDateTime::from_plain(
    plain,
    zone~,
    disambiguation=Reject,
  )
  // A fixed zone has exactly one matching instant for every local reading.
  inspect(value, content="2040-01-01T01:00:00+01:00[Example]")
  let offset : @time.OffsetPolicy = Ignore
  debug_inspect(
    value.with_hour(2, offset~, disambiguation=Reject).to_string(),
    content="\"2040-01-01T02:00:00+01:00[Example]\"",
  )
}
```

`add_hours`, `add_minutes`, `add_seconds`, and `add_nanoseconds` add elapsed time
on the Unix timeline, then obtain the zone's offset at the resulting instant.
They need no disambiguation policy. In contrast, `add_years`, `add_months`,
`add_weeks`, and `add_days` operate on local calendar fields, retaining a valid
original offset and otherwise resolving with `Compatible`. Across a one-hour
daylight-saving change, adding one calendar day can span 23 or 25 elapsed hours;
adding 24 hours always advances the instant by 86400 seconds.

`ZonedDateTime::from_plain_datetime` is deprecated but keeps its non-raising
signature and `Compatible` behavior. Migrate to `ZonedDateTime::from_plain`,
which raises when `Reject` is requested and the input is ambiguous or missing.

Gap adjustments beyond the supported date range remain a known limitation:
those inputs retain the historical, unresolved result and may not round trip
through Unix time. The policy for that boundary is deferred.

## TODOs

- Convert from/to RFC format string.
- Custom string formatter.
- Support monotonic clock to accurately measure the elapsed time.
- Support different calendar system, such as Chinese calendar system.
