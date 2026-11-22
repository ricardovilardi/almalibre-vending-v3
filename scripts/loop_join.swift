// Joins clips into one seamless loop: drops the last frame of every clip (each clip ends on the next clip's
// first frame), scales/crops to WxH (cover), composites an optional overlay PNG, writes H.264 without audio.
// Optional env XFADE=n: cross-dissolves n frames at each internal join (clips that meet on a held pose).
// usage: loop_join <out.mp4> <W> <H> <overlay.png|-> <clip1.mp4> [clip2.mp4 ...]
import AVFoundation; import CoreImage
let a=CommandLine.arguments; let out=URL(fileURLWithPath:a[1]); let W=Int(a[2])!, H=Int(a[3])!
let overlay: CIImage? = a[4] == "-" ? nil : CIImage(contentsOf:URL(fileURLWithPath:a[4]))
let clips=a.dropFirst(5).map{URL(fileURLWithPath:$0)}; try? FileManager.default.removeItem(at:out)
let ctx=CIContext(); let sem=DispatchSemaphore(value:0)
Task{
 var frames:[CIImage]=[]; var fps:Float=24; let xf=Int(ProcessInfo.processInfo.environment["XFADE"] ?? "0") ?? 0
 for c in clips { let asset=AVURLAsset(url:c); let tr=try await asset.loadTracks(withMediaType:.video)[0]; fps=try await tr.load(.nominalFrameRate)
  let r=try AVAssetReader(asset:asset); let ro=AVAssetReaderTrackOutput(track:tr,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]); r.add(ro); r.startReading()
  var fs:[CIImage]=[]; while let sb=ro.copyNextSampleBuffer(){ if let pb=CMSampleBufferGetImageBuffer(sb){ fs.append(CIImage(cvPixelBuffer:pb).copy() as! CIImage); _ = pb } }
  // materialise so buffers can be released
  fs = fs.map{ CIImage(cgImage: ctx.createCGImage($0, from:$0.extent)!) }
  fs.removeLast()
  if xf>0 && !frames.isEmpty {
   for k in 0..<xf { let t=Double(k+1)/Double(xf+1); let A=frames[frames.count-xf+k], B=fs[k]
    let m=CIFilter(name:"CIDissolveTransition")!; m.setValue(A,forKey:kCIInputImageKey); m.setValue(B,forKey:kCIInputTargetImageKey); m.setValue(t,forKey:kCIInputTimeKey)
    frames[frames.count-xf+k]=CIImage(cgImage:ctx.createCGImage(m.outputImage!.cropped(to:A.extent),from:A.extent)!) }
   fs.removeFirst(xf) }
  frames += fs; print("clip \(c.lastPathComponent): \(fs.count) frames") }
 let w=try AVAssetWriter(outputURL:out,fileType:.mp4); w.shouldOptimizeForNetworkUse=true
 let wi=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:W,AVVideoHeightKey:H,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:10_000_000,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel,AVVideoExpectedSourceFrameRateKey:Int(fps.rounded())]])
 let ad=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:wi,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H])
 w.add(wi); w.startWriting(); w.startSession(atSourceTime:.zero)
 for (i,img) in frames.enumerated(){
  let s=max(Double(W)/img.extent.width,Double(H)/img.extent.height)
  let f=CIFilter(name:"CILanczosScaleTransform")!; f.setValue(img,forKey:kCIInputImageKey); f.setValue(s,forKey:kCIInputScaleKey)
  var o=f.outputImage!; o=o.transformed(by:CGAffineTransform(translationX:-o.extent.minX-(o.extent.width-Double(W))/2,y:-o.extent.minY-(o.extent.height-Double(H))/2)).cropped(to:CGRect(x:0,y:0,width:W,height:H))
  if let ov=overlay { o=ov.composited(over:o) }
  while !wi.isReadyForMoreMediaData{ try await Task.sleep(nanoseconds:2_000_000) }
  var pb:CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil,ad.pixelBufferPool!,&pb); ctx.render(o,to:pb!)
  ad.append(pb!,withPresentationTime:CMTime(value:CMTimeValue(i),timescale:CMTimeScale(fps.rounded())))
 }
 wi.markAsFinished(); await w.finishWriting(); print(w.status == .completed ? "ok \(frames.count) frames" : "FAILED \(String(describing:w.error))"); sem.signal()}
sem.wait()
