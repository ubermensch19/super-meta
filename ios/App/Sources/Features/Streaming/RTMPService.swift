import Foundation
import SwiftUI
import AVFoundation
import VideoToolbox
import CoreMedia
import HaishinKit
import RTMPHaishinKit
import GlassesKit
import os.log

private let log = Logger(subsystem: "com.priyanshu.metamod", category: "RTMP")

/// Streams glasses camera frames to any RTMP endpoint (YouTube, Twitch, etc.)
/// via HaishinKit. Build-validated; requires glasses + a live RTMP server to verify.
@MainActor
final class RTMPService: ObservableObject {
    enum State: Equatable { case idle, connecting, streaming, error(String) }

    @Published private(set) var state: State = .idle
    @Published private(set) var framesSent = 0
    /// Frames appended per second, averaged over the session — a health readout.
    @Published private(set) var fps: Double = 0
    /// Seconds since the publish went live.
    @Published private(set) var connectionTime: TimeInterval = 0

    private var connection: RTMPConnection?
    private var stream: RTMPStream?
    private var pumpTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var statsTask: Task<Void, Never>?
    private var startTime: Date?

    private let width = 1280
    private let height = 720
    private let fpsTarget: Int32 = 24

    /// - Parameter bitrate: target video bitrate in bits per second.
    func start(url: String, streamKey: String, bitrate: Int, glasses: GlassesService) {
        guard !url.isEmpty else { state = .error("Enter an RTMP URL"); return }
        state = .connecting
        resetStats()
        Task { await setupAndPublish(url: url, streamKey: streamKey, bitrate: bitrate, glasses: glasses) }
    }

    private func bumpFrames() { framesSent += 1 }

    private func resetStats() {
        framesSent = 0
        fps = 0
        connectionTime = 0
        startTime = nil
    }

    func stop() {
        pumpTask?.cancel(); pumpTask = nil
        statusTask?.cancel(); statusTask = nil
        statsTask?.cancel(); statsTask = nil
        let stream = self.stream
        let connection = self.connection
        Task {
            try? await stream?.close()
            try? await connection?.close()
        }
        self.stream = nil
        self.connection = nil
        resetStats()
        state = .idle
    }

    private func setupAndPublish(url: String, streamKey: String, bitrate: Int, glasses: GlassesService) async {
        let connection = RTMPConnection()
        self.connection = connection
        let stream = RTMPStream(connection: connection)
        self.stream = stream

        var settings = VideoCodecSettings()
        settings.videoSize = CGSize(width: width, height: height)
        settings.bitRate = bitrate
        settings.maxKeyFrameIntervalDuration = 1
        settings.profileLevel = kVTProfileLevel_H264_Main_AutoLevel as String
        try? await stream.setVideoSettings(settings)

        do {
            _ = try await connection.connect(url)
            _ = try await stream.publish(streamKey, type: .live)
            startTime = Date()
            state = .streaming
            if !glasses.isStreaming { await glasses.startStreaming() }
            startPump(stream: stream, glasses: glasses)
            startStats()
        } catch {
            state = .error(error.localizedDescription)
            log.error("RTMP publish failed: \(error.localizedDescription)")
        }
    }

    /// Recomputes elapsed time and average fps once a second while live.
    private func startStats() {
        statsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                await MainActor.run {
                    guard let start = self.startTime else { return }
                    let elapsed = Date().timeIntervalSince(start)
                    self.connectionTime = elapsed
                    self.fps = elapsed > 0 ? Double(self.framesSent) / elapsed : 0
                }
            }
        }
    }

    private func startPump(stream: RTMPStream, glasses: GlassesService) {
        let fpsValue = fpsTarget
        let frameInterval = UInt64(1_000_000_000 / Double(fpsValue))
        let step = Int64(1_000_000) / Int64(fpsValue)
        pumpTask = Task { [weak self] in
            var ts: Int64 = 0
            while !Task.isCancelled {
                if let frame = await glasses.latestFrame,
                   let sample = frame.toCMSampleBuffer(timestamp: ts) {
                    await stream.append(sample)
                    ts += step
                    await MainActor.run { self?.bumpFrames() }
                }
                try? await Task.sleep(nanoseconds: frameInterval)
            }
        }
    }
}

extension UIImage {
    /// Converts the image to a 32BGRA CMSampleBuffer for the RTMP encoder.
    func toCMSampleBuffer(timestamp: Int64) -> CMSampleBuffer? {
        guard let cgImage else { return nil }
        let width = Int(size.width)
        let height = Int(size.height)
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer) == kCVReturnSuccess,
              let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &formatDescription)
        guard let format = formatDescription else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 24),
            presentationTimeStamp: CMTime(value: timestamp, timescale: 1_000_000),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault, imageBuffer: buffer, dataReady: true,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: format,
            sampleTiming: &timing, sampleBufferOut: &sampleBuffer
        )
        return sampleBuffer
    }
}
