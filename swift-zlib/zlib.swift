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
                   From source: () -> UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        stream[0].total_in = 0
        let rc = inflateBackHelper(stream,
            { let data = source(); $0[0] = data.baseAddress; return UInt32(data.count) },
            { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
        )
        return (Int(rc), Int(stream[0].total_in))
    }
    
    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:  UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        stream[0].total_in = 0
        let rc = inflateBackHelper(stream,
            { $0[0] = source.baseAddress; return UInt32(source.count) },
            { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
        )
        return (Int(rc), Int(stream[0].total_in))
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
                   From source: () -> UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        return raw.inflateTo(sink, From: source);
    }

    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:  UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        return raw.inflateTo(sink, From: source);
    }

    func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:                     [UInt8]) -> (Int, Int)
    {
        return source.withUnsafeBufferPointer { self.inflateTo(sink, From: $0) }
    }

    func inflate(source: [UInt8]) -> ([UInt8], Int, Int)
    {
        var rslt = Array<UInt8>();
        let rc = inflateTo({ rslt.extend($0); return 0 }, From: source);

        return (rslt, rc.0, rc.1);
    }
}

class InflateZlib
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
                   From source: () -> UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        // check zlib header
        // see http://tools.ietf.org/html/rfc1950#page-4
        let first  = source()
        if first.count < 2 { return (0, 0) }

        if (Int(first[0]) * 256 + Int(first[1])) % 31 != 0 { return (Int(Z_DATA_ERROR), 0) }

        let CM     = first[0] & 0x0F
        if CM != UInt8(Z_DEFLATED) { return (Int(Z_DATA_ERROR), 0) }

        let CINFO  = first[0] >> 4
        if CINFO > 7 { return (Int(Z_DATA_ERROR), 0) }

        let FDICT  = first[1] & 0x20;
        if FDICT != 0  { return (Int(Z_NEED_DICT), 0) }

        return (0, 0) //raw.inflateTo(sink, From: source);
    }
}
