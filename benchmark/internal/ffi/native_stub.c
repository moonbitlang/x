#include <time.h>

time_t instant_now() { return time(NULL); }

double instant_elapsed_as_secs_f64(time_t before) {
  return time(NULL) - before;
}

#ifdef _WIN32

#include <Windows.h>
#include <synchapi.h>

void sleep_second(int second) { Sleep(((DWORD)second) * 1000); }
#else

#include <unistd.h>
void sleep_second(int second) { sleep(second); }

#endif