//
//  helper.h
//  swift-zlib
//
//  Created by Ken on 8/22/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

#include <stdint.h>
#include <zlib.h>

// bridging callback blocks
typedef unsigned (^backIn_block)(unsigned char const **restrict dataptr);
typedef int (^backOut_block)(unsigned length, unsigned char *restrict data);
int inflateBackHelper(z_streamp strm, backIn_block src, backOut_block sink);
