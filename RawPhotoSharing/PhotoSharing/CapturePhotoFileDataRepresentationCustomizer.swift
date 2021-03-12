//
//  CapturePhotoFileDataRepresentationCustomizer.swift
//  PhotoSharing
//
//  Created by Dolgopolik, Olesya on 12.03.2021.
//

import AVFoundation
import Foundation

final class CapturePhotoFileDataRepresentationCustomizer: NSObject, AVCapturePhotoFileDataRepresentationCustomizer {
    func replacementEmbeddedThumbnailPixelBuffer(withPhotoFormat replacementEmbeddedThumbnailPhotoFormatOut: AutoreleasingUnsafeMutablePointer<NSDictionary?>, for photo: AVCapturePhoto) -> Unmanaged<CVPixelBuffer>? {
          /// To preserve the existing embedded thumbnail photo to the flattened data, set *replacementEmbeddedThumbnailPhotoFormatOut to photo.embeddedThumbnailPhotoFormat and return nil.
        replacementEmbeddedThumbnailPhotoFormatOut.pointee = photo.embeddedThumbnailPhotoFormat as NSDictionary?
        return nil
      }
}
