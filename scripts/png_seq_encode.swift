// Encode a PNG sequence (RGBA) to video.
// Usage: png_seq_encode <frames_dir> <out> <mode> [fps]
//   mode = cream  -> H.264 MP4, frames composited over #FFFCF5
//   mode = alpha  -> HEVC-with-alpha MOV (keeps transparency)
import Foundation
import AVFoundation
import CoreImage

let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1]), out = URL(fileURLWithPath: a[2]), mode = a[3]
let fps = Int32(a.count > 4 ? Int(a[4])! : 24)
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = CIImage(contentsOf: files[0]) else { fatalError("cannot read frames") }
let W = Int(first.extent.width), H = Int(first.extent.height)
try? FileManager.default.removeItem(at: out)
let alpha = mode == "alpha"
let w = try AVAssetWriter(outputURL: out, fileType: alpha ? .mov : .mp4)
var settings: [String: Any] = [AVVideoWidthKey: W, AVVideoHeightKey: H]
if alpha {
    settings[AVVideoCodecKey] = AVVideoCodecType.hevcWithAlpha
    settings[AVVideoCompressionPropertiesKey] = [AVVideoQualityKey: 0.85,
        "TargetQualityForAlpha": 0.9, "AlphaChannelMode": "PremultipliedAlpha"] as [String: Any]
} else {
    settings[AVVideoCodecKey] = AVVideoCodecType.h264
    settings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey: 10_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]
}
let inp = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
inp.expectsMediaDataInRealTime = false
let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: inp, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
w.add(inp); w.startWriting(); w.startSession(atSourceTime: .zero)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CIContext(options: [.workingColorSpace: cs, .outputColorSpace: cs])
let cream = CIImage(color: CIColor(red: 1.0, green: 252/255, blue: 245/255)).cropped(to: first.extent)
for (i, f) in files.enumerated() {
    var img = CIImage(contentsOf: f)!
    if !alpha { img = img.composited(over: cream) }
    while !inp.isReadyForMoreMediaData { usleep(2000) }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, ad.pixelBufferPool!, &pb)
    ctx.render(img, to: pb!, bounds: first.extent, colorSpace: cs)
    ad.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
inp.markAsFinished()
let sem = DispatchSemaphore(value: 0); w.finishWriting { sem.signal() }; sem.wait()
print(w.status == .completed ? "ok \(files.count) frames \(W)x\(H) -> \(out.lastPathComponent)" : "error \(String(describing: w.error))")
