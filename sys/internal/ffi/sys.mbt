///|
/// Gets the command line arguments passed to the program.
/// 
/// This function returns `argv[0]` as the name of the program, and the rest are
/// the other arguments passed to the program (C-style `argv` list). This list
/// of arguments does not contain the runtime used to run the program, nor any
/// arguments meant to be consumed by the runtime.
pub fn get_cli_args() -> Array[String] {
  get_cli_args_internal()
}

///|
/// Gets the environment variables of the current process.
pub fn get_env_vars() -> Map[String, String] {
  get_env_vars_internal()
}

///|
/// Sets an environment variable.
pub fn set_env_var(key : String, value : String) -> Unit {
  set_env_var_internal(key, value)
}

///|
/// Unsets an environment variable.
pub fn unset_env_var(key : String) -> Unit {
  unset_env_var_internal(key)
}

///|
/// Exits the program immediately with the given exit code.
pub fn exit(code : Int) -> Unit {
  exit_internal(code)
}
