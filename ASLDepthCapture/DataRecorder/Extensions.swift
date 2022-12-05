//
//  Extensions.swift
//  ASLDepthCapture
//
//  Created by Ting Yu on 11/29/22.
//

import CoreVideo
import Foundation

extension CVPixelBuffer {

    var pointer: UnsafeMutablePointer<Float16> {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        return unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float16>.self)
    }
    
    var data: Data {
        return Data(bytes: self.pointer, count: self.size * 2)
    }
    
    func getRawDepthAt(x: Int, y: Int) -> Float16 {
        return pointer[y * self.width + x]
    }
    
    func getRawDepths(removeNaN: Bool = true) -> [[NSNumber]] {
        let ptr = self.pointer
        let width = self.width
        var matrix = [[NSNumber]]()
        for y in 0..<self.width {
            var row = [NSNumber]()
            for x in 0..<self.height {
                var value = ptr[y * width + x]
                if value.isNaN || value.isSignalingNaN {
                    value = Float16(-1)
                }
                row.append(NSNumber(floatLiteral: Double(value)))
            }
            matrix.append(row)
        }
        return matrix
    }
//
//    func getRawDepths(removeNaN: Bool = true) -> [[Float16]] {
//        let ptr = self.pointer
//        let width = self.width
//        var matrix = [[Float16]]()
//        for y in 0..<self.width {
//            var row = [Float16]()
//            for x in 0..<self.height {
//                var value = ptr[y * width + x]
//                if value.isNaN || value.isSignalingNaN {
//                    value = Float16(-1)
//                }
//                row.append(value)
//            }
//            matrix.append(row)
//        }
//        return matrix
//    }
    
    var width: Int {
        CVPixelBufferGetWidth(self)
    }

    var height: Int {
        CVPixelBufferGetHeight(self)
    }
    
    var size: Int {
        return self.width * self.height
    }
    
}


/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
//
//import CoreVideo
//import UIKit
//
//extension CVPixelBuffer {
//  func clamp() {
//    let width = CVPixelBufferGetWidth(self)
//    let height = CVPixelBufferGetHeight(self)
//
//    CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
//    let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)
//
//    /// You might be wondering why the for loops below use `stride(from:to:step:)`
//    /// instead of a simple `Range` such as `0 ..< height`?
//    /// The answer is because in Swift 5.1, the iteration of ranges performs badly when the
//    /// compiler optimisation level (`SWIFT_OPTIMIZATION_LEVEL`) is set to `-Onone`,
//    /// which is eactly what happens when running this sample project in Debug mode.
//    /// If this was a production app then it might not be worth worrying about but it is still
//    /// worth being aware of.
//
//    for y in stride(from: 0, to: height, by: 1) {
//      for x in stride(from: 0, to: width, by: 1) {
//        let pixel = floatBuffer[y * width + x]
//        floatBuffer[y * width + x] = min(1.0, max(pixel, 0.0))
//      }
//    }
//
//    CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
//  }

// Requires CVPixelBufferLockBaseAddress(_:_:) first
//    var rawPointer: UnsafeRawBufferPointer? {
//        let size = CVPixelBufferGetDataSize(self)
//        CVPixelBufferLockBaseAddress(self, .readOnly)
//        let ptr: UnsafeRawBufferPointer? = .init(start: CVPixelBufferGetBaseAddress(self), count: size)
//        CVPixelBufferUnlockBaseAddress(self, .readOnly)
//        return ptr
//    }
//
//    var safePointer: UnsafeBufferPointer<UInt8>? {
//        let ptr = self.rawPointer?.assumingMemoryBound(to: UInt8.self)
//        return ptr
//    }
 

//    var intValue: UInt8? {
//        return self.safePointer?[0]
//    }
//
//    var pixelSize: simd_int2 {
//        simd_int2(Int32(width), Int32(height))
//    }



//    func sample(location: simd_float2) -> simd_float4? {
//        let pixelSize = self.pixelSize
//        guard pixelSize.x > 0 && pixelSize.y > 0 else { return nil }
//        guard CVPixelBufferLockBaseAddress(self, .readOnly) == noErr else { return nil }
//        guard let data = rawPointer else { return nil }
//        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
//        let pix = location * simd_float2(pixelSize)
//        let clamped = simd.clamp(simd_int2(pix), min: .zero, max: pixelSize &- simd_int2(1,1))
//
//        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
//        let row = Int(clamped.y)
//        let column = Int(clamped.x)
//
//        let rowPtr = data.baseAddress! + row * bytesPerRow
//        switch CVPixelBufferGetPixelFormatType(self) {
//        case kCVPixelFormatType_DepthFloat32:
//            // Bind the row to the right type
//            let typed = rowPtr.assumingMemoryBound(to: Float.self)
//            return .init(typed[column], 0, 0, 0)
//        case kCVPixelFormatType_32BGRA:
//            // Bind the row to the right type
//            let typed = rowPtr.assumingMemoryBound(to: UInt8.self)
//            return .init(Float(typed[column]) / Float(UInt8.max), 0, 0, 0)
//        default:
//            return nil
//        }
//    }

//}
//
//import Metal
//import simd
