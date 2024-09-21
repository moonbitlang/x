

test "write_and_read" {
  let path = "1.txt"
  @fs.write_string(
    path="1.txt",
    content=
      #|target/
      #|.mooncakes/
      #|
    ,
  )
  assert_true!(@fs.path_exists(~path))
  let byte = @fs.read_to_bytes!(~path).map(fn(x) { x.to_uint() })
  inspect!(
    byte,
    content="[116, 97, 114, 103, 101, 116, 47, 10, 46, 109, 111, 111, 110, 99, 97, 107, 101, 115, 47, 10]",
  )
  @fs.remove_file!(~path)
  assert_false!(@fs.path_exists(~path))

  let bytes = [65, 97].map(fn(x) { x.to_byte() })
  @fs.write_bytes(~path, content=bytes)
  assert_true!(@fs.path_exists(~path))
  let content = @fs.read_to_string!(~path)
  inspect!(content, content="Aa")
  @fs.remove_file!(~path)
  assert_false!(@fs.path_exists(~path))
}

test "path_exist" {
  // dir exist
  assert_true!(@fs.path_exists(path=".github"))
  // dir don't exist
  assert_false!(@fs.path_exists(path="no_exist"))

  // file exist
  assert_true!(@fs.path_exists(path=".gitignore"))

  // file don't exist
  assert_false!(@fs.path_exists(path="no_exist.txt"))
}

test "create_and_remove_dir" {
  @fs.create_dir(path="hello/1/12.txt")
  assert_true!(@fs.path_exists(path="hello/1/12.txt"))
  @fs.remove_dir!(path="hello")
  assert_false!(@fs.path_exists(path="hello"))
}

test "read_dir" {
  let dir_content = @fs.read_dir!(path=".")..sort()
  inspect!(
    dir_content,
    content=
      #|["fs", "num", ".git", "time", "uuid", "json5", "stack", "crypto", "target", ".github", "README.md", ".gitignore", ".mooncakes", "_typos.toml", "moon.mod.json", "licenserc.toml", ".moonbit-lsp.json"]
    ,
  )
}
