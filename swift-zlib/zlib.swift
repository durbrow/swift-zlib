//
//  zlib.swift
//  swift-zlib
//
//  Created by Ken on 8/14/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

import Swift

private struct zlib
{
    static let MAX_WBYTES = Int(1 << MAX_WBITS)
}

private struct InflateBack
{
    let window: UnsafeMutablePointer<UInt8>
    let stream: UnsafeMutablePointer<z_stream>

    init()
    {
        window = UnsafeMutablePointer<UInt8>.alloc(zlib.MAX_WBYTES)
        stream = UnsafeMutablePointer<z_stream>.alloc(1)

        inflateBackInit_(stream, MAX_WBITS, window, ZLIB_VERSION, Int32(sizeof(z_stream)))
    }
    func destroy()
    {
        inflateBackEnd(stream);
        stream.dealloc(1)
        window.dealloc(zlib.MAX_WBYTES)
    }
    func inflate(source: () -> UnsafeBufferPointer<UInt8>,
                   sink: (UnsafeBufferPointer<UInt8>) -> Int32) -> Int
    {
        return Int(inflateBackHelper(stream,
            {
                let data = source();
                $0[0] = data.baseAddress;
                return UInt32(data.count);
            },
            {
                sink(UnsafeBufferPointer(start: $1, count: Int($0)))
            }
        ))
    }
    func inflate(source: UnsafeBufferPointer<UInt8>,
                   sink: (UnsafeBufferPointer<UInt8>) -> Int32) -> Int
    {
        return Int(
            inflateBackHelper(stream,
                { $0[0] = source.baseAddress; return UInt32(source.count) },
                { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
            ))
    }
}
