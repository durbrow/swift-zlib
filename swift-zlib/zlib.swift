//
//  zlib.swift
//  swift-zlib
//
//  Created by Ken on 8/14/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

import Swift
import Foundation

private let MAX_WBYTES = Int(1 << MAX_WBITS)

//// TODO: enum for inflate error codes

private struct ZStream : DebugPrintable
{
    var stream: z_stream

    init()
    {
        stream = z_stream(next_in: nil, avail_in: 0, total_in: 0, next_out: nil, avail_out: 0, total_out: 0, msg: nil, state: nil, zalloc: nil, zfree: nil, opaque: nil, data_type: 0, adler: 0, reserved: 0);
    }
    var debugDescription: String
    {
        let msg = stream.msg != nil ? String.fromCString(stream.msg) : "";
        return "avail_in: \(stream.avail_in); avail_out: \(stream.avail_out); total_in: \(stream.total_in); total_out: \(stream.total_out); data_type: \(stream.data_type); checksum: \(stream.adler); msg: '\(msg)'"
    }
    mutating func InflateInit(wbits: Int32) -> Int32
    {
        return inflateInit2_(&stream, wbits, ZLIB_VERSION, Int32(sizeof(z_stream)))
    }
    mutating func Inflate(flush: Int32) -> Int32
    {
        return inflate(&stream, flush)
    }
    mutating func getHeader(head: gz_headerp) -> Int32
    {
        return inflateGetHeader(&stream, head)
    }
    mutating func InflateEnd() -> Int32
    {
        return inflateEnd(&stream)
    }
    mutating func InflateReset() -> Int32
    {
        return inflateReset(&stream)
    }
    var totalIn: Int {
        get {
            return Int(stream.total_in)
        }
        set (y) {
            stream.total_in = uLong(y)
        }
    }
    var totalOut: Int {
        get {
            return Int(stream.total_out)
        }
        set (y) {
            stream.total_out = uLong(y)
        }
    }
    var hasInput: Bool {
        return stream.avail_in != 0
    }
    var input: UnsafeBufferPointer<UInt8> {
        get {
            return UnsafeBufferPointer(start: UnsafePointer<UInt8>(stream.next_in), count: Int(stream.avail_in))
        }
        set(newValue) {
            stream.next_in = UnsafeMutablePointer<Bytef>(newValue.baseAddress)
            stream.avail_in = uInt(newValue.count)
        }
    }
    var availOut: Int { return Int(stream.avail_out) }
    mutating func setOutput(buffer: UnsafeMutablePointer<UInt8>, size: Int)
    {
        stream.next_out = UnsafeMutablePointer<Bytef>(buffer)
        stream.avail_out = uInt(size)
    }
    mutating func noOutput()
    {
        let bogus = UnsafePointer<Void>(bitPattern: 0xDEADBEEF)
        setOutput(UnsafeMutablePointer<UInt8>(bogus), size: 0)
    }
    mutating func noInput()
    {
        stream.next_in = UnsafeMutablePointer<Bytef>(nil)
        stream.avail_in = 0
    }
}

// callback based inflate
private struct InflateBack
{
    // this is for inflate's lookback window, it is 32K
    let window: UnsafeMutablePointer<UInt8>

    // inflate's state object
    var stream = z_stream(next_in: nil, avail_in: 0, total_in: 0, next_out: nil, avail_out: 0, total_out: 0, msg: nil, state: nil, zalloc: nil, zfree: nil, opaque: nil, data_type: 0, adler: 0, reserved: 0)

    init()
    {
        window = UnsafeMutablePointer<UInt8>.alloc(MAX_WBYTES)
        inflateBackInitialize(&stream, MAX_WBITS, window);
    }

    mutating func dealloc() -> ()
    {
        inflateBackEnd(&stream)
        window.dealloc(MAX_WBYTES)
    }

    mutating func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source: () -> UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        stream.total_in = 0
        let rc = inflateBackHelper(&stream,
            { let data = source(); $0[0] = data.baseAddress; return UInt32(data.count) },
            { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
        )
        return (Int(rc), Int(stream.total_in))
    }
    
    mutating func inflateTo(       sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   From source:  UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        stream.total_in = 0
        let rc = inflateBackHelper(&stream,
            { $0[0] = source.baseAddress; return UInt32(source.count) },
            { sink(UnsafeBufferPointer(start: $1, count: Int($0))) }
        )
        return (Int(rc), Int(stream.total_in))
    }
}

class InflateRaw
{
    private var raw: InflateBack

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

struct GZipHeader {
    struct Extra {
        let SI: (CChar, CChar)
        let data: UnsafeBufferPointer<UInt8>
    }
    let mtime: NSDate?
    let name: String?
    let comment: String?
    let extra: [Extra]

    init(_ header: gz_header) {
        if header.time != 0 {
            mtime = NSDate(timeIntervalSince1970: NSTimeInterval(header.time))
        }
        if header.name != nil {
            name = String.fromCString(UnsafePointer<CChar>(header.name))
        }
        if header.comment != nil {
            comment = String.fromCString(UnsafePointer<CChar>(header.comment))
        }
        let N = Int(header.extra_len)
        var X = [Extra]()
        for var i = 4; i < N; () {
            let LEN = Int(header.extra[i - 2]) + 256 * Int(header.extra[i - 1])
            if i + LEN <= N {
                let subField = Extra(
                    SI: (CChar(header.extra[i - 4]), CChar(header.extra[i - 3])),
                    data: UnsafeBufferPointer(start: header.extra.advancedBy(i), count: LEN)
                )
                X.append(subField)
            }
            i += 4 + LEN
        }
        extra = X
    }
}

class Inflate
{
    enum Header {
        case None
        case zlib
        case gzip(GZipHeader)

        static func make(header: gz_header) -> Header
        {
            if header.done ==  1 { return .gzip(GZipHeader(header)) }
            if header.done == -1 { return .zlib }
            return .None
        }
    }
    private let scratch = UnsafeMutablePointer<Bytef>.alloc(3 * 64 * 1024)
    private var stream = ZStream()

    init()
    {
        stream.InflateInit(MAX_WBITS + 32)
    }
    deinit
    {
        stream.InflateEnd()
        scratch.dealloc(3 * 64 * 1024)
    }

    func inflateTo(           sink: (UnsafeBufferPointer<UInt8>) -> Int32,
                   Header delegate: (Header) -> Int32,
                       From source: () -> UnsafeBufferPointer<UInt8>) -> (Int, Int)
    {
        func put() -> Int32
        {
            let bytes = 64*1024 - stream.availOut
            let data = UnsafePointer<UInt8>(scratch)
            return sink(UnsafeBufferPointer<UInt8>(start: data, count: bytes))
        }
        let extra   = UnsafeMutableBufferPointer<Bytef>(start: scratch.advancedBy(0*64*1024), count: 64*1024)
        let name    = UnsafeMutableBufferPointer<Bytef>(start: scratch.advancedBy(1*64*1024), count: 64*1024)
        let comment = UnsafeMutableBufferPointer<Bytef>(start: scratch.advancedBy(2*64*1024), count: 64*1024)

        stream.noInput()
        for ( ; ; ()) {
            var hdr = gz_header(
                text: 0,
                time: 0,
                xflags: 0,
                os: 0,
                extra: extra.baseAddress, extra_len: 0, extra_max: uInt(extra.count),
                name: name.baseAddress, name_max: uInt(name.count - 1),
                comment: comment.baseAddress, comm_max: uInt(comment.count - 1),
                hcrc: 0, done: 0)
            var noHeader = true;

            stream.InflateReset()
            stream.getHeader(&hdr)
            stream.noOutput()

            for ( ; ; ()) {
                if !stream.hasInput {
                    let input = source()
                    let bytes = uInt(input.count)
                    if bytes == 0 { return (Int(Z_OK), Int(stream.totalIn)) }

                    stream.input = input
                }
                let zrc = stream.Inflate(Z_FINISH)
                switch zrc {
                case Z_OK:
                    /* need more input */
                    continue
                case Z_BUF_ERROR:
                    if !stream.hasInput {
                        continue
                    }
                    if noHeader {
                        name[name.count - 1] = 0
                        comment[comment.count - 1] = 0
                        let rc = delegate(Header.make(hdr))
                        if rc != 0 { return (Int(rc), Int(stream.totalIn)) }
                        noHeader = false
                    }
                    else {
                        let rc = put()
                        if rc != 0 { return (Int(rc), Int(stream.totalIn)) }
                    }
                    stream.setOutput(scratch, size: 64 * 1024)
                case Z_STREAM_END:
                    return (Int(put()), Int(stream.totalIn))
                default:
                    println(stream)
                    return (Int(zrc), Int(stream.totalIn))
                }
            }
        }
    }
}
