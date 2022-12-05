//
//  RawDepthRecorder.swift
//  ASLDepthCapture
//
//  Created by Ting Yu on 12/4/22.
//

import Foundation
//import CoreImage
//import CoreVideo
import AVFoundation

class RawDepthRecorder {

    static let shared = RawDepthRecorder()
        
    var isReadyForWriting = false

    var processingQ: DispatchQueue = DispatchQueue(label: "writingRawDepthData", qos: .userInitiated)
    
    var filePath: URL?
    
    var dataDict: [[[Float16]]] = .init()
    var pixelBufferArray: [CVPixelBuffer] = .init()
    

    func fileOutputPath() -> URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentDirectory: URL = urls.first else {
            fatalError("documentDir Error")
        }
        
        let sessionTimestamp = RecordSession.current.timestamp ?? "TimestampError"
        let fileOutputURL = documentDirectory.appendingPathComponent("\(sessionTimestamp)-RawDepth")
        
        if fileManager.fileExists(atPath: fileOutputURL.path) {
            do {
                try FileManager.default.removeItem(atPath: fileOutputURL.path)
            } catch {
                fatalError("Unable to delete file: \(error) : \(#function).")
            }
        } else {
            fileManager.createFile(atPath: fileOutputURL.path, contents: nil)
        }
                
        return fileOutputURL
    }
    
    func reset() {
        dataDict = .init()
        filePath = nil
    }
    
    func prepareForRecording() {
        reset()
        
        self.filePath = fileOutputPath()
        self.isReadyForWriting = true
    }
    
    func startRecording() {
        processingQ.sync {
            self.prepareForRecording()
        }
    }
    
    func finishRecording(success: @escaping ((URL?) -> Void)) {
        guard let url = self.filePath else { return }
        isReadyForWriting = false
        processingQ.async { [self] in
            do {
                let file = try FileHandle(forWritingTo: url)
//                let jsonData = try JSONSerialization.data(withJSONObject: convertPixelBuffersToDepth())
//                file.write(jsonData)
                for data in convertPixelBuffersToDepthData() {
                    file.write(data)
                }
                try file.close()
                print("Depth json successfully wrote to file at \(url.path)")
            } catch {
                print("error: \(error)")
            }
            DispatchQueue.main.sync {
                success(self.filePath)
            }
            self.reset()
        }
    }
    
    func addRawDepth(pixelBuffer: CVPixelBuffer) {
        processingQ.sync {
            self.pixelBufferArray.append(pixelBuffer)
        }
        return
    }
    
    func convertPixelBuffersToDepth() -> [[[NSNumber]]] {
        return self.pixelBufferArray.map { buffer in
            return buffer.getRawDepths()
        }
    }
    
    func convertPixelBuffersToDepthData() -> [Data] {
        return self.pixelBufferArray.map { buffer in
            return buffer.data
        }
    }

}
