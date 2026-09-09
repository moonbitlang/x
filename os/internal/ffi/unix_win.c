// Native implementation for `moonbitlang/x/os` — the Windows half.
// See unix.c (the POSIX dual) for the shared FFI contract.
//
// The whole impl is guarded by `#ifdef _WIN32`, the mirror of unix.c's `#ifndef`,
// so listing both stubs compiles exactly one per platform.

typedef int moonbit_community_unix_os_win_c_tu_marker; // keep the TU non-empty on POSIX

#ifdef _WIN32

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <process.h>
#include <errno.h>
#include <winioctl.h>

// ── moonbit runtime ───────────────────────────────────────────────────────────
extern uint8_t *moonbit_make_bytes(int32_t size, int value);

static uint8_t *mb_empty(void) { return moonbit_make_bytes(0, 0); }

static uint8_t *mb_from(const void *src, size_t len) {
  uint8_t *out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) memcpy(out, src, len);
  return out;
}

// Preserve the original failure when releasing an owned handle.
static int32_t close_result(HANDLE handle, int32_t error) {
  if (!CloseHandle(handle) && error == 0) return (int32_t)GetLastError();
  return error;
}

// ── UTF-8 <-> UTF-16 ──────────────────────────────────────────────────────────
// UTF-8 (NUL-terminated) -> freshly malloc'd NUL-terminated UTF-16. NULL on error.
static wchar_t *to_wide(const uint8_t *s) {
  int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)s, -1, NULL, 0);
  if (n <= 0) return NULL;
  wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
  if (!w) { SetLastError(ERROR_NOT_ENOUGH_MEMORY); return NULL; }
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)s, -1, w, n)) {
    DWORD error = GetLastError(); free(w); SetLastError(error); return NULL;
  }
  return w;
}

// UTF-16 (`wl` units) -> a fresh moonbit Bytes of UTF-8.
static uint8_t *wide_to_bytes(const wchar_t *w, int wl) {
  int n = WideCharToMultiByte(CP_UTF8, 0, w, wl, NULL, 0, NULL, NULL);
  if (n < 0) n = 0;
  uint8_t *out = moonbit_make_bytes(n, 0);
  if (n > 0) WideCharToMultiByte(CP_UTF8, 0, w, wl, (char *)out, n, NULL, NULL);
  return out;
}

// A growable byte buffer for stdin/capture reads.
typedef struct { uint8_t *p; size_t len; size_t cap; } Buf;
static int buf_reserve(Buf *b, size_t extra) {
  if (extra > INT32_MAX || b->len > INT32_MAX - extra) return ERROR_BUFFER_OVERFLOW;
  if (b->len + extra <= b->cap) return 0;
  size_t nc = b->cap ? b->cap * 2 : 4096;
  while (nc < b->len + extra) nc *= 2;
  uint8_t *np = (uint8_t *)realloc(b->p, nc);
  if (!np) return ERROR_NOT_ENOUGH_MEMORY;
  b->p = np;
  b->cap = nc;
  return 0;
}

// ── host OS family ────────────────────────────────────────────────────────────
int32_t moonbit_community_unix_os_kind(void) { return 2; }

int32_t moonbit_community_unix_available_parallelism(void) {
  DWORD n = GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
  if (n == 0) {
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    n = info.dwNumberOfProcessors;
  }
  return n > 0 ? (int32_t)n : 1;
}

// ── time / pid / stderr / stdin ───────────────────────────────────────────────
int64_t moonbit_community_unix_now_ns(void) {
  LARGE_INTEGER freq, ctr;
  if (!QueryPerformanceFrequency(&freq) || freq.QuadPart == 0) return 0;
  QueryPerformanceCounter(&ctr);
  return (int64_t)((double)ctr.QuadPart * 1e9 / (double)freq.QuadPart);
}

int32_t moonbit_community_unix_getpid(void) { return (int32_t)GetCurrentProcessId(); }

// Match POSIX exit(): flush the CRT streams used by MoonBit's println before
// terminating. ExitProcess bypasses those buffers and loses failure reports.
void moonbit_community_unix_exit(int32_t code) { exit(code); }

int32_t moonbit_community_unix_write_stderr(const uint8_t *s, int32_t len) {
  if (len < 0) return ERROR_INVALID_PARAMETER;
  HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
  DWORD off = 0;
  while (off < (DWORD)len) {
    DWORD written = 0;
    if (!WriteFile(h, s + off, (DWORD)len - off, &written, NULL)) return (int32_t)GetLastError();
    if (!written) return ERROR_WRITE_FAULT;
    off += written;
  }
  return 0;
}

int32_t moonbit_community_unix_stderr_is_terminal(void) {
  HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
  DWORD mode = 0;
  return GetConsoleMode(h, &mode) ? 1 : 0;
}

uint8_t *moonbit_community_unix_read_stdin(int32_t *status) {
  HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
  Buf b = {0};
  status[0] = 0;
  for (;;) {
    status[0] = buf_reserve(&b, 4096);
    if (status[0]) break;
    DWORD n = 0;
    if (!ReadFile(h, b.p + b.len, (DWORD)(b.cap - b.len), &n, NULL)) {
      DWORD error = GetLastError();
      if (error != ERROR_BROKEN_PIPE && error != ERROR_HANDLE_EOF) status[0] = (int32_t)error;
      break;
    }
    if (!n) break;
    b.len += n;
  }
  uint8_t *out = status[0] ? mb_empty() : mb_from(b.p, b.len);
  free(b.p);
  return out;
}

uint8_t *moonbit_community_unix_read_file(const uint8_t *path, int32_t sync_timestamp,
                                         int32_t *status) {
  status[0] = 0;
  wchar_t *wpath = to_wide(path);
  if (!wpath) { status[0] = (int32_t)GetLastError(); return mb_empty(); }
  DWORD access = GENERIC_READ | (sync_timestamp ? GENERIC_WRITE : 0);
  HANDLE h = CreateFileW(wpath, access, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (h == INVALID_HANDLE_VALUE) status[0] = (int32_t)GetLastError();
  free(wpath);
  if (status[0]) return mb_empty();
  Buf b = {0};
  for (;;) {
    status[0] = buf_reserve(&b, 4096);
    if (status[0]) break;
    DWORD n = 0;
    if (!ReadFile(h, b.p + b.len, (DWORD)(b.cap - b.len), &n, NULL)) {
      status[0] = (int32_t)GetLastError(); break;
    }
    if (n == 0) break;
    b.len += n;
  }
  if (sync_timestamp && status[0] == 0 && !FlushFileBuffers(h)) status[0] = (int32_t)GetLastError();
  status[0] = close_result(h, status[0]);
  uint8_t *out = status[0] ? mb_empty() : mb_from(b.p, b.len);
  free(b.p);
  return out;
}

int32_t moonbit_community_unix_write_file(const uint8_t *path, const uint8_t *content,
    int32_t len, int32_t create_mode, int32_t permission, int32_t sync_mode, int32_t append) {
  (void)permission;
  static const DWORD dispositions[] = {
    OPEN_EXISTING, TRUNCATE_EXISTING, OPEN_ALWAYS, CREATE_ALWAYS, CREATE_NEW
  };
  if (create_mode < 0 || create_mode > 4 || sync_mode < 0 || sync_mode > 2 || len < 0)
    return ERROR_INVALID_PARAMETER;
  wchar_t *wpath = to_wide(path);
  if (!wpath) return (int32_t)GetLastError();
  DWORD flags = FILE_ATTRIBUTE_NORMAL | (sync_mode ? FILE_FLAG_WRITE_THROUGH : 0);
  HANDLE h = CreateFileW(wpath, GENERIC_WRITE,
                         FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         NULL, dispositions[create_mode], flags, NULL);
  int32_t error = h == INVALID_HANDLE_VALUE ? (int32_t)GetLastError() : 0;
  free(wpath);
  if (error) return error;
  int32_t off = 0;
  while (off < len) {
    DWORD written = 0;
    OVERLAPPED position = {0};
    position.Offset = position.OffsetHigh = 0xffffffff;
    if (!WriteFile(h, content + off, (DWORD)(len - off), &written, append ? &position : NULL)) {
      error = (int32_t)GetLastError(); break;
    }
    if (written == 0) { error = ERROR_WRITE_FAULT; break; }
    off += (int32_t)written;
  }
  return close_result(h, error);
}

int32_t moonbit_community_unix_access(const uint8_t *path, int32_t mode, int32_t *status) {
  static const DWORD access_modes[] = { 0, GENERIC_READ, GENERIC_WRITE, FILE_EXECUTE };
  status[0] = 0;
  if (mode < 0 || mode > 3) { status[0] = ERROR_INVALID_PARAMETER; return 0; }
  wchar_t *wpath = to_wide(path);
  if (!wpath) { status[0] = (int32_t)GetLastError(); return 0; }
  HANDLE h = CreateFileW(wpath, access_modes[mode],
                         FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         NULL, OPEN_EXISTING,
                         FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS, NULL);
  DWORD error = h == INVALID_HANDLE_VALUE ? GetLastError() : 0;
  free(wpath);
  if (h != INVALID_HANDLE_VALUE) { status[0] = close_result(h, 0); return 1; }
  if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND &&
      !(mode != 0 && error == ERROR_ACCESS_DENIED)) status[0] = (int32_t)error;
  return 0;
}

// ── command-line marshalling (MSVCRT quoting, CommandLineToArgvW's inverse) ────
typedef struct { wchar_t *p; size_t len; size_t cap; int failed; } WBuf;
static void wbuf_push(WBuf *b, wchar_t c) {
  if (b->failed) return;
  if (b->len + 1 > b->cap) {
    size_t cap = b->cap ? b->cap * 2 : 256;
    wchar_t *p = (wchar_t *)realloc(b->p, cap * sizeof(wchar_t));
    if (!p) { b->failed = ERROR_NOT_ENOUGH_MEMORY; return; }
    b->p = p;
    b->cap = cap;
  }
  b->p[b->len++] = c;
}
static void append_arg(WBuf *b, const wchar_t *arg) {
  int needq = (arg[0] == 0);
  for (size_t i = 0; !needq && arg[i]; i++) {
    wchar_t c = arg[i];
    if (c == L' ' || c == L'\t' || c == L'\n' || c == 11 || c == L'"') needq = 1;
  }
  if (needq) wbuf_push(b, L'"');
  size_t s = 0;
  for (;;) {
    size_t nbs = 0;
    while (arg[s] == L'\\') { s++; nbs++; }
    if (arg[s] == L'"') {
      for (size_t k = 0; k < 2 * nbs + 1; k++) wbuf_push(b, L'\\');
      wbuf_push(b, L'"');
      s++;
    } else if (arg[s] == 0) {
      size_t reps = needq ? 2 * nbs : nbs;
      for (size_t k = 0; k < reps; k++) wbuf_push(b, L'\\');
      break;
    } else {
      for (size_t k = 0; k < nbs; k++) wbuf_push(b, L'\\');
      wbuf_push(b, arg[s]);
      s++;
    }
  }
  if (needq) wbuf_push(b, L'"');
}

// Build a writable wide command line from the argv blob. Caller frees.
static wchar_t *build_cmdline(const uint8_t *blob, int32_t argc) {
  WBuf b = {0};
  const char *p = (const char *)blob;
  for (int32_t i = 0; i < argc; i++) {
    wchar_t *w = to_wide((const uint8_t *)p);
    if (!w) { DWORD error = GetLastError(); free(b.p); SetLastError(error); return NULL; }
    if (i != 0) wbuf_push(&b, L' ');
    append_arg(&b, w ? w : L"");
    if (w) free(w);
    p += strlen(p) + 1;
  }
  wbuf_push(&b, 0);
  if (b.failed) { free(b.p); SetLastError((DWORD)b.failed); return NULL; }
  return b.p;
}

// ── synchronous process handles and child-only environment ──────────────────
#define MAX_INFLIGHT 1024
static HANDLE g_handles[MAX_INFLIGHT];
static DWORD g_pids[MAX_INFLIGHT];
static size_t g_ninflight = 0;

static int same_env_key(const wchar_t *a, const wchar_t *b) {
  // Windows' special "=C:=..." drive-directory entries have a leading '='.
  const wchar_t *ae = wcschr(a + (a[0] == L'='), L'=');
  const wchar_t *be = wcschr(b + (b[0] == L'='), L'=');
  size_t al = ae ? (size_t)(ae - a) : wcslen(a);
  size_t bl = be ? (size_t)(be - b) : wcslen(b);
  return al == bl && CompareStringOrdinal(a, (int)al, b, (int)bl, TRUE) == CSTR_EQUAL;
}

static int compare_env(const void *a, const void *b) {
  return CompareStringOrdinal(*(const wchar_t *const *)a, -1,
      *(const wchar_t *const *)b, -1, TRUE) - CSTR_EQUAL;
}

static wchar_t *build_env(const uint8_t *blob, int32_t count, int inherit) {
  wchar_t *parent = inherit ? GetEnvironmentStringsW() : NULL;
  if (inherit && !parent) return NULL;
  size_t parent_count = 0;
  if (parent) for (const wchar_t *p = parent; *p; p += wcslen(p) + 1) parent_count++;
  wchar_t **entries = (wchar_t **)calloc(parent_count + (size_t)count + 1, sizeof(wchar_t *));
  if (!entries) { if (parent) FreeEnvironmentStringsW(parent); SetLastError(ERROR_NOT_ENOUGH_MEMORY); return NULL; }
  size_t n = 0;
  wchar_t *block = NULL;
  DWORD error = ERROR_NOT_ENOUGH_MEMORY;
  const char *p = (const char *)blob;
  for (int32_t i = 0; i < count; i++) {
    wchar_t *entry = to_wide((const uint8_t *)p);
    if (!entry) { error = GetLastError(); goto cleanup; }
    p += strlen(p) + 1;
    size_t j = 0;
    while (j < n && !same_env_key(entries[j], entry)) j++;
    if (j < n) { free(entries[j]); entries[j] = entry; }
    else entries[n++] = entry;
  }
  size_t extra_count = n;
  if (parent) {
    for (const wchar_t *entry = parent; *entry; entry += wcslen(entry) + 1) {
      size_t j = 0;
      while (j < extra_count && !same_env_key(entries[j], entry)) j++;
      if (j < extra_count) continue;
      size_t bytes = (wcslen(entry) + 1) * sizeof(wchar_t);
      entries[n] = (wchar_t *)malloc(bytes);
      if (!entries[n]) goto cleanup;
      memcpy(entries[n++], entry, bytes);
    }
  }
  qsort(entries, n, sizeof(wchar_t *), compare_env);
  size_t units = 2; // An empty environment must still contain two terminators.
  for (size_t i = 0; i < n; i++) units += wcslen(entries[i]) + 1;
  block = (wchar_t *)calloc(units, sizeof(wchar_t));
  if (block) {
    wchar_t *dst = block;
    for (size_t i = 0; i < n; i++) {
      size_t len = wcslen(entries[i]) + 1;
      memcpy(dst, entries[i], len * sizeof(wchar_t));
      dst += len;
    }
  }
cleanup:
  for (size_t i = 0; i < n; i++) free(entries[i]);
  free(entries);
  if (parent) FreeEnvironmentStringsW(parent);
  if (!block) SetLastError(error);
  return block;
}

int64_t moonbit_community_unix_process_open(const uint8_t *path, int32_t output,
    int32_t append, int32_t create_mode, int32_t permission, int32_t *status) {
  (void)permission;
  status[0] = 0;
  static const DWORD modes[] = {OPEN_EXISTING, TRUNCATE_EXISTING, OPEN_ALWAYS, CREATE_ALWAYS, CREATE_NEW};
  if (create_mode < 0 || create_mode > 4) { status[0] = ERROR_INVALID_PARAMETER; return -1; }
  wchar_t *wide = to_wide(path);
  if (!wide) { status[0] = (int32_t)GetLastError(); return -1; }
  HANDLE handle = CreateFileW(wide, output ? GENERIC_WRITE : GENERIC_READ,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      output ? modes[create_mode] : OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (handle == INVALID_HANDLE_VALUE) status[0] = (int32_t)GetLastError();
  free(wide);
  if (status[0]) return -1;
  if (output && append) {
    HANDLE append_handle;
    BOOL ok = DuplicateHandle(GetCurrentProcess(), handle, GetCurrentProcess(),
        &append_handle, FILE_APPEND_DATA | SYNCHRONIZE, FALSE, 0);
    if (!ok) status[0] = (int32_t)GetLastError();
    status[0] = close_result(handle, status[0]);
    if (status[0]) { if (ok) CloseHandle(append_handle); return -1; }
    handle = append_handle;
  }
  return (int64_t)(intptr_t)handle;
}

void moonbit_community_unix_process_close(int64_t handle) {
  if (handle != -1) CloseHandle((HANDLE)(intptr_t)handle);
}

int32_t moonbit_community_unix_process_pipe(int64_t *handles) {
  HANDLE rd, wr;
  // Originals are never inheritable. Spawn duplicates only its own stdio.
  if (!CreatePipe(&rd, &wr, NULL, 0)) return (int32_t)GetLastError();
  handles[0] = (int64_t)(intptr_t)rd;
  handles[1] = (int64_t)(intptr_t)wr;
  return 0;
}

// Borrows application; takes ownership of cmd/env/directory. Used by argv execution
// and the compiler's explicit shell adapter (cmd does not use MSVCRT argv syntax).
static int32_t spawn_cmdline(const wchar_t *application, wchar_t *cmd, wchar_t *env, wchar_t *directory,
    const int64_t *streams, int32_t no_console_window, int32_t *result) {
  // Check capacity before launch, so failure never loses a running child's handle.
  if (g_ninflight >= MAX_INFLIGHT) {
    free(cmd); free(env); free(directory); return ERROR_TOO_MANY_OPEN_FILES;
  }
  STARTUPINFOEXW si;
  memset(&si, 0, sizeof(si));
  si.StartupInfo.cb = sizeof(si);
  si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  HANDLE stdio[3] = {NULL, NULL, NULL};
  HANDLE inherited[3];
  DWORD count = 0;
  int ok = 0;
  int32_t error = 0;
  int attributes_ready = 0;
  for (int i = 0; i < 3; i++) {
    static const DWORD ids[] = {STD_INPUT_HANDLE, STD_OUTPUT_HANDLE, STD_ERROR_HANDLE};
    HANDLE original = streams[i] == -1 ? GetStdHandle(ids[i]) : (HANDLE)(intptr_t)streams[i];
    if (!original || original == INVALID_HANDLE_VALUE) continue;
    if (!DuplicateHandle(GetCurrentProcess(), original, GetCurrentProcess(),
        &stdio[i], 0, TRUE, DUPLICATE_SAME_ACCESS)) goto cleanup;
    inherited[count++] = stdio[i];
  }
  si.StartupInfo.hStdInput = stdio[0];
  si.StartupInfo.hStdOutput = stdio[1];
  si.StartupInfo.hStdError = stdio[2];
  if (count) {
    SIZE_T size = 0;
    InitializeProcThreadAttributeList(NULL, 1, 0, &size);
    si.lpAttributeList = (LPPROC_THREAD_ATTRIBUTE_LIST)malloc(size);
    if (!si.lpAttributeList) { error = ERROR_NOT_ENOUGH_MEMORY; goto cleanup; }
    if (!InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &size)) goto cleanup;
    attributes_ready = 1;
    if (!UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
        inherited, (SIZE_T)count * sizeof(HANDLE), NULL, NULL)) goto cleanup;
  }
  PROCESS_INFORMATION pi;
  DWORD flags = EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT;
  if (no_console_window) flags |= CREATE_NO_WINDOW;
  if (!CreateProcessW(application, cmd, NULL, NULL, count != 0, flags, env, directory,
      &si.StartupInfo, &pi)) goto cleanup;
  CloseHandle(pi.hThread);
  g_handles[g_ninflight] = pi.hProcess;
  g_pids[g_ninflight++] = pi.dwProcessId;
  result[0] = (int32_t)pi.dwProcessId;
  ok = 1;
cleanup:
  if (!ok && error == 0) error = (int32_t)GetLastError();
  if (attributes_ready) DeleteProcThreadAttributeList(si.lpAttributeList);
  free(si.lpAttributeList);
  for (int i = 0; i < 3; i++) if (stdio[i]) CloseHandle(stdio[i]);
  free(cmd); free(env); free(directory);
  return ok ? 0 : error;
}

int32_t moonbit_community_unix_process_spawn(const uint8_t *blob, int32_t argc,
    const uint8_t *env_blob, int32_t envc, int32_t inherit_env,
    const uint8_t *cwd, int32_t has_cwd, const int64_t *streams,
    int32_t no_console_window, int32_t *result) {
  if (argc < 1 || envc < 0) return ERROR_INVALID_PARAMETER;
  wchar_t *cmd = build_cmdline(blob, argc);
  if (!cmd) return (int32_t)GetLastError();
  wchar_t *env = build_env(env_blob, envc, inherit_env);
  if (!env) { int32_t error = (int32_t)GetLastError(); free(cmd); return error; }
  wchar_t *directory = has_cwd ? to_wide(cwd) : NULL;
  if (has_cwd && !directory) {
    int32_t error = (int32_t)GetLastError(); free(cmd); free(env); return error;
  }
  return spawn_cmdline(NULL, cmd, env, directory, streams, no_console_window, result);
}

// A drive-relative path (C:cmd.exe) or rooted path (\cmd.exe) still depends on
// the parent's cwd. Only drive-absolute and UNC paths are suitable shell overrides.
static int absolute_shell_path(const wchar_t *path) {
  const wchar_t *unc = NULL;
  if (wcsncmp(path, L"\\\\?\\", 4) == 0) {
    path += 4;
    if (_wcsnicmp(path, L"UNC\\", 4) == 0) unc = path + 4;
  } else if (path[0] == L'\\' && path[1] == L'\\') {
    unc = path + 2;
  }
  if (unc) {
    const wchar_t *share = wcschr(unc, L'\\');
    return share && share > unc && share[1] && share[1] != L'\\' &&
        !(share == unc + 1 && (unc[0] == L'.' || unc[0] == L'?'));
  }
  return ((path[0] >= L'A' && path[0] <= L'Z') ||
          (path[0] >= L'a' && path[0] <= L'z')) &&
      path[1] == L':' && (path[2] == L'\\' || path[2] == L'/');
}

static wchar_t *resolve_shell(void) {
  DWORD capacity = GetEnvironmentVariableW(L"COMSPEC", NULL, 0);
  if (capacity) {
    wchar_t *path = (wchar_t *)malloc((size_t)capacity * sizeof(wchar_t));
    if (!path) return NULL;
    DWORD length = GetEnvironmentVariableW(L"COMSPEC", path, capacity);
    if (length > 0 && length < capacity && absolute_shell_path(path)) return path;
    free(path);
    if (length >= capacity) return NULL; // The override grew; never use truncated data.
  }
  // Do not search cwd/PATH, or trust the overridable SystemRoot environment value.
  UINT size = GetSystemDirectoryW(NULL, 0);
  if (!size) return NULL;
  wchar_t *path = (wchar_t *)malloc(((size_t)size + 8) * sizeof(wchar_t));
  if (!path) return NULL;
  UINT length = GetSystemDirectoryW(path, size);
  if (!length || length >= size) { free(path); return NULL; }
  if (path[length - 1] != L'\\') path[length++] = L'\\';
  memcpy(path + length, L"cmd.exe", 8 * sizeof(wchar_t));
  return path;
}

// Private compatibility entry point for src/util/os, not part of unix/process.
// Preserve shell source verbatim: MSVCRT quoting would turn embedded quotes into
// backslash-quotes, which cmd.exe interprets differently.
int32_t moonbit_community_unix_process_spawn_shell(const uint8_t *source, int32_t *result) {
  wchar_t *inner = to_wide(source);
  wchar_t *env = build_env((const uint8_t *)"", 0, 1);
  wchar_t *shell = resolve_shell();
  if (!inner || !env || !shell) { free(inner); free(env); free(shell); return -1; }
  WBuf cmd = {0};
  append_arg(&cmd, shell);
  const wchar_t *prefix = L" /C ";
  for (size_t i = 0; prefix[i]; i++) wbuf_push(&cmd, prefix[i]);
  for (size_t i = 0; inner[i]; i++) wbuf_push(&cmd, inner[i]);
  wbuf_push(&cmd, 0);
  free(inner);
  if (cmd.failed) { free(cmd.p); free(env); free(shell); return -1; }
  const int64_t streams[] = {-1, -1, -1};
  int32_t status = spawn_cmdline(shell, cmd.p, env, NULL, streams, 0, result);
  free(shell);
  return status;
}

int32_t moonbit_community_unix_process_wait(int32_t pid, int32_t *result) {
  if (g_ninflight == 0 || (pid != -1 && pid <= 0)) return ERROR_INVALID_PARAMETER;
  size_t idx = 0;
  if (pid != -1) {
    while (idx < g_ninflight && g_pids[idx] != (DWORD)pid) idx++;
    if (idx == g_ninflight) return ERROR_INVALID_PARAMETER;
    if (WaitForSingleObject(g_handles[idx], INFINITE) != WAIT_OBJECT_0) return (int32_t)GetLastError();
  } else {
    for (;;) {
      // Scan all children, not only the first Windows wait-set (64 handles).
      for (idx = 0; idx < g_ninflight; idx++) {
        DWORD ready = WaitForSingleObject(g_handles[idx], 0);
        if (ready == WAIT_OBJECT_0) break;
        if (ready == WAIT_FAILED) return (int32_t)GetLastError();
      }
      if (idx < g_ninflight) break;
      DWORD batch = (DWORD)(g_ninflight < MAXIMUM_WAIT_OBJECTS ? g_ninflight : MAXIMUM_WAIT_OBJECTS);
      DWORD ready = WaitForMultipleObjects(batch, g_handles, FALSE,
          g_ninflight > MAXIMUM_WAIT_OBJECTS ? 10 : INFINITE);
      if (ready == WAIT_FAILED) return (int32_t)GetLastError();
    }
  }
  DWORD code = 0;
  int32_t error = GetExitCodeProcess(g_handles[idx], &code) ? 0 : (int32_t)GetLastError();
  result[0] = (int32_t)g_pids[idx];
  result[1] = (int32_t)code; // 259 and high-bit exit codes are valid after wait.
  error = close_result(g_handles[idx], error);
  g_ninflight--;
  g_handles[idx] = g_handles[g_ninflight];
  g_pids[idx] = g_pids[g_ninflight];
  return error;
}

typedef struct { HANDLE handle; Buf buffer; int failed; } CaptureReader;

// A native worker only uses malloc/Win32; it must not enter the MoonBit runtime.
static unsigned __stdcall read_capture(void *context) {
  CaptureReader *reader = (CaptureReader *)context;
  uint8_t chunk[16384];
  for (;;) {
    DWORD n = 0;
    if (!ReadFile(reader->handle, chunk, sizeof(chunk), &n, NULL)) {
      DWORD error = GetLastError();
      if (error != ERROR_BROKEN_PIPE && !reader->failed) reader->failed = (int32_t)error;
      break;
    }
    if (n == 0) break;
    // Keep draining/discarding after allocation failure, so the other reader
    // and the child can still finish without a full-pipe deadlock.
    if (reader->failed) continue;
    reader->failed = buf_reserve(&reader->buffer, n);
    if (reader->failed) continue;
    memcpy(reader->buffer.p + reader->buffer.len, chunk, n);
    reader->buffer.len += n;
  }
  reader->failed = close_result(reader->handle, reader->failed);
  return 0;
}

// Takes ownership of both readers, including setup and I/O failure paths.
uint8_t *moonbit_community_unix_process_collect(int64_t first, int64_t second,
                                               int32_t *result) {
  CaptureReader readers[2] = {
    {(HANDLE)(intptr_t)first, {0}, 0}, {(HANDLE)(intptr_t)second, {0}, 0}
  };
  result[0] = 0; result[1] = 0;
  HANDLE thread = NULL;
  if (second != -1) {
    // The worker uses the CRT allocator; _beginthreadex also cleans up CRT TLS.
    thread = (HANDLE)_beginthreadex(NULL, 0, read_capture, &readers[1], 0, NULL);
    if (!thread) {
      unsigned long error = 0;
      _get_doserrno(&error);
      result[1] = error ? (int32_t)error : ERROR_NOT_ENOUGH_MEMORY;
      CloseHandle(readers[0].handle); CloseHandle(readers[1].handle);
      return mb_empty();
    }
  }
  read_capture(&readers[0]);
  if (thread) {
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
  }
  size_t len = readers[0].buffer.len + readers[1].buffer.len;
  result[1] = readers[0].failed ? readers[0].failed : readers[1].failed;
  if (!result[1] && len > INT32_MAX) result[1] = ERROR_BUFFER_OVERFLOW;
  uint8_t *out = result[1] ? mb_empty() : moonbit_make_bytes((int32_t)len, 0);
  if (!result[1]) {
    result[0] = (int32_t)readers[0].buffer.len;
    if (readers[0].buffer.len) memcpy(out, readers[0].buffer.p, readers[0].buffer.len);
    if (readers[1].buffer.len) memcpy(out + readers[0].buffer.len, readers[1].buffer.p, readers[1].buffer.len);
  }
  free(readers[0].buffer.p); free(readers[1].buffer.p);
  return out;
}

// ── PATH lookup (directory order first, then PATHEXT within each directory) ──
static int has_extension(const wchar_t *path) {
  const wchar_t *base = wcsrchr(path, L'\\');
  const wchar_t *slash = wcsrchr(path, L'/');
  if (!base || (slash && slash > base)) base = slash;
  base = base ? base + 1 : path;
  return wcschr(base, L'.') != NULL;
}

static wchar_t *which_env(const wchar_t *name) {
  DWORD size = GetEnvironmentVariableW(name, NULL, 0);
  if (!size) return NULL;
  wchar_t *value = (wchar_t *)malloc((size_t)size * sizeof(wchar_t));
  if (!value) return NULL;
  DWORD n = GetEnvironmentVariableW(name, value, size);
  if (!n || n >= size) { free(value); return NULL; }
  return value;
}

static DWORD which_candidate(const wchar_t *dir, const wchar_t *tool,
                             const wchar_t *ext, wchar_t *buf, DWORD size) {
  DWORD n = SearchPathW(dir, tool, ext, size, buf, NULL);
  if (!n || n >= size) return 0;
  DWORD attrs = GetFileAttributesW(buf);
  return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY) ? n : 0;
}

static DWORD which_in_dir(const wchar_t *dir, const wchar_t *tool,
                          wchar_t *extensions, wchar_t *buf, DWORD size) {
  DWORD n = which_candidate(dir, tool, NULL, buf, size);
  if (n || has_extension(tool)) return n;
  for (wchar_t *ext = extensions; *ext;) {
    wchar_t *end = wcschr(ext, L';');
    if (end) *end = 0;
    if (ext[0] == L'.') n = which_candidate(dir, tool, ext, buf, size);
    if (end) *end = L';';
    if (n || !end) break;
    ext = end + 1;
  }
  return n;
}

uint8_t *moonbit_community_unix_which(const uint8_t *tool) {
  wchar_t *w = to_wide(tool);
  if (!w) return mb_empty();
  wchar_t *path = which_env(L"PATH");
  wchar_t *extensions = which_env(L"PATHEXT");
  wchar_t defaults[] = L".COM;.EXE;.BAT;.CMD";
  wchar_t *exts = extensions ? extensions : defaults;
  wchar_t buf[4096];
  DWORD n = 0;
  if (wcschr(w, L'\\') || wcschr(w, L'/') || wcschr(w, L':')) {
    n = which_in_dir(L".", w, exts, buf, 4096);
  } else if (path) {
    // Searching the entire PATH once per extension lets a later .exe hide an
    // earlier .cmd. An explicit directory also avoids SearchPath's implicit
    // application/system-directory precedence over the caller's PATH.
    for (wchar_t *dir = path; *dir;) {
      wchar_t *end = wcschr(dir, L';');
      if (end) *end = 0;
      size_t len = wcslen(dir);
      if (len >= 2 && dir[0] == L'"' && dir[len - 1] == L'"') {
        dir[len - 1] = 0;
        dir++;
      }
      if (*dir) n = which_in_dir(dir, w, exts, buf, 4096);
      if (n || !end) break;
      dir = end + 1;
    }
  }
  free(path); free(extensions); free(w);
  return n ? wide_to_bytes(buf, (int)n) : mb_empty();
}

// ── working directory ─────────────────────────────────────────────────────────
uint8_t *moonbit_community_unix_cwd(int32_t *status) {
  status[0] = 0;
  DWORD n = GetCurrentDirectoryW(0, NULL);
  if (n == 0) { status[0] = (int32_t)GetLastError(); return mb_empty(); }
  wchar_t *buf = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
  if (!buf) { status[0] = ERROR_NOT_ENOUGH_MEMORY; return mb_empty(); }
  DWORD got = GetCurrentDirectoryW(n, buf);
  if (got == 0) status[0] = (int32_t)GetLastError();
  else if (got >= n) status[0] = ERROR_INSUFFICIENT_BUFFER;
  uint8_t *out = status[0] ? mb_empty() : wide_to_bytes(buf, (int)got);
  free(buf);
  return out;
}

int32_t moonbit_community_unix_chdir(const uint8_t *path) {
  wchar_t *w = to_wide(path);
  if (!w) return (int32_t)GetLastError();
  int32_t error = SetCurrentDirectoryW(w) ? 0 : (int32_t)GetLastError();
  free(w);
  return error;
}

uint8_t *moonbit_community_unix_realpath(const uint8_t *path, int32_t *status) {
  status[0] = 0;
  wchar_t *w = to_wide(path);
  if (!w) { status[0] = (int32_t)GetLastError(); return mb_empty(); }
  HANDLE h = CreateFileW(w, 0, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                         OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (h == INVALID_HANDLE_VALUE) status[0] = (int32_t)GetLastError();
  free(w);
  if (status[0]) return mb_empty();
  wchar_t buf[4096];
  DWORD n = GetFinalPathNameByHandleW(h, buf, 4096, FILE_NAME_NORMALIZED);
  if (n == 0) status[0] = (int32_t)GetLastError();
  else if (n >= 4096) status[0] = ERROR_INSUFFICIENT_BUFFER;
  status[0] = close_result(h, status[0]);
  if (status[0]) return mb_empty();
  // Match async/fs: an extended UNC path becomes a regular UNC path, while
  // drive-absolute paths lose only their extended prefix. Other namespaces
  // must keep the prefix or they would become relative paths.
  wchar_t *start = buf;
  if (n >= 8 && wcsncmp(buf, L"\\\\?\\UNC\\", 8) == 0) {
    start = buf + 6;
    start[0] = L'\\';
    n -= 6;
  } else if (n >= 7 && wcsncmp(buf, L"\\\\?\\", 4) == 0 &&
             ((buf[4] >= L'A' && buf[4] <= L'Z') ||
              (buf[4] >= L'a' && buf[4] <= L'z')) &&
             buf[5] == L':' && buf[6] == L'\\') {
    start = buf + 4;
    n -= 4;
  }
  return wide_to_bytes(start, (int)n);
}

// ── stat surface ──────────────────────────────────────────────────────────────
// Keep seconds and nanoseconds separate to avoid overflow and preserve times
// before 1970. The nanosecond component is always nonnegative.
static void filetime_to_unix_time(const FILETIME *ft, int64_t *out) {
  ULARGE_INTEGER u;
  u.LowPart = ft->dwLowDateTime;
  u.HighPart = ft->dwHighDateTime;
  out[0] = (int64_t)(u.QuadPart / 10000000ULL) - 11644473600LL;
  out[1] = (int64_t)(u.QuadPart % 10000000ULL) * 100LL;
}

static HANDLE metadata_handle(const uint8_t *path, int32_t follow_symlink, int32_t *status) {
  status[0] = 0;
  wchar_t *w = to_wide(path);
  if (!w) { status[0] = (int32_t)GetLastError(); return INVALID_HANDLE_VALUE; }
  HANDLE h = CreateFileW(w, FILE_READ_ATTRIBUTES,
                         FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         NULL, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS |
                         (follow_symlink ? 0 : FILE_FLAG_OPEN_REPARSE_POINT), NULL);
  if (h == INVALID_HANDLE_VALUE) status[0] = (int32_t)GetLastError();
  free(w);
  return h;
}

int32_t moonbit_community_unix_mtime(const uint8_t *path, int32_t follow_symlink,
                                    int64_t *out) {
  int32_t error = 0;
  HANDLE h = metadata_handle(path, follow_symlink, &error);
  if (error) return error;
  FILETIME time;
  if (GetFileTime(h, NULL, NULL, &time)) filetime_to_unix_time(&time, out);
  else error = (int32_t)GetLastError();
  return close_result(h, error);
}

int64_t moonbit_community_unix_file_size(const uint8_t *path, int32_t *status) {
  HANDLE h = metadata_handle(path, 1, status);
  if (status[0]) return 0;
  BY_HANDLE_FILE_INFORMATION info;
  int64_t result = 0;
  SetLastError(0);
  DWORD type = GetFileType(h);
  if (type == FILE_TYPE_UNKNOWN && GetLastError()) status[0] = (int32_t)GetLastError();
  else if (type != FILE_TYPE_DISK) status[0] = ERROR_INVALID_PARAMETER;
  else if (!GetFileInformationByHandle(h, &info)) status[0] = (int32_t)GetLastError();
  else if (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) status[0] = ERROR_INVALID_PARAMETER;
  else {
    uint64_t size = ((uint64_t)info.nFileSizeHigh << 32) | info.nFileSizeLow;
    if (size > INT64_MAX) status[0] = ERROR_FILE_TOO_LARGE;
    else result = (int64_t)size;
  }
  status[0] = close_result(h, status[0]);
  return result;
}

int32_t moonbit_community_unix_kind(const uint8_t *path, int32_t follow_symlink, int32_t *status) {
  HANDLE h = metadata_handle(path, follow_symlink, status);
  if (status[0]) return 0;
  SetLastError(0);
  DWORD type = GetFileType(h);
  int32_t result = 0;
  if (type == FILE_TYPE_DISK) {
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(h, &info)) status[0] = (int32_t)GetLastError();
    else if (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) result = 3;
    else if (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) result = 2;
    else result = 1;
  } else if (type == FILE_TYPE_CHAR) result = 7;
  else if (type == FILE_TYPE_PIPE) result = 5;
  else if (GetLastError() != 0) status[0] = (int32_t)GetLastError();
  status[0] = close_result(h, status[0]);
  return result;
}

uint8_t *moonbit_community_unix_readlink(const uint8_t *path, int32_t *status) {
  // Open the reparse point itself: the target may be relative or nonexistent.
  status[0] = 0;
  wchar_t *w = to_wide(path);
  if (!w) { status[0] = (int32_t)GetLastError(); return mb_empty(); }
  HANDLE h = CreateFileW(w, 0, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL);
  if (h == INVALID_HANDLE_VALUE) status[0] = (int32_t)GetLastError();
  free(w);
  if (status[0]) return mb_empty();
  union { uint64_t align; uint8_t bytes[MAXIMUM_REPARSE_DATA_BUFFER_SIZE]; } buffer;
  DWORD length = 0;
  if (!DeviceIoControl(h, FSCTL_GET_REPARSE_POINT, NULL, 0, buffer.bytes,
      sizeof(buffer.bytes), &length, NULL)) status[0] = (int32_t)GetLastError();
  status[0] = close_result(h, status[0]);
  if (status[0]) return mb_empty();
  // REPARSE_DATA_BUFFER has an 8-byte header, followed by the tag's payload.
  DWORD tag;
  USHORT payload, fields[4];
  if (length < 16) { status[0] = ERROR_INVALID_REPARSE_DATA; return mb_empty(); }
  memcpy(&tag, buffer.bytes, sizeof(tag));
  memcpy(&payload, buffer.bytes + 4, sizeof(payload));
  size_t base;
  if (tag == IO_REPARSE_TAG_SYMLINK) base = 20; // includes the relative-link flag
  else if (tag == IO_REPARSE_TAG_MOUNT_POINT) base = 16;
  else { status[0] = ERROR_NOT_SUPPORTED; return mb_empty(); }
  size_t end = (size_t)payload + 8;
  if (end > length || end < base) { status[0] = ERROR_INVALID_REPARSE_DATA; return mb_empty(); }
  memcpy(fields, buffer.bytes + 8, sizeof(fields));
  // The substitute name is authoritative; the print name may be a display label.
  DWORD flags = 0;
  if (tag == IO_REPARSE_TAG_SYMLINK) memcpy(&flags, buffer.bytes + 16, sizeof(flags));
  size_t offset = fields[0];
  size_t bytes = fields[1];
  if ((offset | bytes) & 1 || base + offset + bytes > end) {
    status[0] = ERROR_INVALID_REPARSE_DATA; return mb_empty();
  }
  const wchar_t *target = (const wchar_t *)(buffer.bytes + base + offset);
  int units = (int)(bytes / sizeof(wchar_t));
  if (!(flags & 1) && units >= 4 && target[0] == 0x5c && target[1] == L'?' && target[2] == L'?' && target[3] == 0x5c) {
    // Translate the NT namespace prefix to the equivalent Win32 extended prefix.
    // Keeping it preserves volume-GUID, UNC, and extended-name semantics.
    wchar_t win32[MAXIMUM_REPARSE_DATA_BUFFER_SIZE / sizeof(wchar_t)];
    memcpy(win32, target, (size_t)units * sizeof(wchar_t));
    win32[1] = 0x5c;
    return wide_to_bytes(win32, units);
  }
  return wide_to_bytes(target, units);
}

// ── directory listing (FindFirstFileW/FindNextFileW) ──────────────────────────
uint8_t *moonbit_community_unix_readdir(const uint8_t *path, int32_t include_hidden,
    int32_t include_special, int32_t *status) {
  status[0] = 0;
  size_t plen = strlen((const char *)path);
  uint8_t *pat = (uint8_t *)malloc(plen + 3);
  if (!pat) { status[0] = ERROR_NOT_ENOUGH_MEMORY; return mb_empty(); }
  memcpy(pat, path, plen);
  size_t cursor = plen;
  if (cursor == 0 || (pat[cursor - 1] != '/' && pat[cursor - 1] != 0x5c)) pat[cursor++] = 0x5c;
  pat[cursor++] = '*';
  pat[cursor] = '\0';
  wchar_t *wpat = to_wide(pat);
  if (!wpat) status[0] = (int32_t)GetLastError();
  free(pat);
  if (status[0]) return mb_empty();
  WIN32_FIND_DATAW fd;
  HANDLE h = FindFirstFileW(wpat, &fd);
  if (h == INVALID_HANDLE_VALUE) status[0] = (int32_t)GetLastError();
  free(wpat);
  if (status[0]) return mb_empty();
  Buf b = {0};
  do {
    if (!include_hidden && (fd.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN)) continue;
    if (!include_special &&
        (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L".."))) continue;
    int count = WideCharToMultiByte(CP_UTF8, 0, fd.cFileName, -1, NULL, 0, NULL, NULL);
    if (count <= 0) { status[0] = (int32_t)GetLastError(); break; }
    size_t nlen = (size_t)count - 1;
    status[0] = buf_reserve(&b, nlen + 1);
    if (status[0]) break;
    if (!WideCharToMultiByte(CP_UTF8, 0, fd.cFileName, -1,
                             (char *)b.p + b.len, count, NULL, NULL)) {
      status[0] = (int32_t)GetLastError();
      break;
    }
    b.len += (size_t)count;
  } while (FindNextFileW(h, &fd));
  if (status[0] == 0 && GetLastError() != ERROR_NO_MORE_FILES) status[0] = (int32_t)GetLastError();
  if (!FindClose(h) && status[0] == 0) status[0] = (int32_t)GetLastError();
  uint8_t *out = status[0] ? mb_empty() : mb_from(b.p, b.len);
  free(b.p);
  return out;
}

// ── mkdir -p ──────────────────────────────────────────────────────────────────
static int ensure_dir_w(const wchar_t *path) {
  if (CreateDirectoryW(path, NULL)) return 0;
  DWORD error = GetLastError();
  if (error != ERROR_ALREADY_EXISTS) return (int32_t)error;
  DWORD attrs = GetFileAttributesW(path);
  if (attrs == INVALID_FILE_ATTRIBUTES) return (int32_t)GetLastError();
  return (attrs & FILE_ATTRIBUTE_DIRECTORY) ? 0 : ERROR_DIRECTORY;
}

static int is_path_separator_w(wchar_t c) {
  return c == L'/' || c == L'\\';
}

int32_t moonbit_community_unix_mkdir(const uint8_t *path, int32_t permission, int32_t recursive) {
  (void)permission;
  wchar_t *w = to_wide(path);
  if (!w) return (int32_t)GetLastError();
  if (CreateDirectoryW(w, NULL)) { free(w); return 0; }
  int32_t error = (int32_t)GetLastError();
  if (!recursive || error != ERROR_PATH_NOT_FOUND) { free(w); return error; }
  size_t len = wcslen(w);
  while (len > 1 && is_path_separator_w(w[len - 1])) w[--len] = 0;
  if (len == 0) { free(w); return ERROR_PATH_NOT_FOUND; }
  size_t start = 1;
  if (len >= 2 && w[1] == L':') {
    start = len >= 3 && is_path_separator_w(w[2]) ? 3 : 2;
  } else if (len >= 2 && is_path_separator_w(w[0]) &&
             is_path_separator_w(w[1])) {
    // A UNC prefix (`\\server\share`) already exists and is not creatable.
    size_t i = 2;
    while (i < len && !is_path_separator_w(w[i])) i++;
    if (i < len) i++;
    while (i < len && !is_path_separator_w(w[i])) i++;
    start = i < len ? i + 1 : len;
  }
  for (size_t i = start; i < len; i++) {
    if (is_path_separator_w(w[i])) {
      wchar_t saved = w[i];
      w[i] = 0;
      error = ensure_dir_w(w);
      if (error != 0) { free(w); return error; }
      w[i] = saved;
    }
  }
  int rc = CreateDirectoryW(w, NULL) ? 0 : (int32_t)GetLastError();
  free(w);
  return rc;
}

// ── rm -rf (recursive) ────────────────────────────────────────────────────────
static int rm_rf_w(wchar_t *path) {
  DWORD attr = GetFileAttributesW(path);
  if (attr == INVALID_FILE_ATTRIBUTES) {
    DWORD error = GetLastError();
    return error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND ? 0 : (int32_t)error;
  }
  if ((attr & FILE_ATTRIBUTE_DIRECTORY) && !(attr & FILE_ATTRIBUTE_REPARSE_POINT)) {
    size_t plen = wcslen(path);
    wchar_t *pat = (wchar_t *)malloc((plen + 3) * sizeof(wchar_t));
    if (!pat) return ERROR_NOT_ENOUGH_MEMORY;
    memcpy(pat, path, plen * sizeof(wchar_t));
    pat[plen] = 0x5c; pat[plen + 1] = L'*'; pat[plen + 2] = 0;
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(pat, &fd);
    int32_t error = h == INVALID_HANDLE_VALUE ? (int32_t)GetLastError() : 0;
    free(pat);
    if (h == INVALID_HANDLE_VALUE && error != ERROR_FILE_NOT_FOUND) return error;
    if (h != INVALID_HANDLE_VALUE) {
      do {
        if (!wcscmp(fd.cFileName, L".") || !wcscmp(fd.cFileName, L"..")) continue;
        size_t nlen = wcslen(fd.cFileName);
        wchar_t *child = (wchar_t *)malloc((plen + nlen + 2) * sizeof(wchar_t));
        if (!child) { error = ERROR_NOT_ENOUGH_MEMORY; break; }
        memcpy(child, path, plen * sizeof(wchar_t));
        child[plen] = 0x5c;
        memcpy(child + plen + 1, fd.cFileName, (nlen + 1) * sizeof(wchar_t));
        error = rm_rf_w(child);
        free(child);
        if (error) break;
      } while (FindNextFileW(h, &fd));
      if (!error && GetLastError() != ERROR_NO_MORE_FILES) error = (int32_t)GetLastError();
      if (!FindClose(h) && !error) error = (int32_t)GetLastError();
      if (error) return error;
    }
    return RemoveDirectoryW(path) ? 0 : (int32_t)GetLastError();
  }
  return (attr & FILE_ATTRIBUTE_DIRECTORY ? RemoveDirectoryW(path) : DeleteFileW(path))
      ? 0 : (int32_t)GetLastError();
}

int32_t moonbit_community_unix_remove_all(const uint8_t *path) {
  wchar_t *w = to_wide(path);
  if (!w) return (int32_t)GetLastError();
  int rc = rm_rf_w(w);
  free(w);
  return rc;
}

int32_t moonbit_community_unix_remove(const uint8_t *path) {
  wchar_t *w = to_wide(path);
  if (!w) return (int32_t)GetLastError();
  DWORD attrs = GetFileAttributesW(w);
  int rc;
  if (attrs != INVALID_FILE_ATTRIBUTES &&
      (attrs & FILE_ATTRIBUTE_DIRECTORY) && (attrs & FILE_ATTRIBUTE_REPARSE_POINT)) {
    rc = RemoveDirectoryW(w) ? 0 : (int32_t)GetLastError(); // unlink a directory junction, not its target
  } else {
    rc = DeleteFileW(w) ? 0 : (int32_t)GetLastError();
  }
  free(w);
  return rc;
}

int32_t moonbit_community_unix_rmdir(const uint8_t *path, int32_t recursive) {
  wchar_t *w = to_wide(path);
  if (!w) return (int32_t)GetLastError();
  size_t len = wcslen(w);
  while (len > 1 && is_path_separator_w(w[len - 1]) &&
         !(len == 3 && w[1] == L':')) w[--len] = 0;
  DWORD attrs = GetFileAttributesW(w);
  int rc = attrs == INVALID_FILE_ATTRIBUTES ? (int32_t)GetLastError() : ERROR_DIRECTORY;
  if (attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY) &&
      !(attrs & FILE_ATTRIBUTE_REPARSE_POINT)) {
    rc = recursive ? rm_rf_w(w) : (RemoveDirectoryW(w) ? 0 : (int32_t)GetLastError());
  }
  free(w);
  return rc;
}

int32_t moonbit_community_unix_hardlink(const uint8_t *src, const uint8_t *dst) {
  wchar_t *wsrc = to_wide(src);
  if (!wsrc) return (int32_t)GetLastError();
  wchar_t *wdst = to_wide(dst);
  if (!wdst) { int32_t error = (int32_t)GetLastError(); free(wsrc); return error; }
  int32_t error = CreateHardLinkW(wdst, wsrc, NULL) ? 0 : (int32_t)GetLastError();
  free(wsrc); free(wdst);
  return error;
}

int32_t moonbit_community_unix_touch(const uint8_t *path) {
  wchar_t *wpath = to_wide(path);
  if (!wpath) return (int32_t)GetLastError();
  HANDLE h = CreateFileW(wpath, FILE_WRITE_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE,
                         NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  int32_t error = h == INVALID_HANDLE_VALUE ? (int32_t)GetLastError() : 0;
  free(wpath);
  if (error) return error;
  FILETIME now;
  GetSystemTimeAsFileTime(&now);
  int rc = SetFileTime(h, NULL, NULL, &now) ? 0 : (int32_t)GetLastError();
  return close_result(h, rc);
}

// ── chmod +x: no-op on Windows (executability is extension-based) ─────────────
int32_t moonbit_community_unix_set_executable(const uint8_t *path) { (void)path; return 0; }

#endif // _WIN32
