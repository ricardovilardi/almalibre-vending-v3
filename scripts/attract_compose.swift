// Build one language version of the attract video.
// Usage: attract_compose <source.mp4> <captions_dir> <button.png> <unused> <out.mp4> [static_layer.png]   (video only; add sound with mux_audio)
// static_layer: optional full-frame overlay on every frame (the white brand symbol, top-left).
// Per frame: source frame + caption layer (cap_NNNN.png) + tap button, which pulses (scale 1 → 1.045 → 1)
// every 2.5 s so the 25 s loop has a whole number of pulses (no jump at the loop point).
import AVFoundation
import CoreImage

let a = CommandLine.arguments
let src = URL(fileURLWithPath: a[1]), capDir = URL(fileURLWithPath: a[2])
let button = CIImage(contentsOf: URL(fileURLWithPath: a[3]))!
let wavURL = URL(fileURLWithPath: a[4]), out = URL(fileURLWithPath: a[5])
let staticLayer = a.count > 6 ? CIImage(contentsOf: URL(fileURLWithPath: a[6])) : nil
let W = 1080, H = 1920, FPS: Int32 = 24
let PULSE = 2.5, AMP = 0.045
let cx = 540.0, cy = Double(H) - 1773.5          // button centre in Core Image coordinates (origin bottom-left)

// ---- readers ----
let asset = AVURLAsset(url: src)
let vtrack = asset.tracks(withMediaType: .video)[0]
let vr = try! AVAssetReader(asset: asset)
let vout = AVAssetReaderTrackOutput(track: vtrack, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
vr.add(vout); vr.startReading()
// ---- writer ----
try? FileManager.default.removeItem(at: out)
let w = try! AVAssetWriter(outputURL: out, fileType: .mp4)
let vin = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2, AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: FPS, AVVideoMaxKeyFrameIntervalKey: 48]])
vin.expectsMediaDataInRealTime = false
let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vin, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
w.add(vin); w.startWriting(); w.startSession(atSourceTime: .zero)

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CIContext(options: [.workingColorSpace: cs, .outputColorSpace: cs])
let rect = CGRect(x: 0, y: 0, width: W, height: H)

// ---- video ----
let group = DispatchGroup()
var i = 0
group.enter()
vin.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while vin.isReadyForMoreMediaData {
        guard let sb = vout.copyNextSampleBuffer() else { vin.markAsFinished(); group.leave(); return }
        guard let pbIn = CMSampleBufferGetImageBuffer(sb) else { continue }
        var img = CIImage(cvPixelBuffer: pbIn)
        if let l = staticLayer { img = l.composited(over: img) }
        let cap = capDir.appendingPathComponent(String(format: "cap_%04d.png", i))
        if let c = CIImage(contentsOf: cap) { img = c.composited(over: img) }
        let t = Double(i) / Double(FPS)
        let s = 1 + AMP * (1 - cos(2 * .pi * t / PULSE)) / 2
        let tr = CGAffineTransform(translationX: cx, y: cy).scaledBy(x: s, y: s).translatedBy(x: -cx, y: -cy)
        img = button.transformed(by: tr).composited(over: img).cropped(to: rect)
        var pb: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, ad.pixelBufferPool!, &pb)
        ctx.render(img, to: pb!, bounds: rect, colorSpace: cs)
        ad.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: FPS))
        i += 1
    }
}
group.wait()

let sem = DispatchSemaphore(value: 0); w.finishWriting { sem.signal() }; sem.wait()
print(w.status == .completed ? "ok \(i) frames -> \(out.lastPathComponent)" : "error \(String(describing: w.error))")
