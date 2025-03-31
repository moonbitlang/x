///| We cannot actually test timestamp-getting methods, so this file only includes smoke tests for now.
test "instant_elapsed_as_secs_f64() returns a reasonable value" {
  let i = instant_now()
  let elapsed = instant_elapsed_as_secs_f64(i)
  inspect!(elapsed > 0.0, content="false")
}
