//
//  DataRecorder.swift
//  ASLDepthCapture
//
//  Created by Ting Yu on 11/17/22.
//

import AVFoundation
import Foundation
import Compression
import CoreImage


class DataRecorder {
//    private var videoOutputURL: URL?
    private var outputSize = CGSizeMake(1280, 720)
    
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var frameCount: Int64 = 0
    private var fps: Int32 = 1
    lazy private var frameDuration = CMTimeMake(value: 1, timescale: fps) //timescale is frame per second
    
    // All operations writing the video are done on the porcessingQ so they will happen sequentially
    var processingQ = DispatchQueue(label: "writingPixels",
                                    qos: .userInteractive)
    
    let kErrorDomain = "DepthCapture"
    let maxNumberOfFrame = 25
    lazy var bufferSize = 640 * 480 * 2 * maxNumberOfFrame  // maxNumberOfFrame frames
    var dstBuffer: UnsafeMutablePointer<UInt8>?
    
    var compresserPtr: UnsafeMutablePointer<compression_stream>?
    var file: FileHandle?
    
    
    
    init() {
        subscribeToVideoFeed()
    }
    
    func reset() {
        frameCount = 0
//        videoOutputURL = nil
        if self.compresserPtr != nil {
            //free(compresserPtr!.pointee.dst_ptr)
            compression_stream_destroy(self.compresserPtr!)
            self.compresserPtr = nil
        }
        if self.file != nil {
            self.file!.closeFile()
            self.file = nil
        }
    }
    
    func subscribeToVideoFeed() {
//        frameManager.$current
//            .receive(on: RunLoop.main)
//            .compactMap { buffer in
//                guard let image = CGImage.create(from: buffer) else {
//                    return nil
//                }
//
//                var ciImage = CIImage(cgImage: image)
//
//                writeImageToVideo(ciImage: ciImage)
//            }

    }
    
    func writeImageToVideo(ciImage: CIImage) -> Bool {
        guard let videoWriterInput = videoWriterInput, let pixelBufferAdaptor = pixelBufferAdaptor, let cgImage = ciImage.cgImage else { return false }
        
        var appendSucceeded = true
        videoWriterInput.requestMediaDataWhenReady(on: processingQ, using: { () -> Void in
            
            
            if (videoWriterInput.isReadyForMoreMediaData) {
//                    let nextPhoto = self.choosenPhotos.remove(at: 0)
                let lastFrameTime = CMTimeMake(value: self.frameCount, timescale: self.fps)
                let presentationTime = self.frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, self.frameDuration)
                
                var pixelBuffer: CVPixelBuffer? = nil
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                
                if let pixelBuffer = pixelBuffer, status == 0 {
                    let managedPixelBuffer = pixelBuffer
                    
                    CVPixelBufferLockBaseAddress(managedPixelBuffer, [])
                    
                    let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                    let context = CGContext(data: data, width: Int(self.outputSize.width), height: Int(self.outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                    
                    context?.clear(CGRect(x: 0, y: 0, width: self.outputSize.width, height: self.outputSize.height))
                    let horizontalRatio = CGFloat(self.outputSize.width) / ciImage.extent.size.width
                    let verticalRatio = CGFloat(self.outputSize.height) / ciImage.extent.size.height
                    //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
                    let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
                    
                    let newSize:CGSize = CGSizeMake(ciImage.extent.size.width * aspectRatio, ciImage.extent.size.height * aspectRatio)
                    
                    let x = newSize.width < self.outputSize.width ? (self.outputSize.width - newSize.width) / 2 : 0
                    let y = newSize.height < self.outputSize.height ? (self.outputSize.height - newSize.height) / 2 : 0
                                        
                    context?.draw(cgImage, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
                    
                    CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])
                    
                    appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                } else {
                    print("Failed to allocate pixel buffer")
                    appendSucceeded = false
                }
            }
            self.frameCount += 1
        })
        return appendSucceeded
    }
    
    func fileOutputPath() -> URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentDirectory: URL = urls.first else {
            fatalError("documentDir Error")
        }
        
        let videoOutputURL = documentDirectory.appendingPathComponent("OutputVideo.mp4")
        
        if fileManager.fileExists(atPath: videoOutputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: videoOutputURL.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        }
        
        return videoOutputURL
    }
    
    func prepareForRecording() {
        reset()
        
        let videoOutputURL = fileOutputPath()
        
        if let videoWriter = try? AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mp4) {
            self.videoWriter = videoWriter
        } else {
            fatalError("AVAssetWriter error")
        }
        
        guard let videoWriter = self.videoWriter else {
            fatalError("Video writer not found")
        }
        
        let outputSettings = [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : NSNumber(value: Float(outputSize.width)), AVVideoHeightKey : NSNumber(value: Float(outputSize.height))] as [String : Any]
        
        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) == true else {
            fatalError("Negative : Can't apply the Output settings...")
        }
        
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let videoWriterInput = videoWriterInput!
        let sourcePixelBufferAttributesDictionary = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB), kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSize.width)), kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSize.height))]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        let pixelBufferAdaptor = pixelBufferAdaptor!
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        if videoWriter.startWriting() {
            videoWriter.startSession(atSourceTime: CMTime.zero)
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
        } else {
            
        }
    }
    
    func startRecording() throws {
        processingQ.async {
            self.prepareForRecording()
        }
    }
    
    func finishRecording(success: @escaping ((URL?) -> Void)) throws {
        processingQ.async { [self] in
            videoWriterInput?.markAsFinished()
            videoWriter?.finishWriting { () -> Void in
                print("FINISHED!!!!!")
            }
            
            DispatchQueue.main.sync {
//                success(self.videoOutputURL)
            }
            self.reset()
        }
    }
    
//    func addPixelBuffers(pixelBuffer: CVPixelBuffer) {
//        if videoWriter.startWriting() {
//            videoWriter.startSession(atSourceTime: CMTime.zero)
//            assert(pixelBufferAdaptor.pixelBufferPool != nil)
//
//            let media_queue = DispatchQueue(__label: "mediaInputQueue", attr: nil)
//
//            videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
//                let fps: Int32 = 1
//                let frameDuration = CMTimeMake(value: 1, timescale: fps)
//
//                var frameCount: Int64 = 0
//                var appendSucceeded = true
//
//                while (!self.choosenPhotos.isEmpty) {
//                    if (videoWriterInput.isReadyForMoreMediaData) {
//                        let nextPhoto = self.choosenPhotos.remove(at: 0)
//                        let lastFrameTime = CMTimeMake(value: frameCount, timescale: fps)
//                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
//
//                        var pixelBuffer: CVPixelBuffer? = nil
//                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
//
//                        if let pixelBuffer = pixelBuffer, status == 0 {
//                            let managedPixelBuffer = pixelBuffer
//
//                            CVPixelBufferLockBaseAddress(managedPixelBuffer, [])
//
//                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
//                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
//                            let context = CGContext(data: data, width: Int(self.outputSize.width), height: Int(self.outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
//
//                            context?.clear(CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))
//
//                            let horizontalRatio = CGFloat(self.outputSize.width) / nextPhoto.size.width
//                            let verticalRatio = CGFloat(self.outputSize.height) / nextPhoto.size.height
//                            //aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
//                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
//
//                            let newSize:CGSize = CGSizeMake(nextPhoto.size.width * aspectRatio, nextPhoto.size.height * aspectRatio)
//
//                            let x = newSize.width < self.outputSize.width ? (self.outputSize.width - newSize.width) / 2 : 0
//                            let y = newSize.height < self.outputSize.height ? (self.outputSize.height - newSize.height) / 2 : 0
//
//                            context?.draw(nextPhoto.cgImage!, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
//
//                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, [])
//
//                            appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
//                        } else {
//                            print("Failed to allocate pixel buffer")
//                            appendSucceeded = false
//                        }
//                    }
//                    if !appendSucceeded {
//                        break
//                    }
//                    frameCount += 1
//                }
//
//                videoWriterInput.markAsFinished()
//                videoWriter.finishWriting { () -> Void in
//                    print("FINISHED!!!!!")
//                }
//            })
//    }
//
//    func compressPixelBuffers(pixelBuffer: CVPixelBuffer) {
//        processingQ.async {
//            if self.frameCount >= self.maxNumberOfFrame {
//                // TODO now!! flush when needed!!!
//                print("MAXED OUT")
//                return
//            }
//
//            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
//            let add: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(pixelBuffer)!
//
//            guard let compressor = self.compresserPtr else { return }
//
//            compressor.pointee.src_ptr = UnsafePointer<UInt8>(add.assumingMemoryBound(to: UInt8.self))
//            let height = CVPixelBufferGetHeight(pixelBuffer)
//            compressor.pointee.src_size = CVPixelBufferGetBytesPerRow(pixelBuffer) * height
//            let flags = Int32(0)
//            let compression_status = compression_stream_process(compressor, flags)
//            if compression_status != COMPRESSION_STATUS_OK {
//                NSLog("Buffer compression retured: \(compression_status)")
//                return
//            }
//            if compressor.pointee.src_size != 0 {
//                NSLog("Compression lib didn't eat all data: \(compression_status)")
//                return
//            }
//            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
//            // TODO(eyal): flush when needed!!!
//            self.frameCount += 1
//            print("handled \(self.frameCount) buffers")
//        }
//    }
//
//

}
