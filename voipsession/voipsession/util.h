//
//  util.h
//  im
//
//  Created by houxh on 14-6-27.
//  Copyright (c) 2014年 potato. All rights reserved.
//

#ifndef IM_UTIL_H
#define IM_UTIL_H

#ifdef __cplusplus
extern "C" {
#endif
void writeInt32(int32_t v, void *p);
int32_t readInt32(const void *p);

void writeInt64(int64_t v, void *p);
int64_t readInt64(const void *p);

void writeInt16(int16_t v, void *p);
int16_t readInt16(const void *p);

int lookupAddr(const char *host, int port, struct sockaddr_in *addr);


int sock_nonblock(int fd, int set);
int write_data(int fd, uint8_t *bytes, int len);
#ifdef __cplusplus
}
#endif

#endif
