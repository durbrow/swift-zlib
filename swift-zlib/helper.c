//
//  helper.c
//  swift-zlib
//
//  Created by Ken on 8/22/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

#include "helper.h"

// this one is called to provide data to be decompressed
// ctx here is the pointer that was passed in as the 3rd parameter to inflateBack
static unsigned in_cb(void *const ctx1, unsigned char **const dataptr)
{
    backIn_block const src = ctx1;

    return src((void *)dataptr);
}

// this one is called with decompressed data
// ctx here is the pointer that was passed in as the 5th parameter to inflateBack
static int out_cb(void *const ctx2, unsigned char *const data, unsigned const datalen)
{
    backOut_block const sink = ctx2;

    return sink(datalen, data);
}

int inflateBackHelper(z_streamp const strm,
                      backIn_block const src,
                      backOut_block const sink)
{
    void *const ctx1 = src;
    void *const ctx2 = sink;

    return inflateBack(strm, in_cb, ctx1, out_cb, ctx2);
}
