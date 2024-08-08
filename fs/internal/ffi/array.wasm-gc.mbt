pub type JSArray

pub fn array_len(arr : JSArray) -> Int = "__moonbit_fs_unstable" "array_len"

pub fn array_get(arr : JSArray, idx : Int) -> JSValue = "__moonbit_fs_unstable" "array_get"

pub fn JSArray::op_get(self : JSArray, idx : Int) -> JSValue {
  return array_get(self, idx)
}
