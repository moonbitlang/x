#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include "moonbit.h"

int path_exists(struct moonbit_bytes *path) {
    struct stat buffer;
    int status = stat((const char *)(path->data), &buffer);
    if (status == 0) {
        return 0;
    }
    return -1;
}

struct moonbit_bytes* read_file_to_bytes(struct moonbit_bytes *filename) {
    FILE *file = fopen((const char*)(filename->data), "rb");
    if (file == NULL) {
        perror("fopen");
        return NULL;
    }

    // move file pointer to the end of the file
    if (fseek(file, 0, SEEK_END) != 0) {
        perror("fseek");
        fclose(file);
        return NULL;
    }

    // get the current position of the file pointer, which is the file size
    long size = ftell(file);
    if (size == -1L) {
        perror("ftell");
        fclose(file);
        return NULL;
    }

    if (fseek(file, 0, SEEK_SET) != 0) {
        perror("fseek");
        fclose(file);
        return NULL;
    }


    // allocate memory to store the file content
    char *buffer = (char *)malloc((size_t)size);
    if (buffer == NULL) {
        perror("malloc");
        fclose((FILE *)(filename->data));
        return NULL;
    }

    // read the file content into the buffer
    size_t bytes_read = fread(buffer, 1, (size_t)size, file);
    if (bytes_read != (size_t)size) {
        perror("fread");
        free(buffer);
        fclose((FILE *)(filename->data));
        return NULL;
    }

    // close the file
    if (fclose(file) != 0) {
        perror("fclose");
        free(buffer);
        return NULL;
    }

    struct moonbit_bytes* bytes = moonbit_make_bytes(size, 0);
    memcpy(bytes->data, buffer, size);

    return bytes;
}

struct moonbit_ref_array* read_dir(struct moonbit_bytes* path) {

    DIR *dir;
    struct dirent *entry;
    struct moonbit_ref_array *result = NULL;
    int count = 0;

    // open the directory
    dir = opendir((const char *)path->data);
    if (dir == NULL) {
        perror("opendir");
        return NULL;
    }

    // first traversal of the directory, calculate the number of items
    while ((entry = readdir(dir)) != NULL) {
        // ignore hidden files and current/parent directories
        if (entry->d_name[0] != '.') {
            count++;
        }
    }

    // reset the directory stream
    rewinddir(dir);

    // create moonbit_ref_array to store the result
    result = moonbit_make_ref_array(count, NULL);
    if (result == NULL) {
        closedir(dir);
        return NULL;
    }

    // second traversal of the directory, fill the array
    int index = 0;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_name[0] != '.') {
            size_t name_len = strlen(entry->d_name);
            struct moonbit_bytes *item = moonbit_make_bytes(name_len, 0);
            memcpy(item->data, entry->d_name, name_len);
            result->data[index++] = (struct moonbit_object *)item;
        }
    }

    closedir(dir);
    return result;
}

int is_dir(struct moonbit_bytes* path) {
    struct stat buffer;
    int status = stat((const char *)(path->data), &buffer);
    if (status == 0 && S_ISDIR(buffer.st_mode)) {
        return 0;
    }
    return -1;
}

int is_file(struct moonbit_bytes* path) {
    struct stat buffer;
    int status = stat((const char *)(path->data), &buffer);
    if (status == 0 && S_ISREG(buffer.st_mode)) {
        return 0;
    }
    return -1;
}

void remove_dir(struct moonbit_bytes* path) {
    rmdir((const char *)(path->data));
}

void create_dir(struct moonbit_bytes* path) {
    mkdir((const char *)(path->data), 0777);
}

void remove_file(struct moonbit_bytes* path) {
    remove((const char *)(path->data));
}

void write_bytes_to_file(struct moonbit_bytes* path, struct moonbit_bytes* content) {
    FILE *file = fopen((const char *)(path->data), "wb");
    size_t content_size = strlen((const char *)(content->data));
    fwrite(content->data, 1, content_size, file);
    fclose(file);
}

