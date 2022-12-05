//
//  CameraManager.swift
//  ASLDepthCapture
//
//  Created by Ting Yu.
//

import AVFoundation
import UIKit

class CameraManager: ObservableObject {
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    static let shared = CameraManager()
    
    @Published var error: CameraError?
    
    let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.ASLDepthCapture.SessionQ")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    private var status = Status.unconfigured
    
    private init() {
        configure()
    }
    
    private func set(error: CameraError?) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = .unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
    }
    
    private func configureCaptureSession() {
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        
        defer {
            session.commitConfiguration()
        }
        
        let device: AVCaptureDevice? = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera], mediaType: .video, position: .front).devices.first
        
        guard let camera = device else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        print("Camera Specs for \(camera)")
        print("FrameRate: \(camera.activeFormat.videoSupportedFrameRateRanges)")
        print("FoV: \(camera.activeFormat.videoFieldOfView)")
        if #available(iOS 16.0, *) {
            print("Dimensions: \(camera.activeFormat.supportedMaxPhotoDimensions)")
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            set(error: .createCaptureInput(error))
            status = .failed
            return
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            videoOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoOrientation = .portrait
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        // Add a depth data output
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = false
            if let connection = depthOutput.connection(with: .depthData) {
                connection.isEnabled = true
            } else {
                print("No AVCaptureConnection")
            }
        } else {
            set(error: .cannotAddDepthOutput)
            status = .failed
            return
        }
        
        // Search for highest resolution with half-point depth values
        let depthFormats = camera.activeFormat.supportedDepthDataFormats
        let filtered = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
//            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        })
        let selectedFormat = filtered.max(by: {
            first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
        })
        
//        let availableFormats = camera.activeFormat.supportedDepthDataFormats
//
//        let depthFormat = availableFormats.filter { format in
//            let pixelFormatType =
//                CMFormatDescriptionGetMediaSubType(format.formatDescription)
//
//            return (pixelFormatType == kCVPixelFormatType_DepthFloat16 ||
//                    pixelFormatType == kCVPixelFormatType_DepthFloat32)
//        }.first
        
        
        do {
            try camera.lockForConfiguration()
            camera.activeDepthDataFormat = selectedFormat
            camera.unlockForConfiguration()
        } catch {
            set(error: .cannotLockCameraForConfiguration)
            status = .failed
            return
        }
        
        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
//        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
        
        status = .configured
    }
    
    private func configure() {
        checkPermissions()
        
        sessionQueue.async {
            self.configureCaptureSession()
            self.session.startRunning()
        }
    }
    
//    func set(
//        _ delegate: AVCaptureVideoDataOutputSampleBufferDelegate,
//        queue: DispatchQueue
//    ) {
//        sessionQueue.async {
//            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
//        }
//    }
    
    func set(
        _ delegate: AVCaptureDataOutputSynchronizerDelegate,
        queue: DispatchQueue
    ) {
        sessionQueue.async {
            // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
            // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
            if let synchronizer = self.outputSynchronizer {
                synchronizer.setDelegate(delegate, queue: queue)
            }
        }
    }
}

extension CameraManager {
    
    // TODO: - Add Thermal state alert pop-up
    // You can use this opportunity to take corrective action to help cool the system down.
    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }
    
    func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            var thermalStateString = "UNKNOWN"
            if state == .nominal {
                thermalStateString = "NOMINAL"
            } else if state == .fair {
                thermalStateString = "FAIR"
            } else if state == .serious {
                thermalStateString = "SERIOUS"
            } else if state == .critical {
                thermalStateString = "CRITICAL"
            }
            
            
        print(thermalStateString)
            
//            let message = NSLocalizedString("Thermal state: \(thermalStateString)", comment: "Alert message when thermal state has changed")
//            let alertController = UIAlertController(title: "TrueDepthStreamer", message: message, preferredStyle: .alert)
//            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
//            self.present(alertController, animated: true, completion: nil)
        }
    }
}
