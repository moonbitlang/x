pub type XJSArray

pub fn array_len(arr : XJSArray) -> Int = "__moonbit_fs_unstable" "array_len"

pub fn array_get(arr : XJSArray, idx : Int) -> XJSValue = "__moonbit_fs_unstable" "array_get"

pub fn XJSArray::op_get(self : XJSArray, idx : Int) -> XJSValue {
  return array_get(self, idx)
}
