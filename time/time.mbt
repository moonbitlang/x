///| return the seconds and the nanoseconds
pub fn now() -> (UInt64, UInt) {
  let t = @env.now()
  let current_second : UInt64 = t / 1000 % 60 + 1
  let current_nanosecond : UInt = (t % 1000 * 1_000_000).to_uint()
  (current_second, current_nanosecond)
}
