///|
trait ByteSource {
  op_get(Self, index : Int) -> Byte
  length(Self) -> Int
  blit_to(
    Self,
    dst : FixedArray[Byte],
    len~ : Int,
    src_offset~ : Int,
    dst_offset~ : Int,
  ) -> Unit
}

///|
pub impl ByteSource for FixedArray[Byte] with op_get(self, index) {
  self[index]
}

///|
pub impl ByteSource for FixedArray[Byte] with length(self) {
  self.length()
}

///|
pub impl ByteSource for FixedArray[Byte] with blit_to(
  self,
  dst,
  len~,
  src_offset~,
  dst_offset~,
) {
  self.blit_to(dst, len~, src_offset~, dst_offset~)
}

///|
pub impl ByteSource for @bytes.View with op_get(self, index) {
  self[index]
}

///|
pub impl ByteSource for @bytes.View with length(self) {
  self.length()
}

///|
pub impl ByteSource for @bytes.View with blit_to(
  self,
  dst,
  len~,
  src_offset~,
  dst_offset~,
) {
  dst.blit_from_bytesview(dst_offset, self[src_offset:src_offset + len])
}

///|
pub impl ByteSource for Bytes with op_get(self, index) {
  self[index]
}

///|
pub impl ByteSource for Bytes with length(self) {
  self.length()
}

///|
pub impl ByteSource for Bytes with blit_to(
  self,
  dst,
  len~,
  src_offset~,
  dst_offset~,
) {
  dst.blit_from_bytes(dst_offset, self, src_offset, len)
}
