# Internal TZif data parser

`moonbitlang/x/time/internal/tzif` decodes TZif versions 1–4 into structured data.
It is internal to the time package and is not a public library interface.
It accepts caller-supplied bytes and has no filesystem or timezone database
dependency.

```mbt check
///|
test {
  // A minimal v1 file containing a fixed UTC local time type.
  let bytes = b"TZif\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" +
    b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" +
    b"\x00\x00\x00\x01\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00UTC\x00"
  let data = @tzif.parse(bytes)
  assert_eq(data.version, V1)
  assert_eq(data.local_time_types[0].offset, 0)
  assert_eq(data.local_time_types[0].designation, b"UTC")
}
```

The parser follows [RFC 9636](https://www.rfc-editor.org/rfc/rfc9636.html).
For v2–v4 it skips the compatibility block and reads the authoritative 64-bit
block. It validates block sizes, indices, ordering, flags, leap correction
steps and minimum spacing, and footer syntax. Invalid input raises
`ParseError(byte_offset, reason)`.

The result owns its designation bytes. They retain their original encoding,
including historical non-UTF-8 designations. Missing standard/wall and UT/local
indicators are represented by their specified default, `false`.

Leap-bearing files are accepted. `leap_records` retains every correction and
v4 expiration marker, without applying them. Transition and leap occurrence
timestamps remain **UNIX leap time**, as encoded in TZif; they are not converted
to POSIX seconds. A final v4 record with the same correction as its predecessor
marks expiration. A first correction other than ±1 indicates truncated history.

`future_rule` contains the parsed POSIX footer, or `None` for an empty footer or
v1 file. Numeric offsets use **local minus UT**, matching the local time types;
this reverses the sign used in the POSIX text. Omitted DST rules remain `None`;
the parser never invents rules from the host environment. Default DST offsets
and default transition times are expanded. Recurring rules are not evaluated.

This package parses format data. It does not construct `Zone` or `ZonedDateTime`,
resolve local times, or change the existing time package's POSIX-time model.
It does not validate that leap occurrences fall at UTC month ends or that the
footer agrees with the last transition. These require interpreting the data
and belong with the future timezone-rule implementation.

Tests include the exact bytes of RFC 9636 Appendix B, Tables 1–5, synthetic
boundary cases, every truncated prefix of those examples, and byte mutations.
