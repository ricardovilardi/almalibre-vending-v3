// in.mp4 out.mp4 W H dropLast [overlay.png]
import AVFoundation; import CoreImage
let a=CommandLine.arguments; let W=Int(a[3])!, H=Int(a[4])!, drop=Int(a[5])!
let out=URL(fileURLWithPath:a[2]); try? FileManager.default.removeItem(at:out)
let ctx=CIContext(); let sem=DispatchSemaphore(value:0); let overlay: CIImage? = a.count>6 ? CIImage(contentsOf:URL(fileURLWithPath:a[6])) : nil
Task{
 let asset=AVURLAsset(url:URL(fileURLWithPath:a[1])); let tr=try await asset.loadTracks(withMediaType:.video)[0]
 let fps=try await tr.load(.nominalFrameRate)
 let r=try AVAssetReader(asset:asset); let ro=AVAssetReaderTrackOutput(track:tr,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]); r.add(ro); r.startReading()
 var frames:[(CIImage,CMTime)]=[]
 while let sb=ro.copyNextSampleBuffer(){ if let pb=CMSampleBufferGetImageBuffer(sb){ frames.append((CIImage(cvPixelBuffer:pb),CMSampleBufferGetPresentationTimeStamp(sb))) } }
 frames.removeLast(drop)
 let w=try AVAssetWriter(outputURL:out,fileType:.mp4); w.shouldOptimizeForNetworkUse=true
 let wi=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:W,AVVideoHeightKey:H,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:10_000_000,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel,AVVideoExpectedSourceFrameRateKey:Int(fps.rounded())]])
 let ad=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:wi,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H])
 w.add(wi); w.startWriting(); w.startSession(atSourceTime:.zero)
 for (i,(img,_)) in frames.enumerated(){
  let s=max(Double(W)/img.extent.width,Double(H)/img.extent.height)
  let f=CIFilter(name:"CILanczosScaleTransform")!; f.setValue(img,forKey:kCIInputImageKey); f.setValue(s,forKey:kCIInputScaleKey)
  var o=f.outputImage!; o=o.transformed(by:CGAffineTransform(translationX:-o.extent.minX-(o.extent.width-Double(W))/2,y:-o.extent.minY-(o.extent.height-Double(H))/2))
  if let ov=overlay { o=ov.composited(over:o.cropped(to:CGRect(x:0,y:0,width:W,height:H))) }
  while !wi.isReadyForMoreMediaData{ try await Task.sleep(nanoseconds:2_000_000) }
  var pb:CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil,ad.pixelBufferPool!,&pb)
  ctx.render(o.cropped(to:CGRect(x:0,y:0,width:W,height:H)),to:pb!)
  ad.append(pb!,withPresentationTime:CMTime(value:CMTimeValue(i),timescale:CMTimeScale(fps.rounded())))
 }
 wi.markAsFinished(); await w.finishWriting(); print(w.status == .completed ? "ok \(frames.count) frames" : "FAILED \(String(describing:w.error))"); sem.signal()}
sem.wait()
