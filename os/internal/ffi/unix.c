// Native implementation for `moonbitlang/x/os` — the POSIX half. Wraps
// synchronous POSIX calls; unix_win.c is the Windows adapter for the same API.
// Both are plain C native stubs supported by the stock `moon` toolchain.
//
// FFI contract:
//   * inputs cross as NUL-terminated UTF-8 (moonbit Bytes used as C strings);
//   * returned Bytes are allocated via `moonbit_make_bytes`;
//   * the argv blob is each arg '\0'-terminated and concatenated, `argc` = count;
//   * FixedArray[Int] -> int32_t*, FixedArray[Int64] -> int64_t* (raw elements).
//
// The whole POSIX impl is guarded by `#ifndef _WIN32` so that when the manifest
// lists BOTH unix.c and unix_win.c, exactly one provides symbols per platform and
// the other compiles to an (almost) empty translation unit.

typedef int moonbit_community_unix_os_c_tu_marker; // keep the TU non-empty on Windows

#ifndef _WIN32

#define _GNU_SOURCE // posix_spawn, clock_gettime, realpath, environ on glibc
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <signal.h>
#include <spawn.h>
#include <time.h>
#include <errno.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <utime.h>
#include <poll.h>

extern char **environ;

// ── moonbit runtime ───────────────────────────────────────────────────────────
extern uint8_t *moonbit_make_bytes(int32_t size, int value);

static uint8_t *mb_empty(void) { return moonbit_make_bytes(0, 0); }

static uint8_t *mb_from(const void *src, size_t len) {
  uint8_t *out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) memcpy(out, src, len);
  return out;
}

// ── a small growable byte buffer (malloc/realloc-backed) ──────────────────────
typedef struct { uint8_t *p; size_t len; size_t cap; } Buf;

static int buf_reserve(Buf *b, size_t extra) {
  if (extra > INT32_MAX || b->len > INT32_MAX - extra) { errno = EOVERFLOW; return -1; }
  if (b->len + extra <= b->cap) return 0;
  size_t nc = b->cap ? b->cap * 2 : 4096;
  while (nc < b->len + extra) nc *= 2;
  uint8_t *np = (uint8_t *)realloc(b->p, nc);
  if (!np) return -1;
  b->p = np;
  b->cap = nc;
  return 0;
}

static uint8_t *read_all_fd(int fd, int32_t *status) {
  Buf b = {0};
  if (status) status[0] = 0;
  for (;;) {
    if (buf_reserve(&b, 4096)) {
      if (status) status[0] = errno;
      break;
    }
    ssize_t n;
    do {
      n = read(fd, b.p + b.len, b.cap - b.len);
    } while (n < 0 && errno == EINTR);
    if (n < 0) {
      if (status) status[0] = errno;
      break;
    }
    if (n == 0) break;
    b.len += (size_t)n;
  }
  uint8_t *out = status && status[0] ? mb_empty() : mb_from(b.p, b.len);
  free(b.p);
  return out;
}

// ── host OS family (resolved at compile time, never sniffed) ──────────────────
int32_t moonbit_community_unix_os_kind(void) {
#if defined(__APPLE__)
  return 1;
#else
  return 0;
#endif
}

int32_t moonbit_community_unix_available_parallelism(void) {
  long n = sysconf(_SC_NPROCESSORS_ONLN);
  if (n < 1) return 1;
  if (n > INT32_MAX) return INT32_MAX;
  return (int32_t)n;
}

// ── time / pid / stderr / stdin ───────────────────────────────────────────────
int64_t moonbit_community_unix_now_ns(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;
  return (int64_t)ts.tv_sec * 1000000000LL + (int64_t)ts.tv_nsec;
}

int32_t moonbit_community_unix_getpid(void) { return (int32_t)getpid(); }

void moonbit_community_unix_exit(int32_t code) { exit(code); }

int32_t moonbit_community_unix_write_stderr(const uint8_t *s, int32_t len) {
  if (len < 0) return EINVAL;
  int32_t off = 0;
  while (off < len) {
    ssize_t n;
    do { n = write(2, s + off, (size_t)(len - off)); } while (n < 0 && errno == EINTR);
    if (n < 0) return errno;
    if (n == 0) return EIO;
    off += (int32_t)n;
  }
  return 0;
}

int32_t moonbit_community_unix_stderr_is_terminal(void) { return isatty(2) ? 1 : 0; }

uint8_t *moonbit_community_unix_read_stdin(int32_t *status) { return read_all_fd(0, status); }

uint8_t *moonbit_community_unix_read_file(const uint8_t *path, int32_t sync_timestamp,
                                         int32_t *status) {
  status[0] = 0;
  int fd;
  do {
    fd = open((const char *)path, O_RDONLY | O_CLOEXEC);
  } while (fd < 0 && errno == EINTR);
  if (fd < 0) { status[0] = errno; return mb_empty(); }
  uint8_t *out = read_all_fd(fd, status);
  if (sync_timestamp && status[0] == 0) {
    int rc;
    do {
      rc = fsync(fd);
    } while (rc < 0 && errno == EINTR);
    if (rc < 0) status[0] = errno;
  }
  if (close(fd) != 0 && status[0] == 0) status[0] = errno;
  return out;
}

int32_t moonbit_community_unix_write_file(const uint8_t *path, const uint8_t *content,
    int32_t len, int32_t create_mode, int32_t permission, int32_t sync_mode, int32_t append) {
  static const int create_flags[] = {
    0, O_TRUNC, O_CREAT, O_CREAT | O_TRUNC, O_CREAT | O_EXCL
  };
  static const int sync_flags[] = { 0, O_DSYNC, O_SYNC };
  if (create_mode < 0 || create_mode > 4 || sync_mode < 0 || sync_mode > 2 || len < 0)
    return EINVAL;
  int flags = O_WRONLY | O_CLOEXEC | create_flags[create_mode] | sync_flags[sync_mode];
  if (append) flags |= O_APPEND;
  int fd;
  do {
    fd = open((const char *)path, flags, (mode_t)permission);
  } while (fd < 0 && errno == EINTR);
  if (fd < 0) return errno;
  int32_t off = 0;
  while (off < len) {
    ssize_t n;
    do {
      n = write(fd, content + off, (size_t)(len - off));
    } while (n < 0 && errno == EINTR);
    if (n <= 0) {
      int error = n < 0 ? errno : EIO;
      close(fd);
      return error;
    }
    off += (int32_t)n;
  }
  return close(fd) == 0 ? 0 : errno;
}

// 1: accessible, 0: missing/denied, -1: unexpected error. Existence probes
// propagate EACCES; permission probes suppress it, matching async/fs.
int32_t moonbit_community_unix_access(const uint8_t *path, int32_t mode, int32_t *status) {
  static const int modes[] = { F_OK, R_OK, W_OK, X_OK };
  status[0] = 0;
  if (mode < 0 || mode > 3) { status[0] = EINVAL; return 0; }
  if (access((const char *)path, modes[mode]) == 0) return 1;
  int error = errno;
  if (error != ENOENT && !(mode != 0 && error == EACCES)) status[0] = error;
  return 0;
}

// ── synchronous processes (posix_spawn; never fork a threaded runtime) ──────
static pid_t waitpid_retry(pid_t pid, int *status) {
  pid_t result;
  do { result = waitpid(pid, status, 0); } while (result < 0 && errno == EINTR);
  return result;
}

// Operation errors are separate from statuses: -signal is a successful wait.
int32_t moonbit_community_unix_process_wait(int32_t pid, int32_t *result) {
  if (pid != -1 && pid <= 0) return EINVAL;
  int status = 0;
  pid_t got = waitpid_retry((pid_t)pid, &status);
  if (got < 0) return errno;
  result[0] = (int32_t)got;
  result[1] = WIFSIGNALED(status) ? -(int32_t)WTERMSIG(status) : (int32_t)WEXITSTATUS(status);
  return 0;
}

// Build vectors pointing into borrowed MoonBit blobs / the parent environment.
// Neither the parent environment nor its current directory is ever modified.
static char **build_argv(const uint8_t *blob, int32_t argc) {
  char **argv = (char **)malloc(((size_t)argc + 1) * sizeof(char *));
  if (!argv) return NULL;
  const char *p = (const char *)blob;
  for (int32_t i = 0; i < argc; i++) {
    argv[i] = (char *)p;
    p += strlen(p) + 1;
  }
  argv[argc] = NULL;
  return argv;
}

static char **build_env(const uint8_t *blob, int32_t count, int inherit) {
  size_t parent_count = 0;
  if (inherit) while (environ[parent_count]) parent_count++;
  char **env = (char **)malloc((parent_count + (size_t)count + 1) * sizeof(char *));
  if (!env) return NULL;
  size_t n = 0;
  const char *p = (const char *)blob;
  for (int32_t i = 0; i < count; i++) {
    env[n++] = (char *)p;
    p += strlen(p) + 1;
  }
  for (size_t i = 0; i < parent_count; i++) {
    const char *entry = environ[i];
    const char *eq = strchr(entry, '=');
    size_t len = eq ? (size_t)(eq - entry) + 1 : strlen(entry) + 1;
    int overridden = 0;
    for (int32_t j = 0; j < count; j++) {
      if (strncmp(entry, env[j], len) == 0) { overridden = 1; break; }
    }
    if (!overridden) env[n++] = environ[i];
  }
  env[n] = NULL;
  return env;
}

// Keep owned descriptors above stdio so dup2 actions cannot clobber a source
// descriptor, including when the parent started with fd 0, 1 or 2 closed.
static int owned_fd(int fd) {
  if (fd < 0) return -1;
  if (fd < 3) {
    int copy = fcntl(fd, F_DUPFD_CLOEXEC, 3);
    int error = errno;
    close(fd);
    errno = error;
    return copy;
  }
  if (fcntl(fd, F_SETFD, FD_CLOEXEC) < 0) {
    int error = errno;
    close(fd);
    errno = error;
    return -1;
  }
  return fd;
}

int64_t moonbit_community_unix_process_open(const uint8_t *path, int32_t output,
    int32_t append, int32_t create_mode, int32_t permission, int32_t *status) {
  status[0] = 0;
  static const int modes[] = {0, O_TRUNC, O_CREAT, O_CREAT | O_TRUNC, O_CREAT | O_EXCL};
  if (create_mode < 0 || create_mode > 4) { status[0] = EINVAL; return -1; }
  int flags = O_CLOEXEC | (output ? O_WRONLY | modes[create_mode] : O_RDONLY);
  if (output && append) flags |= O_APPEND;
  int fd;
  do { fd = open((const char *)path, flags, (mode_t)permission); }
  while (fd < 0 && errno == EINTR);
  fd = owned_fd(fd);
  if (fd < 0) status[0] = errno;
  return (int64_t)fd;
}

void moonbit_community_unix_process_close(int64_t handle) {
  if (handle >= 0) close((int)handle);
}

int32_t moonbit_community_unix_process_pipe(int64_t *handles) {
  int fds[2];
#ifdef __linux__
  if (pipe2(fds, O_CLOEXEC) != 0) return errno;
#else
  if (pipe(fds) != 0) return errno;
#endif
  fds[0] = owned_fd(fds[0]);
  if (fds[0] < 0) { int error = errno; close(fds[1]); return error; }
  fds[1] = owned_fd(fds[1]);
  if (fds[1] < 0) { int error = errno; close(fds[0]); return error; }
  handles[0] = fds[0]; handles[1] = fds[1];
  return 0;
}

int32_t moonbit_community_unix_process_spawn(const uint8_t *blob, int32_t argc,
    const uint8_t *env_blob, int32_t envc, int32_t inherit_env,
    const uint8_t *cwd, int32_t has_cwd, const int64_t *streams,
    int32_t no_console_window, int32_t *result) {
  (void)no_console_window;
  if (argc < 1 || envc < 0) return EINVAL;
  char **argv = build_argv(blob, argc);
  char **env = build_env(env_blob, envc, inherit_env);
  if (!argv || !env) { free(argv); free(env); return ENOMEM; }
  posix_spawn_file_actions_t fa;
  int rc = posix_spawn_file_actions_init(&fa);
  if (rc != 0) { free(argv); free(env); return rc; }
  posix_spawnattr_t attr;
  rc = posix_spawnattr_init(&attr);
  if (rc != 0) {
    posix_spawn_file_actions_destroy(&fa);
    free(argv); free(env);
    return rc;
  }
  // Async runtimes block cancellation signals and may ignore SIGPIPE. Reset
  // only the child's signal state so ordinary programs can still be terminated.
  sigset_t empty_mask, default_signals;
  sigemptyset(&empty_mask);
  sigfillset(&default_signals);
  rc = posix_spawnattr_setsigmask(&attr, &empty_mask);
  if (rc == 0) rc = posix_spawnattr_setsigdefault(&attr, &default_signals);
  if (rc == 0) rc = posix_spawnattr_setflags(&attr,
      POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF);
  // Keep compatibility with macOS before 26, which lacks the standardized name.
#ifdef __APPLE__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#endif
  if (rc == 0 && has_cwd) rc = posix_spawn_file_actions_addchdir_np(&fa, (const char *)cwd);
#ifdef __APPLE__
#pragma clang diagnostic pop
#endif
  for (int i = 0; rc == 0 && i < 3; i++) {
    if (streams[i] != -1) rc = posix_spawn_file_actions_adddup2(&fa, (int)streams[i], i);
  }
  pid_t pid = 0;
  if (rc == 0) {
    // Keep the existing bounded EAGAIN backoff for heavily parallel builds.
    for (int attempt = 0;; attempt++) {
      rc = posix_spawnp(&pid, argv[0], &fa, &attr, argv, env);
      if (rc != EAGAIN || attempt >= 40) break;
      long ms = 5L * (attempt + 1);
      if (ms > 100) ms = 100;
      struct timespec ts = {0, ms * 1000000L};
      nanosleep(&ts, NULL);
    }
  }
  posix_spawnattr_destroy(&attr);
  posix_spawn_file_actions_destroy(&fa);
  free(argv); free(env);
  if (rc != 0) return rc;
  result[0] = (int32_t)pid;
  return 0;
}

// Drain both blocking pipes fairly with poll, taking ownership of both readers.
// Close them before returning, including on an I/O/allocation failure.
// Return stdout || stderr; result[0] marks the split, result[1] is the I/O error.
uint8_t *moonbit_community_unix_process_collect(int64_t first, int64_t second,
                                               int32_t *result) {
  struct pollfd fds[2] = {{(int)first, POLLIN, 0}, {(int)second, POLLIN, 0}};
  Buf buffers[2] = {{0}, {0}};
  result[0] = 0; result[1] = 0;
  while (fds[0].fd >= 0 || fds[1].fd >= 0) {
    int ready;
    do { ready = poll(fds, 2, -1); } while (ready < 0 && errno == EINTR);
    if (ready < 0) { result[1] = errno; break; }
    for (int i = 0; i < 2; i++) {
      if (!fds[i].revents) continue;
      uint8_t chunk[16384];
      ssize_t n;
      do { n = read(fds[i].fd, chunk, sizeof(chunk)); } while (n < 0 && errno == EINTR);
      if (n < 0) { result[1] = errno; break; }
      if (n == 0) {
        if (close(fds[i].fd) != 0 && result[1] == 0) result[1] = errno;
        fds[i].fd = -1; continue;
      }
      if (buffers[0].len + buffers[1].len + (size_t)n > INT32_MAX) {
        result[1] = EOVERFLOW; break;
      }
      if (buf_reserve(&buffers[i], (size_t)n) != 0) {
        result[1] = errno; break;
      }
      memcpy(buffers[i].p + buffers[i].len, chunk, (size_t)n);
      buffers[i].len += (size_t)n;
    }
    if (result[1] != 0) break;
  }
  for (int i = 0; i < 2; i++) {
    if (fds[i].fd >= 0 && close(fds[i].fd) != 0 && result[1] == 0) result[1] = errno;
  }
  uint8_t *out = result[1] ? mb_empty() :
      moonbit_make_bytes((int32_t)(buffers[0].len + buffers[1].len), 0);
  if (!result[1]) {
    result[0] = (int32_t)buffers[0].len;
    if (buffers[0].len) memcpy(out, buffers[0].p, buffers[0].len);
    if (buffers[1].len) memcpy(out + buffers[0].len, buffers[1].p, buffers[1].len);
  }
  free(buffers[0].p); free(buffers[1].p);
  return out;
}

// ── PATH lookup ───────────────────────────────────────────────────────────────
uint8_t *moonbit_community_unix_which(const uint8_t *tool) {
  const char *t = (const char *)tool;
  if (strchr(t, '/') != NULL) {
    if (access(t, X_OK) != 0) return mb_empty();
    return mb_from(t, strlen(t));
  }
  const char *path = getenv("PATH");
  if (!path) return mb_empty();
  char buf[8192];
  const char *seg = path;
  while (*seg) {
    const char *colon = strchr(seg, ':');
    size_t dlen = colon ? (size_t)(colon - seg) : strlen(seg);
    if (dlen > 0 && dlen + 1 + strlen(t) + 1 <= sizeof(buf)) {
      memcpy(buf, seg, dlen);
      buf[dlen] = '/';
      strcpy(buf + dlen + 1, t);
      if (access(buf, X_OK) == 0) return mb_from(buf, strlen(buf));
    }
    if (!colon) break;
    seg = colon + 1;
  }
  return mb_empty();
}

// ── working directory ─────────────────────────────────────────────────────────
uint8_t *moonbit_community_unix_cwd(int32_t *status) {
  char buf[PATH_MAX];
  status[0] = 0;
  if (!getcwd(buf, sizeof(buf))) { status[0] = errno; return mb_empty(); }
  return mb_from(buf, strlen(buf));
}

int32_t moonbit_community_unix_chdir(const uint8_t *path) {
  return chdir((const char *)path) == 0 ? 0 : errno;
}

uint8_t *moonbit_community_unix_realpath(const uint8_t *path, int32_t *status) {
  char buf[PATH_MAX];
  status[0] = 0;
  if (!realpath((const char *)path, buf)) { status[0] = errno; return mb_empty(); }
  return mb_from(buf, strlen(buf));
}

// ── stat surface ──────────────────────────────────────────────────────────────
int32_t moonbit_community_unix_mtime(const uint8_t *path, int32_t follow_symlink,
                                    int64_t *out) {
  struct stat st;
  if ((follow_symlink ? stat((const char *)path, &st) : lstat((const char *)path, &st)) != 0)
    return errno;
#if defined(__APPLE__)
  out[0] = (int64_t)st.st_mtimespec.tv_sec;
  out[1] = (int64_t)st.st_mtimespec.tv_nsec;
#else
  out[0] = (int64_t)st.st_mtim.tv_sec;
  out[1] = (int64_t)st.st_mtim.tv_nsec;
#endif
  return 0;
}

int64_t moonbit_community_unix_file_size(const uint8_t *path, int32_t *status) {
  struct stat st;
  status[0] = 0;
  if (stat((const char *)path, &st) != 0) { status[0] = errno; return 0; }
  if (!S_ISREG(st.st_mode)) { status[0] = EINVAL; return 0; }
  return (int64_t)st.st_size;
}

int32_t moonbit_community_unix_kind(const uint8_t *path, int32_t follow_symlink, int32_t *status) {
  status[0] = 0;
  struct stat st;
  if ((follow_symlink ? stat((const char *)path, &st) : lstat((const char *)path, &st)) != 0)
    { status[0] = errno; return 0; }
  if (S_ISREG(st.st_mode)) return 1;
  if (S_ISDIR(st.st_mode)) return 2;
  if (S_ISLNK(st.st_mode)) return 3;
  if (S_ISSOCK(st.st_mode)) return 4;
  if (S_ISFIFO(st.st_mode)) return 5;
  if (S_ISBLK(st.st_mode)) return 6;
  if (S_ISCHR(st.st_mode)) return 7;
  return 0;
}

uint8_t *moonbit_community_unix_readlink(const uint8_t *path, int32_t *status) {
  char buf[PATH_MAX];
  status[0] = 0;
  ssize_t n = readlink((const char *)path, buf, sizeof(buf));
  if (n < 0 || n == (ssize_t)sizeof(buf)) {
    status[0] = n < 0 ? errno : ENAMETOOLONG;
    return mb_empty();
  }
  return mb_from(buf, (size_t)n);
}

// ── directory listing ─────────────────────────────────────────────────────────
// Each entry is one NUL-terminated name; enumeration does not stat children.
uint8_t *moonbit_community_unix_readdir(const uint8_t *path, int32_t include_hidden,
    int32_t include_special, int32_t *status) {
  status[0] = 0;
  DIR *d = opendir((const char *)path);
  if (!d) { status[0] = errno; return mb_empty(); }
  Buf b = {0};
  struct dirent *e;
  for (;;) {
    errno = 0;
    e = readdir(d);
    if (!e) {
      if (errno != 0) status[0] = errno;
      break;
    }
    if (!include_hidden && e->d_name[0] == '.') continue;
    if (!include_special && (!strcmp(e->d_name, ".") || !strcmp(e->d_name, ".."))) continue;
    size_t nlen = strlen(e->d_name);

    if (buf_reserve(&b, nlen + 1)) { status[0] = errno; break; }
    memcpy(b.p + b.len, e->d_name, nlen);
    b.len += nlen;
    b.p[b.len++] = '\0';
  }
  if (closedir(d) != 0 && status[0] == 0) status[0] = errno;
  uint8_t *out = status[0] ? mb_empty() : mb_from(b.p, b.len);
  free(b.p);
  return out;
}

// ── mkdir -p ──────────────────────────────────────────────────────────────────
static int ensure_dir(const char *path, mode_t permission) {
  if (mkdir(path, permission) == 0) return 0;
  if (errno != EEXIST) return errno;
  struct stat st;
  if (stat(path, &st) != 0) return errno;
  return S_ISDIR(st.st_mode) ? 0 : ENOTDIR;
}

int32_t moonbit_community_unix_mkdir(const uint8_t *path, int32_t permission, int32_t recursive) {
  const char *p = (const char *)path;
  if (mkdir(p, (mode_t)permission) == 0) return 0;
  if (!recursive || errno != ENOENT) return errno;
  size_t len = strlen(p);
  if (len == 0) return ENOENT;
  char *tmp = (char *)malloc(len + 1);
  if (!tmp) return ENOMEM;
  memcpy(tmp, p, len + 1);
  while (len > 1 && tmp[len - 1] == '/') tmp[--len] = '\0';
  for (size_t i = 1; i < len; i++) {
    if (tmp[i] == '/') {
      char saved = tmp[i];
      tmp[i] = '\0';
      int error = ensure_dir(tmp, (mode_t)permission);
      if (error != 0) { free(tmp); return error; }
      tmp[i] = saved;
    }
  }
  int rc = mkdir(tmp, (mode_t)permission) == 0 ? 0 : errno;
  free(tmp);
  return rc;
}

// ── rm -rf (recursive, never follows symlinks) ────────────────────────────────
static int rm_rf(const char *path) {
  struct stat st;
  if (lstat(path, &st) != 0) return errno == ENOENT ? 0 : errno;
  if (S_ISDIR(st.st_mode)) {
    DIR *d = opendir(path);
    if (!d) return errno;
    size_t plen = strlen(path);
    struct dirent *e;
    int rc = 0;
    for (;;) {
      errno = 0;
      e = readdir(d);
      if (!e) {
        if (errno != 0) rc = errno;
        break;
      }
      if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
      size_t nlen = strlen(e->d_name);
      char *child = (char *)malloc(plen + 1 + nlen + 1);
      if (!child) {
        rc = ENOMEM;
        break;
      }
      memcpy(child, path, plen);
      child[plen] = '/';
      memcpy(child + plen + 1, e->d_name, nlen + 1);
      rc = rm_rf(child);
      free(child);
      if (rc != 0) break;
    }
    if (closedir(d) != 0 && rc == 0) rc = errno;
    if (rc != 0) return rc;
    return rmdir(path) == 0 ? 0 : errno;
  } else {
    return unlink(path) == 0 ? 0 : errno;
  }
}

int32_t moonbit_community_unix_remove_all(const uint8_t *path) {
  return rm_rf((const char *)path);
}

int32_t moonbit_community_unix_remove(const uint8_t *path) {
  return unlink((const char *)path) == 0 ? 0 : errno;
}

int32_t moonbit_community_unix_rmdir(const uint8_t *path, int32_t recursive) {
  // Do not let a trailing slash turn a symlink into its target directory.
  char *p = strdup((const char *)path);
  if (!p) return ENOMEM;
  size_t len = strlen(p);
  while (len > 1 && p[len - 1] == '/') p[--len] = '\0';
  struct stat st;
  int rc;
  if (lstat(p, &st) != 0) rc = errno;
  else if (!S_ISDIR(st.st_mode)) rc = ENOTDIR;
  else rc = recursive ? rm_rf(p) : (rmdir(p) == 0 ? 0 : errno);
  free(p);
  return rc;
}

int32_t moonbit_community_unix_hardlink(const uint8_t *src, const uint8_t *dst) {
  return link((const char *)src, (const char *)dst) == 0 ? 0 : errno;
}

int32_t moonbit_community_unix_touch(const uint8_t *path) {
  return utime((const char *)path, NULL) == 0 ? 0 : errno;
}

// ── chmod +x ──────────────────────────────────────────────────────────────────
int32_t moonbit_community_unix_set_executable(const uint8_t *path) {
  struct stat st;
  if (stat((const char *)path, &st) != 0) return errno;
  if (chmod((const char *)path, st.st_mode | 0111) != 0) return errno;
  return 0;
}

#endif // !_WIN32
