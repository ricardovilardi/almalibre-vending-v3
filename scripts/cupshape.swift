// cupshape <video> <t0> <t1> [maskdir] : segments the cup (purple body + cream rim) by colour inside a search box
// and prints "t cx cy angle_deg width height area" from image moments (image coords, y down).
// With maskdir, also writes mask_<t>.png for checking.
import AVFoundation; import CoreImage; import AppKit
let A = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: A[1]))
let t0 = Double(A[2])!, t1 = Double(A[3])!
let maskDir = A.count > 4 ? A[4] : nil
let tr = asset.tracks(withMediaType: .video)[0]
let r = try! AVAssetReader(asset: asset)
let o = AVAssetReaderTrackOutput(track: tr, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
r.add(o); r.startReading()
let bx0 = 480, bx1 = 1080, by0 = 950, by1 = 1520   // search box (image coords)
while let sb = o.copyNextSampleBuffer() {
  let t = CMSampleBufferGetPresentationTimeStamp(sb).seconds
  guard t >= t0 - 0.001 && t <= t1 + 0.001, let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
  CVPixelBufferLockBaseAddress(pb, .readOnly)
  let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
  let bpr = CVPixelBufferGetBytesPerRow(pb)
  var n = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0
  var mask = [UInt8](repeating: 0, count: (bx1-bx0)*(by1-by0))
  for y in by0..<by1 { for x in bx0..<bx1 {
    let p = base + y*bpr + x*4
    let b = Double(p[0])/255, g = Double(p[1])/255, rr = Double(p[2])/255
    let mx = max(rr,g,b), mn = min(rr,g,b), v = mx, s = mx > 0 ? (mx-mn)/mx : 0
    var h = 0.0
    if mx > mn { if mx == rr { h = 60*((g-b)/(mx-mn)) } else if mx == g { h = 60*((b-rr)/(mx-mn)+2) } else { h = 60*((rr-g)/(mx-mn)+4) } }
    if h < 0 { h += 360 }
    let purple = (h > 300 && h < 343) && s > 0.38 && s < 0.8 && v > 0.42 && v < 0.85
    let cream = s < 0.22 && v > 0.8
    if purple || (cream && ProcessInfo.processInfo.environment["WITH_RIM"] != nil) {
      mask[(y-by0)*(bx1-bx0)+(x-bx0)] = 255
      let X = Double(x), Y = Double(y); n += 1; sx += X; sy += Y; sxx += X*X; syy += Y*Y; sxy += X*Y
    }
  } }
  CVPixelBufferUnlockBaseAddress(pb, .readOnly)
  let cx = sx/n, cy = sy/n, mxx = sxx/n-cx*cx, myy = syy/n-cy*cy, mxy = sxy/n-cx*cy
  let ang = 0.5*atan2(2*mxy, mxx-myy)*180/Double.pi
  let l1 = (mxx+myy)/2 + sqrt(pow((mxx-myy)/2,2)+mxy*mxy), l2 = (mxx+myy)/2 - sqrt(pow((mxx-myy)/2,2)+mxy*mxy)
  print(String(format: "%.3f %.1f %.1f %.2f %.1f %.1f %.0f", t, cx, cy, ang, sqrt(12*l1), sqrt(12*max(l2,0)), n))
  if let d = maskDir {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: bx1-bx0, pixelsHigh: by1-by0, bitsPerSample: 8, samplesPerPixel: 1, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceWhite, bytesPerRow: bx1-bx0, bitsPerPixel: 8)!
    memcpy(rep.bitmapData!, mask, mask.count)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: String(format: "%@/m_%.2f.png", d, t)))
  }
}
