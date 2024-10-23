test "to_utf8" {
  inspect!(
    @unicode.to_utf8!("✅"),
    content=
      #|b"\xe2\x9c\x85"
    ,
  )
  inspect!(
    @unicode.to_utf8!("👨‍👩‍👧‍👦"),
    content=
      #|b"\xf0\x9f\x91\xa8\xe2\x80\x8d\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x91\xa7\xe2\x80\x8d\xf0\x9f\x91\xa6"
    ,
  )
}
