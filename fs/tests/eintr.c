// Test-only syscall interposition for eintr.mbtx; not linked into x/fs.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static _Atomic int injected;
static _Atomic int progressed;

static int is_test_file(int fd) {
  char path[PATH_MAX];
#ifdef __APPLE__
  if (fcntl(fd, F_GETPATH, path) != 0) return 0;
#else
  char descriptor[64];
  snprintf(descriptor, sizeof(descriptor), "/proc/self/fd/%d", fd);
  ssize_t len = readlink(descriptor, path, sizeof(path) - 1);
  if (len < 0) return 0;
  path[len] = '\0';
#endif
  const char *name = strrchr(path, '/');
  return name && strcmp(name + 1, "tmp_fs_eintr.bin") == 0;
}

static ssize_t transfer(int fd, void *buffer, size_t size, int writing) {
#ifndef __APPLE__
  ssize_t (*real_read)(int, void *, size_t) = dlsym(RTLD_NEXT, "read");
  ssize_t (*real_write)(int, const void *, size_t) = dlsym(RTLD_NEXT, "write");
#endif
  const char *mode = getenv("X_FS_FAULT");
  const char *operation = writing ? "write" : "read";
  int selected = !injected && size > 0 && mode &&
      strncmp(mode, operation, strlen(operation)) == 0 && is_test_file(fd);
  if (selected) {
    if (strstr(mode, "after") && !progressed) {
      // Force real partial progress before interrupting the next syscall.
      const size_t partial_size = 127;
      if (size > partial_size) size = partial_size;
    } else {
      injected = 1;
      int error = strstr(mode, "error") ? EIO : EINTR;
      fprintf(stderr, "X_FS_INJECTED %s\n", mode);
      errno = error;
      return -1;
    }
  }
#ifdef __APPLE__
  ssize_t result = writing ? write(fd, buffer, size) : read(fd, buffer, size);
#else
  ssize_t result = writing ? real_write(fd, buffer, size)
                           : real_read(fd, buffer, size);
#endif
  if (selected && result > 0) progressed = 1;
  return result;
}

#ifdef __APPLE__
static ssize_t audit_read(int fd, void *buffer, size_t size) {
  return transfer(fd, buffer, size, 0);
}
static ssize_t audit_write(int fd, const void *buffer, size_t size) {
  return transfer(fd, (void *)buffer, size, 1);
}
__attribute__((used)) static struct {
  const void *replacement;
  const void *original;
} interposes[] __attribute__((section("__DATA,__interpose"))) = {
  { (const void *)audit_read, (const void *)read },
  { (const void *)audit_write, (const void *)write },
};
#else
ssize_t read(int fd, void *buffer, size_t size) {
  return transfer(fd, buffer, size, 0);
}
ssize_t write(int fd, const void *buffer, size_t size) {
  return transfer(fd, (void *)buffer, size, 1);
}
#endif
