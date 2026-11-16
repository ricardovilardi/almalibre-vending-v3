import AVFoundation; import Vision; import CoreImage
// track <video> : prints t dx dy of the cup band vs frame at 16 s (image coords, y down)
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: url)
let tr = asset.tracks(withMediaType: .video)[0]
let H = 1920.0
let roi = CGRect(x: 600, y: H-1450, width: 380, height: 180)
func readAll() -> [(Double, CIImage)] {
  let r = try! AVAssetReader(asset: asset)
  let o = AVAssetReaderTrackOutput(track: tr, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
  r.add(o); r.startReading(); var out: [(Double, CIImage)] = []
  while let sb = o.copyNextSampleBuffer() {
    let t = CMSampleBufferGetPresentationTimeStamp(sb).seconds
    guard t >= 5.4 && t <= 22.6, let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
    out.append((t, CIImage(cvPixelBuffer: pb).cropped(to: roi).transformed(by: .init(translationX: -roi.minX, y: -roi.minY))))
  }
  return out
}
let ctx = CIContext()
let frames = readAll().map { ($0.0, ctx.createCGImage($0.1, from: CGRect(origin: .zero, size: roi.size))!) }
let ref = frames.min(by: { abs($0.0-16) < abs($1.0-16) })!.1
for (t, im) in frames {
  let req = VNTranslationalImageRegistrationRequest(targetedCGImage: ref)
  try! VNImageRequestHandler(cgImage: im).perform([req])
  let a = (req.results?.first as? VNImageTranslationAlignmentObservation)?.alignmentTransform ?? .identity
  print(String(format: "%.3f %.1f %.1f", t, a.tx, -a.ty))
}
