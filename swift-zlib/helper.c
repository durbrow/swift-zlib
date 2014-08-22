//
//  helper.c
//  swift-zlib
//
//  Created by Ken on 8/22/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

#include "helper.h"

static unsigned in_cb(void *restrict const ctx, unsigned char **restrict dataptr)
{
    return ((backIn_block)ctx)((unsigned char const **restrict)dataptr);
}

static int out_cb(void *restrict const ctx, unsigned char *restrict data, unsigned datalen)
{
    return ((backOut_block)ctx)(datalen, data);
}

int inflateBackHelper(z_streamp const strm,
                      backIn_block const src,
                      backOut_block const sink)
{
    return inflateBack(strm, in_cb, (void *)src, out_cb, (void *)sink);
}
