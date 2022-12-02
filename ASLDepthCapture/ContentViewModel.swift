//
//  ContentViewModel.swift
//  ASLDepthCapture
//
//  Created by Ting Yu.
//

import CoreImage

class ContentViewModel: ObservableObject {
    @Published var error: Error?
    @Published var frame: CGImage?
    
    var isRecoding = false {
        didSet {
            if isRecoding {
                RecordSession.current.newSession()
                DataRecorder.sharedRgbRecorder.startRecording()
                DataRecorder.sharedDepthRecorder.startRecording()
                DataRecorder.sharedRawDepthRecorder.startRecording()
            } else {
                DataRecorder.sharedRgbRecorder.finishRecording { url in
//                    print(url)
                }
                DataRecorder.sharedDepthRecorder.finishRecording(success: { url in
                    
                })
                DataRecorder.sharedRawDepthRecorder.finishRecording { url in
                    
                }
                RecordSession.current.endSession()
            }
        }
    }
        
    private let context = CIContext()
    
    init() {
        setupSubscriptions()
    }
    
    func setupSubscriptions() {
        // swiftlint:disable:next array_init
        CameraManager.shared.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        FrameManager.shared.$currentDataWrapper
            .receive(on: RunLoop.main)
            .compactMap { dataWrapper in
                
                guard let depthPixelBuffer = dataWrapper?.currentDepthPixelBuffer else { return nil }
                guard let videoPixelBuffer = dataWrapper?.currentVideoPixelBuffer else { return nil }
                
                let depthCIImage = CIImage(cvPixelBuffer: depthPixelBuffer)
                let videoCIImage = CIImage(cvImageBuffer: videoPixelBuffer)
                guard let depthCGImage = self.context.createCGImage(depthCIImage, from: depthCIImage.extent) else { return nil }
                guard let videoCGImage = self.context.createCGImage(videoCIImage, from: videoCIImage.extent) else { return nil }
                
                if DataRecorder.sharedRgbRecorder.isReadyForWriting, DataRecorder.sharedDepthRecorder.isReadyForWriting {
                    let _ = DataRecorder.sharedRgbRecorder.writeImageToVideo(ciImage: videoCIImage, cgImage: videoCGImage)
                    let _ = DataRecorder.sharedDepthRecorder.writeImageToVideo(ciImage: depthCIImage, cgImage: depthCGImage)
                    let _ = DataRecorder.sharedRawDepthRecorder.writeRawDepthToFile(pixelBuffer: depthPixelBuffer)
                }
                
                return videoCGImage // Preview videoCGImage
                // TODO: add metal API to overlay depth on video
            }
            .assign(to: &$frame)
    }
//
//    func startRecording() {
//        do {
//            try DataRecorder.shared.startRecording()
//        } catch {
//
//        }
//    }
//
//    func stopRecording() {
//        do {
//            try DataRecorder.shared.finishRecording { fileURL in
////                print(fileURL)
//            }
//        } catch {
//
//        }
//    }
}
