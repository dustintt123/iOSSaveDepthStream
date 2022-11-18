/// Copyright (c) 2021 Razeware LLC
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
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import AVFoundation
import CoreImage

class FrameManager: NSObject, ObservableObject {
    static let shared = FrameManager()
    
    @Published var current: CVPixelBuffer?
    @Published var currentCIImage: CIImage?
    
    let videoOutputQueue = DispatchQueue(
        label: "com.raywenderlich.VideoOutputQ",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
//    let depthRecorder = DepthCapture()
    let dataRecorder = DataRecorder()
    
    private override init() {
        super.init()
        
        CameraManager.shared.set(self, queue: videoOutputQueue)
        dataRecorder.prepareForRecording()
    }
    
    func startRecording() {
        do {
            try dataRecorder.startRecording()
        } catch {
            
        }
    }
    
    func stopRecording() {
        do {
            try dataRecorder.finishRecording { fileURL in
                print(fileURL)
            }
        } catch {
            
        }
    }
}

extension FrameManager: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        guard let videoOutput = synchronizer.dataOutputs.first, let depthOutput = synchronizer.dataOutputs.last else { return }
        
        // Read all outputs, but only keep synced pairs
        guard
            let syncedDepthData: AVCaptureSynchronizedDepthData =
                synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
            let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
                synchronizedDataCollection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }
        
        var depthData = syncedDepthData.depthData
        
        // https://www.kodeco.com/8246240-image-depth-maps-tutorial-for-ios-getting-started#toc-anchor-002
        if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
          depthData = depthData.converting(
            toDepthDataType: kCVPixelFormatType_DisparityFloat32
          )
        }
        
        let pixelBuffer = depthData.applyingExifOrientation(.right).depthDataMap
        pixelBuffer.clamp()
        let depthMap = CIImage(cvPixelBuffer: pixelBuffer)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentCIImage = depthMap
        }
//        
//        let depthPixelBuffer = depthData.depthDataMap
        // 7
//        return depthData.applyingExifOrientation(orientation).depthDataMap
        
        
//        let sampleBuffer = syncedVideoData.sampleBuffer
//
//        if let buffer = sampleBuffer.imageBuffer {
//            DispatchQueue.main.async {
//                self.current = buffer
////                self.current = depthPixelBuffer
//            }
//        }
        
        
        //        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
        //            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
        //                return
        //        }
        
    }
    
}

//extension FrameManager: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(
//        _ output: AVCaptureOutput,
//        didOutput sampleBuffer: CMSampleBuffer,
//        from connection: AVCaptureConnection
//    ) {
//        if let buffer = sampleBuffer.imageBuffer {
//            DispatchQueue.main.async {
//                self.current = buffer
//            }
//        }
//    }
//}

