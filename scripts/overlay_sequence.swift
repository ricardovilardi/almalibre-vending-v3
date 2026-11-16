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
// CUP_LOGO=<1080x1920 transparent png, logo centred at CUP_CENTER (image coords, default 775,1332)>
// CUP_TRACK=<"t dx dy angle blur alpha occl" per line: offset in px (y down), clockwise degrees,
//            horizontal motion-blur radius px, opacity, occl=1 hides the logo where Almita's dark body covers the cup>
let env = ProcessInfo.processInfo.environment
let cupLogo = env["CUP_LOGO"].map { CIImage(contentsOf: URL(fileURLWithPath: $0))! }
let cupCenter = (env["CUP_CENTER"] ?? "775,1332").split(separator: ",").map { Double($0)! }
let cupTrack: [[Double]] = (env["CUP_TRACK"].flatMap { try? String(contentsOfFile: $0, encoding: .utf8) } ?? "")
  .split(separator: "\n").compactMap { l in let v = l.split(separator: " ").compactMap { Double($0) }; return v.count == 7 ? v : nil }
// keeps the logo only where the frame is not Almita (dark, saturated plum)
let occlusion = CIColorKernel(source: """
kernel vec4 occl(__sample logo, __sample f) {
  float mx = max(f.r, max(f.g, f.b)); float mn = min(f.r, min(f.g, f.b));
  float s = mx > 0.0 ? (mx - mn) / mx : 0.0;
  float almita = smoothstep(0.62, 0.70, s) * (1.0 - smoothstep(0.50, 0.56, mx)) * step(f.b, f.r * 0.62);
  return logo * (1.0 - almita);
}
""")!
func cupLayer(at t: Double, over frame: CIImage) -> CIImage? {
  guard let logo = cupLogo, let k = cupTrack.min(by: { abs($0[0] - t) < abs($1[0] - t) }), abs(k[0] - t) < 0.03, k[5] > 0.001 else { return nil }
  let cx = cupCenter[0], cy = 1920 - cupCenter[1], ang = -k[3] * .pi / 180
  var img = logo.transformed(by: CGAffineTransform(translationX: -cx, y: -cy).concatenating(CGAffineTransform(rotationAngle: ang))
    .concatenating(CGAffineTransform(translationX: cx + k[1], y: cy - k[2])))
  if k[4] > 0.3 {
    img = img.applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: k[4], kCIInputAngleKey: 0])
  }
  img = img.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: k[5])])
  if k[6] > 0.5 { img = occlusion.apply(extent: frame.extent, arguments: [img, frame])! }
  return img.cropped(to: frame.extent)
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
    if let c = cupLayer(at: t.seconds, over: img) { img = c.composited(over: img) }
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
