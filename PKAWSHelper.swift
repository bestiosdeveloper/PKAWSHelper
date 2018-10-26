
//  AWSController.swift
//
//  Created by Pramod Kumar on 26/07/17.
//  Copyright © 2017 Pramod Kumar. All rights reserved.


import Foundation
import AWSCore
import AWSS3
import UIKit
import AVKit

class PKAWSHelper {
    
    //MARK: Important credentials for AWS(S3)
    private let S3BaseUrl          = "https://epicapp.s3.amazonaws.com/"
    private let poolId             = "us-east-1:679f3b4e-4dc0-4cd6-8090-e8c6cee53539"
    private let BucketName         = "epicapp"
    private let BucketDirectory    = "iOS"
    
    enum FileType {
        case image
        case video
        case audio
        case doc
        
        var `extension`: String {
            switch self {
            case .image:
                return "png"
                
            case .video:
                return "mp4"
                
            case .audio:
                return "mp3"
                
            case .doc:
                return "pdf"
            }
        }
        
        func getContentType(forExtension: String) -> String {
            switch self {
            case .image:
                return "image/\(forExtension)"
                
            case .video:
                return "video/\(forExtension)"
                
            case .audio:
                return "audio/\(forExtension)"
                
            case .doc:
                return "file/\(forExtension)"
            }
        }
    }
    
    //MARK: Shared Instance
    //MARK: =================
    static let shared = PKAWSHelper()
    private init() {
        self.setupAmazonS3(withPoolID: self.poolId)
    }
    
    //MARK: CANCEL REQUEST
    //MARK: =================
    func cancelAllRequest() {
        AWSS3TransferManager.default().cancelAll()
    }
    
    //MARK: Setting S3 server with the credentials...
    //MARK: =========================================
    func upload(url: URL,
                fileType: FileType,
                uploadFolderName: String = "",
                fileName: String = "",
                success : @escaping (Bool, String) -> Void,
                progress : @escaping (CGFloat) -> Void,
                failure : @escaping (Error) -> Void) {
        
        
        let lFileName = fileName.isEmpty ? (url.lastPathComponent.components(separatedBy: ".").first ?? UUID().uuidString) : fileName
        let fileExtension = url.lastPathComponent.components(separatedBy: ".").last ?? fileType.extension
        let fileNameWithExtension = "\(lFileName).\(fileExtension)"
        
        if url.absoluteString.hasPrefix("file:") {
            //upload to S3
            self.uploadFile(url: url, fileType: fileType, fileName: lFileName, fileExtension: fileExtension, success: success, progress: progress, failure: failure)
        }
        else {
            //download and save to local
            let tempPath = "\(NSTemporaryDirectory())/\(fileNameWithExtension)"
            do {
                let data = try Data(contentsOf: url)
                try data.write(to: URL(fileURLWithPath: tempPath), options: .atomic)
                //upload to S3
                self.uploadFile(url: URL(fileURLWithPath: tempPath), fileType: fileType, fileName: lFileName, fileExtension: fileExtension, success: success, progress: progress, failure: failure)
            }
            catch {
                print(error)
            }
        }
    }
    
    
    //MARK: Private Methods
    //MARK: =================
    private func setupAmazonS3(withPoolID poolID: String) {
        
        let credentialsProvider = AWSCognitoCredentialsProvider( regionType: .USEast1,
                                                                 identityPoolId: poolID)
        let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }
    
    private func uploadFile(url: URL,
                            fileType: FileType,
                            uploadFolderName: String = "",
                            fileName: String,
                            fileExtension: String,
                            success : @escaping (Bool, String) -> Void,
                            progress : @escaping (CGFloat) -> Void,
                            failure : @escaping (Error) -> Void) {
        
        DispatchQueue.main.async {
            
            guard let uploadRequest = AWSS3TransferManagerUploadRequest() else {
                
                let err = NSError(domain: "There is a problem while making the uploading request.", code : 02, userInfo : nil)
                failure(err)
                return
            }
            uploadRequest.bucket = "\(self.BucketName)/\(self.BucketDirectory)\(uploadFolderName.isEmpty ? "" : "/\(uploadFolderName)")"
            uploadRequest.acl    = AWSS3ObjectCannedACL.publicRead
            uploadRequest.key    = "\(fileName).\(fileExtension)"
            uploadRequest.body   = url
            uploadRequest.contentType = fileType.getContentType(forExtension: fileExtension)
            
            uploadRequest.uploadProgress = {(
                bytesSent : Int64,
                totalBytesSent : Int64,
                _ totalBytesExpectedToSend : Int64) -> Void in
                
                progress((CGFloat(totalBytesSent)/CGFloat(totalBytesExpectedToSend)))
                //            print((CGFloat(totalBytesSent)/CGFloat(totalBytesExpectedToSend)))
            }
            
            AWSS3TransferManager.default().upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task) -> Void in
                
                if let err = task.error {
                    failure(err)
                } else {
                    
                    let url = "\(self.S3BaseUrl)\(self.BucketName)/\(self.BucketDirectory)\(uploadFolderName.isEmpty ? "" : "/\(uploadFolderName)")/\(fileName).\(fileExtension)"
                    
                    success(true, url)
                }
            }
        }
        
    }
    
    
//    func uploadTOS3Video(url: URL,
//                                uploadFolderName: String = "",
//                                fileName: String,
//                                success : @escaping (Bool, String) -> Void,
//                                progress : @escaping (CGFloat) -> Void,
//                                failure : @escaping (Error) -> Void) {
//
//        let name = "\(fileName).mp4"
//        let path = NSTemporaryDirectory().stringByAppendingPathComponent(path: name)
//
//        let dispatchgroup = DispatchGroup()
//
//        dispatchgroup.enter()
//
//        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let outputurl = documentsURL.appendingPathComponent(name)
//        var ur = outputurl
//        self.convertVideo(toMPEG4FormatForVideo: url as URL, outputURL: outputurl) { (session) in
//
//            ur = session.outputURL!
//            dispatchgroup.leave()
//
//        }
//        dispatchgroup.wait()
//
//        let data = NSData(contentsOf: ur as URL)
//
//        do {
//
//            try data?.write(to: URL(fileURLWithPath: path), options: .atomic)
//
//        } catch {
//
//            print(error)
//        }
//
//        DispatchQueue.main.async {
//
//            let nurl = NSURL(fileURLWithPath: path)
//
//            guard let uploadRequest = AWSS3TransferManagerUploadRequest() else {
//
//                let err = NSError(domain: "There is a problem while making the uploading request.", code : 02, userInfo : nil)
//                failure(err)
//                return
//            }
//
//            uploadRequest.bucket = "\(BUCKET_NAME)/\(BUCKET_DIRECTORY)\(uploadFolderName.isEmpty ? "" : "/\(uploadFolderName)")"
//            uploadRequest.acl    = AWSS3ObjectCannedACL.publicRead
//            uploadRequest.key    = name
//            uploadRequest.body   = nurl as URL!
//            uploadRequest.body  = URL(fileURLWithPath: path)
//
//
//            uploadRequest.uploadProgress = {(
//                bytesSent : Int64,
//                totalBytesSent : Int64,
//                _ totalBytesExpectedToSend : Int64) -> Void in
//
//                progress((CGFloat(totalBytesSent)/CGFloat(totalBytesExpectedToSend)))
//                //            print((CGFloat(totalBytesSent)/CGFloat(totalBytesExpectedToSend)))
//            }
//
//            AWSS3TransferManager.default().upload(uploadRequest).continueWith(executor: AWSExecutor.mainThread()) { (task) -> Void in
//
//                //MARK: That will remove image from temporary storage (NSTemporaryDirectory())...
//                try? FileManager.default.removeItem(atPath : path)
//                if let err = task.error {
//
//                    failure(err)
//                } else {
//
//                    let url = "https://s3.amazonaws.com/\(BUCKET_NAME)/\(BUCKET_DIRECTORY)\(uploadFolderName.isEmpty ? "" : "/\(uploadFolderName)")/\(name)"
//
//                    success(true, url)
//                }
//            }
//        }
//    }
}
