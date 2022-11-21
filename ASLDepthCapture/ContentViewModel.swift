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
            } else {
                DataRecorder.sharedRgbRecorder.finishRecording { url in
//                    print(url)
                }
                DataRecorder.sharedDepthRecorder.finishRecording(success: { url in
                    
                })
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
                guard let depthCIImage = dataWrapper?.currentDepthCIImage, let depthCGImage = self.context.createCGImage(depthCIImage, from: depthCIImage.extent) else { return nil }
                guard let videoCIImage = dataWrapper?.currentVideoCIImage, let videoCGImage = self.context.createCGImage(videoCIImage, from: videoCIImage.extent) else { return nil }
                if DataRecorder.sharedRgbRecorder.isReadyForWriting, DataRecorder.sharedDepthRecorder.isReadyForWriting {
                    let _ = DataRecorder.sharedRgbRecorder.writeImageToVideo(ciImage: videoCIImage, cgImage: videoCGImage)
                    let _ = DataRecorder.sharedDepthRecorder.writeImageToVideo(ciImage: depthCIImage, cgImage: depthCGImage)
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
