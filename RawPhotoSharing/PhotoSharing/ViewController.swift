//
//  ViewController.swift
//  PhotoSharing
//
//  Created by Dolgopolik, Olesya on 01.03.2021.
//

import AVFoundation
import Photos
import UIKit

enum CameraError: Error {
    case setupFailed
}

class ViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentVideoInput: AVCaptureDeviceInput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var captureDelegates = [Int64: RAWCaptureDelegate]()

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var capturedImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            try setupSession()
        }
        catch {
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.captureSession.startRunning()
        self.videoPreviewLayer.frame = self.previewView.bounds
    }

    private func setupSession() throws {
        // Start capture session configuration.
        captureSession.beginConfiguration()

        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Unable to access back camera!")
            captureSession.commitConfiguration()
            return
        }


        // Configure the session for photo capture.
        captureSession.sessionPreset = .photo

        // Connect the default video device.
        let videoInput = try AVCaptureDeviceInput(device: backCamera)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            currentVideoInput = videoInput
        } else {
            throw CameraError.setupFailed
        }

        // Connect and configure capture output.
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        } else {
            throw CameraError.setupFailed
        }

        setupLivePreview()

        // Session configured. Commit configuration.
        captureSession.commitConfiguration()
    }

    func setupLivePreview() {

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
    }

    @IBAction func takePhoto(_ sender: Any) {
        let query = { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }

        // Retrieve the RAW format, favoring Apple ProRAW when enabled.
        guard let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first(where: query) else {
            fatalError("No RAW format found.")
        }

        // Capture a RAW format photo, along with a processed format photo.
        let processedFormat = [AVVideoCodecKey: AVVideoCodecType.jpeg]
        let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat,
                                                   processedFormat: processedFormat)

        // Create a delegate to monitor the capture process.
        let delegate = RAWCaptureDelegate()
        captureDelegates[photoSettings.uniqueID] = delegate

        // Remove the delegate reference when it finishes its processing.
        delegate.didFinish = {
            self.captureDelegates[photoSettings.uniqueID] = nil
        }

        // Tell the output to capture the photo.
        photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
    }

    @IBAction func shareLastPhoto(_ sender: Any) {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization {
                status in
                if status == .authorized {
                    self.shareLastAsset()
                }
            }
        }
        else if status == .authorized {
            shareLastAsset()
        }
    }

    private func shareLastAsset() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let lastAsset = fetchResult.lastObject else { return }
        let assetResources = PHAssetResource.assetResources(for: lastAsset)
        let possibleRawAssetResource = assetResources.first { resource in
            return resource.uniformTypeIdentifier.contains("raw")
        }

        guard let rawAssetResource = possibleRawAssetResource else { return }
        guard let documentURL = try? FileManager.default.url(for: .documentDirectory,
                                                             in: .userDomainMask,
                                                             appropriateFor: nil,
                                                             create: true) else { return }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        let url = documentURL.appendingPathComponent(rawAssetResource.originalFilename)

        PHAssetResourceManager.default().writeData(for: rawAssetResource, toFile: url, options: options) { error in
            DispatchQueue.main.async {
                let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                vc.completionWithItemsHandler = { _, _, _, _ in
                    self.dismiss(animated: true, completion: nil)
                }
                vc.excludedActivityTypes = [.openInIBooks, .markupAsPDF, .saveToCameraRoll]
                self.present(vc, animated: true, completion: nil)
            }
        }
    }
}

