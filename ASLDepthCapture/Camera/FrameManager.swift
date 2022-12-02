//
//  FrameManager.swift
//  ASLDepthCapture
//
//  Created by Ting Yu.
//

import AVFoundation
import CoreImage

struct RGBDDataWrapper {
    var currentDepthPixelBuffer: CVPixelBuffer?
    var currentVideoPixelBuffer: CVPixelBuffer?
}

class FrameManager: NSObject, ObservableObject {
    static let shared = FrameManager()
    
    @Published var currentDataWrapper: RGBDDataWrapper?
    @Published var currentDepthCIImage: CIImage?
    @Published var currentVideoCIImage: CIImage?
    
    let videoOutputQueue = DispatchQueue(
        label: "com.raywenderlich.VideoOutputQ",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)
    
    //    let depthRecorder = DepthCapture()
    
    private override init() {
        super.init()
        
        CameraManager.shared.set(self, queue: videoOutputQueue)
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
        
        guard let videoSampleBuffer = syncedVideoData.sampleBuffer.imageBuffer else { return }
        var depthData = syncedDepthData.depthData
        
        if depthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
            depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        }
        
        let depthPixelBuffer = depthData.applyingExifOrientation(.right).depthDataMap
        
        print("Raw: \(depthPixelBuffer.depthAt(x: 150, y: 150))")
        print("depth W: \(CVPixelBufferGetWidth(depthPixelBuffer))")
        print("depth H: \(CVPixelBufferGetHeight(depthPixelBuffer))")
        print("video W: \(CVPixelBufferGetWidth(videoSampleBuffer))")
        print("video H: \(CVPixelBufferGetHeight(videoSampleBuffer))")
        
        DispatchQueue.main.async { [weak self] in
            self?.currentDataWrapper = RGBDDataWrapper(currentDepthPixelBuffer: depthPixelBuffer, currentVideoPixelBuffer: videoSampleBuffer)
            
        }
        
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

