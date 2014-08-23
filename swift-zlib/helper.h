//
//  helper.h
//  swift-zlib
//
//  Created by Ken on 8/22/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

#include <stdint.h>
#include <zlib.h>

// inflateBack uses callbacks (c function pointers). While swift can import
// c function pointers it can't generate them. It can generate clang blocks
// though. So this helper provides a pair of callbacks that call the blocks.

// this one provides compressed data
typedef unsigned (^backIn_block)(unsigned char const **dataptr);

// this one receives decompressed data
typedef int (^backOut_block)(unsigned length, unsigned char const data[length]);

int inflateBackHelper(z_streamp strm, backIn_block src, backOut_block sink);
