//
//  zlib.swift
//  swift-zlib
//
//  Created by Ken on 8/14/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

import Swift

private let MAX_WBYTES = Int(1 << MAX_WBITS)

//// TODO: enum for inflate error codes

// callback based inflate
private struct InflateBack
{
    // this is for inflate's lookback window, it is 32K
    let window: UnsafeMutablePointer<UInt8>

    // inflate's state object
    let stream: UnsafeMutablePointer<z_stream>

    init()
    {
        window = UnsafeMutablePointer<UInt8>.alloc(MAX_WBYTES)
        stream = UnsafeMutablePointer<z_stream>.alloc(1)
        inflateBackInitialize(stream, MAX_WBITS, window);
    }

    func dealloc() -> ()
    {
        inflateBackEnd(stream)
        stream.dealloc(1)
        window.dealloc(MAX_WBYTES)
    }

    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source: () -> UnsafeBufferPointer<UInt8>) -> Int
    {
        return Int(inflateBackHelper(stream,
            { let data = source(); $0[0] = data.baseAddress; return UInt32(data.count) },
            { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
        ))
    }
    
    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:  UnsafeBufferPointer<UInt8>) -> Int
    {
        return Int(
            inflateBackHelper(stream,
                { $0[0] = source.baseAddress; return UInt32(source.count) },
                { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
            ))
    }
}

class InflateRaw
{
    private let raw: InflateBack

    init()
    {
        self.raw = InflateBack()
    }

    deinit
    {
        raw.dealloc()
    }

    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source: () -> UnsafeBufferPointer<UInt8>) -> Int
    {
        return raw.inflateTo(sink, From: source);
    }

    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:  UnsafeBufferPointer<UInt8>) -> Int
    {
        return raw.inflateTo(sink, From: source);
    }

    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:                     [UInt8]) -> Int
    {
        return source.withUnsafeBufferPointer { self.inflateTo(sink, From: $0) }
    }

    func inflate(source: [UInt8]) -> ([UInt8], Int)
    {
        var rslt = Array<UInt8>();
        let rc = inflateTo({ rslt.extend($0); return 0 }, From: source);

        return (rslt, rc);
    }
}