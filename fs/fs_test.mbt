

test {
  let a = @fs.read_to_bytes!(path = ".gitignore").map(fn (x) { x.to_uint() })
  println(a)
}

test {
  let bytes = [116, 97, 114, 103, 101, 116, 47, 10, 46, 109, 111, 111, 110, 99, 97, 107, 101, 115, 47, 10].map(fn (x) { x.to_byte() })

  @fs.write_bytes(~path = "1.txt", ~content = bytes)
}

test {
  let a = @fs.read_to_string!(path = ".gitignore")
  println(a)
}

test "path_exist" {
  // dir exist
  assert_true!(@fs.path_exists(path = ".github"))
  // dir don't exist
  assert_false!(@fs.path_exists(path = "no_exist"))

  // file exist
  assert_true!(@fs.path_exists(path = ".gitignore"))

  // file don't exist
  assert_false!(@fs.path_exists(path = "no_exist.txt"))
}

test "create_dir" {
  @fs.create_dir(path="hello/1/12.txt")
  assert_true!(@fs.path_exists(path = "hello/1/12.txt"))
  @fs.remove_dir!(path = "hello")
  assert_false!(@fs.path_exists(path = "hello/1/12.txt"))
}

test "read_dir" {
  let dir_content = @fs.read_dir!(path = ".")
  inspect!(dir_content, content=
    #|["./_typos.toml", "./moon.mod.json", "./crypto", "./target", "./num", "./time", "./README.md", "./.mooncakes", "./.gitignore", "./.github", "./json5", "./licenserc.toml", "./1.txt", "./stack", "./.git", "./fs", "./uuid"]
  )

  let dir_content = @fs.read_dir!(path = "./num")
  inspect!(dir_content, content=
    #|["./num/moon.pkg.json", "./num/num.mbt", "./num/num.mbti"]
  )
}
