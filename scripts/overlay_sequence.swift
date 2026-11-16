// Burns a PNG sequence (1080x1920, transparent, one per video frame) plus optional static PNGs into a video.
// Replaces ffmpeg's overlay for machines without ffmpeg.
// usage: overlay_sequence <in.mp4> <frames_dir/cap_%04d.png> <out.mp4> [static.png ...]
import AVFoundation
import CoreImage
import AppKit

let a = CommandLine.arguments
let src = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let pattern = a[2]
let outURL = URL(fileURLWithPath: a[3]); try? FileManager.default.removeItem(at: outURL)
let statics = a.dropFirst(4).map { CIImage(contentsOf: URL(fileURLWithPath: $0))! }
// Optional logo printed on the cup, under the captions:
// CUP_LOGO=<1080x1920 transparent png> CUP_TRACK=<"t dx dy alpha" per line, dx/dy in px, y down>
let env = ProcessInfo.processInfo.environment
let cupLogo = env["CUP_LOGO"].map { CIImage(contentsOf: URL(fileURLWithPath: $0))! }
let cupTrack: [(t: Double, dx: Double, dy: Double, a: Double)] = (env["CUP_TRACK"].flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? "")
  .split(separator: "\n").compactMap { l in
    let v = l.split(separator: " ").compactMap { Double($0) }; return v.count == 4 ? (v[0], v[1], v[2], v[3]) : nil }
func cupLayer(at t: Double) -> CIImage? {
  guard let logo = cupLogo, let k = cupTrack.min(by: { abs($0.t - t) < abs($1.t - t) }), abs(k.t - t) < 0.03, k.a > 0.001 else { return nil }
  let m = CIFilter(name: "CIColorMatrix", parameters: [kCIInputImageKey: logo, "inputAVector": CIVector(x: 0, y: 0, z: 0, w: k.a)])!.outputImage!
  return m.transformed(by: CGAffineTransform(translationX: k.dx, y: -k.dy))
}
let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
let sem = DispatchSemaphore(value: 0)

Task {
  let track = try await src.loadTracks(withMediaType: .video)[0]
  let size = try await track.load(.naturalSize)
  let fps = try await track.load(.nominalFrameRate)
  let reader = try AVAssetReader(asset: src)
  let ro = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  reader.add(ro)
  let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
  writer.shouldOptimizeForNetworkUse = true
  let wi = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoExpectedSourceFrameRateKey: Int(fps.rounded())]])
  wi.expectsMediaDataInRealTime = false
  let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: wi, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)])
  writer.add(wi)
  reader.startReading(); writer.startWriting(); writer.startSession(atSourceTime: .zero)
  var i = 0
  while let sb = ro.copyNextSampleBuffer() {
    guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sb)
    var img = CIImage(cvPixelBuffer: pb)
    if let c = cupLayer(at: t.seconds) { img = c.composited(over: img) }
    let path = String(format: pattern, i)
    if let cap = CIImage(contentsOf: URL(fileURLWithPath: path)) { img = cap.composited(over: img) }
    for s in statics { img = s.composited(over: img) }
    while !wi.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
    var outPB: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, ad.pixelBufferPool!, &outPB)
    ctx.render(img.cropped(to: CGRect(origin: .zero, size: size)), to: outPB!)
    ad.append(outPB!, withPresentationTime: t)
    i += 1
  }
  wi.markAsFinished(); await writer.finishWriting()
  print(writer.status == .completed ? "ok \(i) frames -> \(a[3])" : "FAILED \(String(describing: writer.error))")
  sem.signal()
}
sem.wait()
