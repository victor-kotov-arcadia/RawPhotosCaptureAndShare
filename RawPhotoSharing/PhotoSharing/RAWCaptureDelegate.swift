//
//  RAWCaptureDelegate.swift
//  PhotoSharing
//
//  Created by Dolgopolik, Olesya on 01.03.2021.
//

import AVFoundation
import Foundation
import Photos

class RAWCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    private var rawFileURL: URL?
    private var compressedData: Data?
    private let customizer = CapturePhotoFileDataRepresentationCustomizer()

    var didFinish: (() -> Void)?

    // Store the RAW file and compressed photo data until the capture finishes.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }

        // Access the file data representation of this photo.
        guard let photoData = photo.fileDataRepresentation(with: customizer) else {
            print("No photo data to write.")
            return
        }

        if photo.isRawPhoto {
            // Generate a unique URL to write the RAW file.
            rawFileURL = makeUniqueDNGFileURL()
            do {
                // Write the RAW (DNG) file data to a URL.
                try photoData.write(to: rawFileURL!)
            } catch {
                fatalError("Couldn't write DNG file to the URL.")
            }
        } else {
            // Store compressed bitmap data.
            compressedData = photoData
        }
    }

    private func makeUniqueDNGFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = ProcessInfo.processInfo.globallyUniqueString
        return tempDir.appendingPathComponent(fileName).appendingPathExtension("dng")
    }


    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {

        // Call the "finished" closure, if set.
        defer { didFinish?() }

        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }

        // Ensure the RAW and processed photo data exists.
        guard let rawFileURL = rawFileURL,
              let compressedData = compressedData else {
            print("The expected photo data isn't available.")
            return
        }

        // Request add-only access to the user's photo library (if not already granted).
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in

            // Don't continue if not authorized.
            guard status == .authorized else { return }

            PHPhotoLibrary.shared().performChanges {
                // Add the compressed (HEIF) data as the main resource for the Photos asset.
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: compressedData, options: nil)

                // Save the RAW (DNG) file as an alternative resource.
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                creationRequest.addResource(with: .alternatePhoto, fileURL: rawFileURL, options: options)

            } completionHandler: { success, error in
                // Process the photo library error.
            }
        }
    }
}
