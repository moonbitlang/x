#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "moonbit.h"

#ifdef _WIN32
#include <windows.h>
#include <direct.h>
#else
#include <dirent.h>
#include <unistd.h>
#endif

struct moonbit_ref_array* get_env_vars() {
#ifdef _WIN32
    // Get environment block
    LPCH env_block = GetEnvironmentStrings();
    if (env_block == NULL) {
        return moonbit_make_ref_array(0, NULL);
    }

    // Count variables and create array
    int count = 0;
    LPCH env = env_block;
    while (*env) {
        count++;
        env += strlen(env) + 1;
    }

    struct moonbit_ref_array* result = moonbit_make_ref_array(count * 2, NULL);
    
    // Parse variables
    env = env_block;
    int i = 0;
    while (*env) {
        char *equals = strchr(env, '=');
        if (equals != NULL) {
            size_t key_len = equals - env;
            size_t val_len = strlen(equals + 1);
            
            struct moonbit_bytes* key = moonbit_make_bytes(key_len, 0);
            memcpy(key->data, env, key_len);
            
            struct moonbit_bytes* value = moonbit_make_bytes(val_len, 0);
            memcpy(value->data, equals + 1, val_len);

            result->data[i * 2] = key;
            result->data[i * 2 + 1] = value;
        }
        env += strlen(env) + 1;
        i++;
    }

    FreeEnvironmentStrings(env_block);
    return result;
#else
    // environ is a pointer to an array of environment variables
    extern char **environ;
    // Count the number of environment variables
    int count = 0;
    char **env = environ;
    while (*env != NULL) {
        count++;
        env++;
    }

    // Create an array to store environment variable key-value pairs
    // Array size is twice the number of variables since we need to store both key and value
    struct moonbit_ref_array* result = moonbit_make_ref_array(count * 2, NULL);
    env = environ;
    int i = 0;
    while (*env != NULL) {
        // Find the '=' character in the environment variable string
        char *equals = strchr(*env, '=');
        if (equals != NULL) {
            // Calculate lengths of key and value
            size_t key_len = equals - *env;
            size_t val_len = strlen(equals + 1);
            
            // Create bytes object for key and copy data
            struct moonbit_bytes* key = moonbit_make_bytes(key_len, 0);
            memcpy(key->data, *env, key_len);
            
            // Create bytes object for value and copy data
            struct moonbit_bytes* value = moonbit_make_bytes(val_len, 0);
            memcpy(value->data, equals + 1, val_len);

            // Store key and value in result array
            // Even indices store keys, odd indices store values
            result->data[i * 2] = key;
            result->data[i * 2 + 1] = value;
        }
        env++;
        i++;
    }
    return result;
#endif
}

void set_env_var(struct moonbit_bytes *key, struct moonbit_bytes *value) {
#ifdef _WIN32
    // SetEnvironmentVariable can't work as expected, so we use _putenv instead
    char *env_str = malloc(Moonbit_array_length(key) + Moonbit_array_length(value) + 2); // +2 for '=' and null terminator
    memcpy(env_str, key->data, Moonbit_array_length(key));
    env_str[Moonbit_array_length(key)] = '=';
    memcpy(env_str + Moonbit_array_length(key) + 1, value->data, Moonbit_array_length(value));
    env_str[Moonbit_array_length(key) + Moonbit_array_length(value) + 1] = '\0';
    _putenv(env_str);
    free(env_str);
#else
    setenv((const char*)key->data, (const char*)value->data, 1);
#endif
}

void unset_env_var(struct moonbit_bytes *key) {
#ifdef _WIN32
    size_t key_len = Moonbit_array_length(key);
    char *env_str = malloc(key_len + 2); // +2 for '=' and null terminator
    memcpy(env_str, key->data, key_len);
    env_str[key_len] = '=';
    env_str[key_len + 1] = '\0';
    _putenv(env_str);
    free(env_str);
#else
    unsetenv((const char*)key->data);
#endif
}
