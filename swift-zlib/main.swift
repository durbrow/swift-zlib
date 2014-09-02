//
//  main.swift
//  swift-zlib
//
//  Created by Ken on 8/22/14.
//  Copyright (c) 2014 Kenneth Durbrow. All rights reserved.
//

import Foundation

let path = "~/tmp/test.bam".stringByExpandingTildeInPath
let file = NSData(contentsOfMappedFile: path)
let data = UnsafePointer<UInt8>(file.bytes)
let size = file.length
let inflater = Inflate()
var cur = 0
var totalSize = 0

do {
    let rc = inflater.inflateTo(
        {
            totalSize += $0.count
            return 0
        },
        Header:
        {
            return 0
            switch $0 {
            case let .gzip(gzh):
                println(gzh)
            default:
                ()
            }
            return 0
        },
        From: {
            let max = size - cur
            let bsize = max > 1024*1024 ? 1024*1024 : max;
            let block = UnsafeBufferPointer(start: data.advancedBy(cur), count: bsize);
            return block
        })
    if rc.0 != 0 {
        println("rc: \(rc)")
        break
    }
    cur += rc.1
} while cur < size
var ratio = Float(size) / Float(totalSize)
println("file size: \(size); decompressed size: \(totalSize); ratio: \(ratio)")
