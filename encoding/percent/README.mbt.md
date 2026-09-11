# Percent encoding

Percent encoding of text. By default, only ASCII letters and digits are left
unescaped. Pass `escape_chars` to choose a different set.

```mbt check
///|
test {
  let encoded = @percent.encode("hello 世界+")
  inspect(encoded, content="hello%20%E4%B8%96%E7%95%8C%2B")
  let decoded = @utf8.decode(@percent.decode(encoded))
  inspect(decoded, content="hello 世界+")
}
```
