// segtrack <video> <t_start> <t_end> : chains frame-to-frame translations of the cup body (Vision),
// starting from the rest pose (identity = cup as at 16 s) at t_start, walking towards t_end (either direction).
// Prints "t h11 h12 h13 h21 h22 h23 h31 h32 h33" mapping rest-pose CI coords (y up) -> frame CI coords.
import AVFoundation; import Vision; import CoreImage; import simd
let A = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: A[1]))
let t0 = Double(A[2])!, t1 = Double(A[3])!
let lo = min(t0, t1) - 0.05, hi = max(t0, t1) + 0.05
let tr = asset.tracks(withMediaType: .video)[0]
let r = try! AVAssetReader(asset: asset)
let o = AVAssetReaderTrackOutput(track: tr, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
r.add(o); r.startReading()
let ctx = CIContext()
var fr: [(Double, CIImage)] = []
while let sb = o.copyNextSampleBuffer() {
  let t = CMSampleBufferGetPresentationTimeStamp(sb).seconds
  guard t >= lo && t <= hi, let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
  let ci = CIImage(cvPixelBuffer: pb); fr.append((t, CIImage(cgImage: ctx.createCGImage(ci, from: ci.extent)!)))
}
if t1 < t0 { fr.reverse() }
// cup body (purple band) in rest pose, CI coords: x 565..995, y (1920-1450)..(1920-1215)
let body = CGRect(x: 565, y: 470, width: 430, height: 235)
var H = matrix_identity_float3x3
func apply(_ m: simd_float3x3, _ p: CGPoint) -> CGPoint { let v = m * SIMD3<Float>(Float(p.x), Float(p.y), 1); return CGPoint(x: CGFloat(v.x / v.z), y: CGFloat(v.y / v.z)) }
func pr(_ t: Double) { let m = H; print(String(format: "%.3f", t), (0..<3).flatMap { row in (0..<3).map { col in String(format: "%.6f", m[col][row]) } }.joined(separator: " ")) }
pr(fr[0].0)
for k in 0..<(fr.count - 1) {
  let corners = [CGPoint(x: body.minX, y: body.minY), CGPoint(x: body.maxX, y: body.minY), CGPoint(x: body.minX, y: body.maxY), CGPoint(x: body.maxX, y: body.maxY)].map { apply(H, $0) }
  var win = CGRect(x: corners.map(\.x).min()!, y: corners.map(\.y).min()!, width: 0, height: 0)
  win.size = CGSize(width: corners.map(\.x).max()! - win.minX, height: corners.map(\.y).max()! - win.minY)
  win = win.insetBy(dx: -6, dy: -6).intersection(CGRect(x: 0, y: 0, width: 1080, height: 1920)).integral
  if win.width < 60 || win.height < 40 { pr(fr[k + 1].0); continue }
  func crop(_ im: CIImage) -> CGImage { ctx.createCGImage(im, from: win)! }
  let a = crop(fr[k].1), b = crop(fr[k + 1].1)
  // translation of frame k+1 relative to frame k inside the window (CI coords, y up)
  let req = VNTranslationalImageRegistrationRequest(targetedCGImage: a)
  try! VNImageRequestHandler(cgImage: b).perform([req])
  if let w = (req.results?.first as? VNImageTranslationAlignmentObservation)?.alignmentTransform, abs(w.tx) < 120, abs(w.ty) < 120 {
    H = simd_float3x3(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Float(w.tx), Float(w.ty), 1)) * H
  }
  pr(fr[k + 1].0)
}
