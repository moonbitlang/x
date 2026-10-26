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
#external
priv type HostZone

///|
#external
priv type HostZoneResult

///|
extern "js" fn get_js_timezone_raw(id : String) -> HostZoneResult =
  #| (id) => {
  #|   try {
  #|     const temporal = globalThis.Temporal;
  #|     if (typeof temporal?.ZonedDateTime === "function") {
  #|       if (id === "") id = temporal.Now.timeZoneId();
  #|       const epoch = new temporal.ZonedDateTime(0n, id);
  #|       return { value: { id: epoch.timeZoneId, temporal: true }, error: "" };
  #|     }
  #|     if (typeof globalThis.Intl?.DateTimeFormat !== "function") {
  #|       throw new Error("local_zone requires Temporal or Date with Intl.DateTimeFormat");
  #|     }
  #|     if (id === "") id = new Intl.DateTimeFormat().resolvedOptions().timeZone;
  #|     // Gregorian fields have the same dates as ISO, and retain an explicit
  #|     // era. Some ICU versions omit the era for the iso8601 formatter.
  #|     const formatter = new Intl.DateTimeFormat("en-US", {
  #|       timeZone: id, calendar: "gregory", numberingSystem: "latn",
  #|       era: "short", year: "numeric", month: "numeric", day: "numeric",
  #|       hour: "numeric", minute: "numeric", second: "numeric", hour12: false, hourCycle: "h23"
  #|     });
  #|     id = formatter.resolvedOptions().timeZone;
  #|     formatter.formatToParts(new Date(0)); // Validate before returning a non-raising query object.
  #|     return { value: { id, temporal: false, formatter }, error: "" };
  #|   } catch (error) {
  #|     return { error: String(error) };
  #|   }
  #| }

///|
extern "js" fn HostZoneResult::error(self : HostZoneResult) -> String =
  #| result => result.error

///|
extern "js" fn HostZoneResult::value(self : HostZoneResult) -> HostZone =
  #| result => result.value

///|
// Obtain a JavaScript-backed timezone. Omitting the identifier captures the
// runtime default; explicit identifiers let internal tests use real JS rules.
fn get_js_timezone(id~ : String = "") -> HostZone raise Error {
  let result = get_js_timezone_raw(id)
  guard result.error().is_empty() else { fail(result.error()) }
  result.value()
}

///|
// Adapt the captured JS timezone to the common Zone representation.
fn HostZone::to_zone(self : HostZone) -> Zone {
  { id: self.id(), rules: JavaScript(self), }
}

///|
extern "js" fn HostZone::id(self : HostZone) -> String =
  #| zone => zone.id

///|
// Host rules cannot be inspected as a table. Compare the selected runtime
// backend and identifier; this does not compare rules across different sources.
impl Eq for HostZone with fn equal(self, other) {
  self.has_temporal() == other.has_temporal() && self.id() == other.id()
}

///|
impl Debug for HostZone with fn to_repr(self) {
  Repr::string(self.id())
}

///|
// MoonBit Int64 values may reach JS as unsigned 64-bit bit patterns.
// The public instant constructor checks the host's range before lookup.
// Local resolution queries only instants near PlainDateTime's bounded years.
// The identifier and selected runtime API were validated when loading.
extern "js" fn HostZone::temporal_offset_seconds(
  self : HostZone,
  second : Int64,
) -> Int32 =
  #| (zone, second) => new Temporal.ZonedDateTime(BigInt.asIntN(64, second) * 1000000000n, zone.id)
  #|   .offsetNanoseconds / 1000000000

///|
extern "js" fn HostZone::has_temporal(self : HostZone) -> Bool =
  #| zone => zone.temporal

///|
// Date.getTimezoneOffset loses historical seconds and uses the live default
// zone. Formatting into fields preserves seconds and the captured identifier.
extern "js" fn HostZone::date_fields(
  self : HostZone,
  second : Int64,
) -> FixedArray[Int32] =
  #| (zone, second) => {
  #|   const fields = Object.create(null);
  #|   for (const part of zone.formatter.formatToParts(new Date(Number(BigInt.asIntN(64, second)) * 1000))) {
  #|     if (part.type !== "literal") fields[part.type] = part.value;
  #|   }
  #|   return [fields.era === "BC" ? 1 - +fields.year : +fields.year,
  #|     +fields.month, +fields.day, +fields.hour % 24, +fields.minute, +fields.second];
  #| }

///|
fn HostZone::offset_seconds(self : HostZone, second : Int64) -> Int32 {
  if self.has_temporal() {
    return self.temporal_offset_seconds(second)
  }
  let fields = self.date_fields(second)
  // Convert calendar fields ourselves: Date.UTC treats years 0..99 specially,
  // and a local reading at Date's instant boundary can lie outside its range.
  let days = date_to_fixed_days(fields[0], fields[1], fields[2]) -
    days_zero_year_to_unix_epoch
  let wall = days * 86400L +
    fields[3].to_int64() * 3600L +
    fields[4].to_int64() * 60L +
    fields[5].to_int64()
  (wall - second).to_int()
}

///|
fn HostZone::lookup_offset(self : HostZone, second : Int64) -> ZoneOffset {
  let seconds = self.offset_seconds(second)
  // JavaScript exposes the actual offset, but neither a DST flag nor an
  // abbreviation. Do not infer DST by comparing summer and winter offsets.
  { id: create_id(seconds), abbrev: "", seconds, dst: false, }
}

///|
#external
priv type HostTimeResult

///|
extern "js" fn HostZone::resolve_local(
  self : HostZone,
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  disambiguation : String,
) -> HostTimeResult =
  #| (zone, year, month, day, hour, minute, second, disambiguation) => {
  #|   try {
  #|     const value = Temporal.ZonedDateTime.from(
  #|       { timeZone: zone.id, year, month, day, hour, minute, second },
  #|       { overflow: "reject", disambiguation }
  #|     );
  #|     return { second: value.epochNanoseconds / 1000000000n, error: "" };
  #|   } catch (error) {
  #|     return { error: String(error) };
  #|   }
  #| }

///|
extern "js" fn HostTimeResult::error(self : HostTimeResult) -> String =
  #| result => result.error

///|
extern "js" fn HostTimeResult::second(self : HostTimeResult) -> Int64 =
  #| result => result.second

///|
fn HostZone::resolve(
  self : HostZone,
  datetime : PlainDateTime,
  disambiguation : Disambiguation,
) -> Int64 raise Error {
  if !self.has_temporal() {
    let wall = datetime.to_unix_second()
    let candidates = self.possible_instants(wall)
    match candidates[:] {
      [only] => return only
      [first, .., last] =>
        if disambiguation == Reject {
          fail("Ambiguous local time")
        } else {
          return if disambiguation == Later { last } else { first }
        }
      [] => ()
    }
    if disambiguation == Reject {
      fail("Nonexistent local time")
    }
    let before = self.offset_seconds(wall - 86400L).to_int64()
    let after = self.offset_seconds(wall + 86400L).to_int64()
    let shift = after - before
    guard shift > 0L && shift <= 86400L else {
      fail("Cannot resolve local time from JavaScript timezone data")
    }
    let adjusted = wall +
      (if disambiguation == Earlier { -shift } else { shift })
    let candidates = self.possible_instants(adjusted)
    guard !candidates.is_empty() else {
      fail("Cannot resolve adjusted local time from JavaScript timezone data")
    }
    return if disambiguation == Earlier {
      candidates[0]
    } else {
      candidates[candidates.length() - 1]
    }
  }
  let result = self.resolve_local(
    datetime.year(),
    datetime.month(),
    datetime.day(),
    datetime.hour(),
    datetime.minute(),
    datetime.second(),
    match disambiguation {
      Compatible => "compatible"
      Earlier => "earlier"
      Later => "later"
      Reject => "reject"
    },
  )
  guard result.error().is_empty() else { fail(result.error()) }
  // Zone offsets and transitions are whole seconds. Nanoseconds stay in
  // MoonBit, avoiding rounding when the resolved instant precedes the epoch.
  result.second()
}

///|
// Match the Temporal polyfill's Intl strategy: offsets one day either side
// cover the surrounding IANA change, including a skipped calendar day. This
// relies on IANA transitions being separated, and is only used for host zones;
// arbitrary caller-supplied TZif tables retain their exact stored-rule resolver.
// Reference: js-temporal/temporal-polyfill, GetNamedTimeZoneEpochNanoseconds.
fn HostZone::possible_instants(self : HostZone, wall : Int64) -> Array[Int64] {
  let before = self.offset_seconds(wall - 86400L)
  let after = self.offset_seconds(wall + 86400L)
  let offsets = if before == after { [before] } else { [before, after] }
  let candidates = offsets.filter_map(offset => {
    let instant = wall - offset.to_int64()
    if self.offset_seconds(instant) == offset {
      Some(instant)
    } else {
      None
    }
  })
  candidates.sort()
  candidates
}

///|
/// Captures the JavaScript runtime's current local timezone identifier.
/// Uses `globalThis.Temporal` when available, otherwise `Date` with
/// `Intl.DateTimeFormat`. Raises if neither is available. Works without
/// filesystem access and uses the host's rules for the requested date.
///
/// The zone retains its identifier if the runtime's default timezone changes.
/// Rules are supplied by the runtime, not copied into an independent snapshot.
/// JavaScript does not expose DST metadata: `ZoneOffset::is_dst()` returns
/// false for these offsets, meaning unavailable, and abbreviations are empty.
pub fn local_zone() -> Zone raise Error {
  get_js_timezone().to_zone()
}

///|
// Imports cannot yet be conditional; UTF-8 decoding is used by native readers.
let _unused_native_utf8_import : Unit = ignore(@utf8.decode_lossy(b""))
