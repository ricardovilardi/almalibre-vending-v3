// Mix the intro soundtrack: looping background music + timed sound effects, 25.0 s, 48 kHz stereo WAV.
// Usage: mix_soundtrack <raw_dir> <out.wav> [variant a|b] [bird file] [music RMS]
// The music is cut to 25 s and its first 2 s are cross-faded with what follows second 25, so the
// track loops with the video without a click. Effects that run past 25 s wrap to the start.
import AVFoundation

let args = CommandLine.arguments
let raw = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let variant = args.count > 3 ? args[3] : "a"
let bird = args.count > 4 ? args[4] : "sfx12b_bird_trim.wav"
let musicRMS = Float(args.count > 5 ? args[5] : "0.03")!
let SR = 48000.0, DUR = 25.0, N = Int(SR * DUR)

func load(_ name: String) -> [[Float]] {
    let file = name.contains(".") ? name : name + ".mp3"
    let f = try! AVAudioFile(forReading: raw.appendingPathComponent(file))
    let fmt = AVAudioFormat(standardFormatWithSampleRate: SR, channels: 2)!
    let conv = AVAudioConverter(from: f.processingFormat, to: fmt)!
    let inBuf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
    try! f.read(into: inBuf)
    let cap = AVAudioFrameCount(Double(f.length) * SR / f.processingFormat.sampleRate) + 4096
    let outBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap)!
    var done = false
    _ = conv.convert(to: outBuf, error: nil) { _, st in
        if done { st.pointee = .endOfStream; return nil }
        done = true; st.pointee = .haveData; return inBuf }
    let n = Int(outBuf.frameLength)
    return (0..<2).map { c in Array(UnsafeBufferPointer(start: outBuf.floatChannelData![c], count: n)) }
}
func peak(_ s: [[Float]]) -> Float { s.flatMap { $0 }.map(abs).max() ?? 1 }
func rms(_ s: [[Float]]) -> Float { let a = s.flatMap { $0 }; return sqrt(a.reduce(0) { $0 + $1 * $1 } / Float(max(a.count, 1))) }

var mix = [[Float]](repeating: [Float](repeating: 0, count: N), count: 2)

// ---- music: seamless 25 s loop, quiet bed ----
let m = load("music_a.mp3")
let X = Int(2.0 * SR)                      // cross-fade length
let mGain = musicRMS / max(rms(m), 1e-6)    // default RMS 0.03 ≈ -30 dBFS: a quiet bed under the effects
for c in 0..<2 { for i in 0..<N {
    var v = m[c][i]
    if i < X, N + i < m[c].count { let w = Float(i) / Float(X); v = v * w + m[c][N + i] * (1 - w) }
    mix[c][i] += v * mGain } }

// ---- sound effects: (file, start s, level relative to a -3 dBFS peak) ----
let cues: [(String, Double, Float)] = [
    ("sfx01\(variant)_hello",    0.35, 0.45),   // Almita waves hello
    ("sfx02\(variant)_steps",    3.95, 0.32),   // walks to the palm
    ("sfx03\(variant)_palm",     6.10, 0.50),   // shakes the palm, berries fall in the cup
    ("sfx04\(variant)_whoosh",   9.05, 0.42),   // cup flips
    ("sfx05\(variant)_swirl",   10.00, 0.50),   // soft-serve appears
    ("sfx02\(variant)_steps",   11.50, 0.30),   // short walk
    ("sfx06\(variant)_toppings",14.35, 0.45),   // toppings rain down
    ("sfx07\(variant)_ding",    16.85, 0.38),   // wink + thumbs up
    ("sfx08_single_clap.wav",   18.955, 0.60),  // one person clapping twice ("¡Listo!"): hands meet at frame 455…
    ("sfx08_single_clap.wav",   19.330, 0.52),  // …and frame 464; one clean clap cut from sfx08b
    (bird,                     20.25, 0.45),   // arms up: Amazon bird call
    ("sfx02\(variant)_steps",   21.70, 0.30),   // walks off
    ("sfx10\(variant)_swish",   22.95, 0.50),   // palm leaf sweeps the frame
]
for (name, start, level) in cues {
    let s = load(name); let g = level * 0.708 / max(peak(s), 1e-6)
    let fade = Int(0.03 * SR)
    for c in 0..<2 { for i in 0..<s[c].count {
        var v = s[c][i] * g
        if i > s[c].count - fade { v *= Float(s[c].count - i) / Float(fade) }   // no click at the tail
        let j = (Int(start * SR) + i) % N
        mix[c][j] += v } }
}

// ---- normalise: loudest peak at -1 dBFS (the machine's volume knob does the rest) ----
let p = peak(mix); let k = 0.89 / p; for c in 0..<2 { for i in 0..<N { mix[c][i] *= k } }

// AAC encoding trims a few ms, so the file carries 0.2 s extra (the start of the loop again);
// the mux trims it back to exactly the video length, and the loop stays continuous.
let EXTRA = Int(0.2 * SR), NT = N + EXTRA
for c in 0..<2 { mix[c] += mix[c][0..<EXTRA] }
let fmt = AVAudioFormat(standardFormatWithSampleRate: SR, channels: 2)!
let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(NT))!
buf.frameLength = AVAudioFrameCount(NT)
for c in 0..<2 { mix[c].withUnsafeBufferPointer { buf.floatChannelData![c].update(from: $0.baseAddress!, count: NT) } }
try? FileManager.default.removeItem(at: out)
let wav = try! AVAudioFile(forWriting: out, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: SR,
    AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false])
try! wav.write(from: buf)
wav.close()                                    // finalise the WAV header (a top-level file is never deinitialised)
print(String(format: "ok %@  peak %.2f dBFS  rms %.1f dBFS", out.lastPathComponent, 20 * log10(peak(mix)), 20 * log10(rms(mix))))
