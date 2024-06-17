test "endode" {
  // https://symbl.cc/261D/
  let emoji = "☝"
  let res = encode(UTF16_LE, emoji)?.to_array()
  inspect(res, content="[29, 38]")?
  let res = encode(UTF16_BE, emoji)?.to_array()
  inspect(res, content="[38, 29]")?
  let res = encode(UTF8, emoji)?.to_array()
  inspect(res, content="[226, 152, 157]")?
  let res = encode(UTF32_LE, emoji)?.to_array()
  inspect(res, content="[29, 38, 0, 0]")?
  let res = encode(UTF32_BE, emoji)?.to_array()
  inspect(res, content="[0, 0, 38, 29]")?

  // https://symbl.cc/1F38C/
  let flag = "🎌"
  let res = encode(UTF8, flag)?.to_array()
  inspect(res, content="[240, 159, 142, 140]")?
  let res = encode(UTF16_LE, flag)?.to_array()
  inspect(res, content="[140, 243]")?
  let res = encode(UTF16_BE, flag)?.to_array()
  inspect(res, content="[243, 140]")?
  let res = encode(UTF32_LE, flag)?.to_array()
  inspect(res, content="[140, 243, 1, 0]")?
  let res = encode(UTF32_BE, flag)?.to_array()
  inspect(res, content="[0, 1, 243, 140]")?
}
