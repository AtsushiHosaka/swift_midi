import SwiftUI
import AudioToolbox
import CoreMIDI
import Foundation
import AVFoundation

// MARK: - Chord Structure
struct Chord {
    let name: String
    let midiNotes: [UInt8]
    
    init(name: String) {
        self.name = name
        self.midiNotes = Chord.notes(for: name)
    }
    
    static func notes(for chordName: String) -> [UInt8] {
        let chordMap: [String: [UInt8]] = [
            "C": [60, 64, 67],
            "Cmaj": [60, 64, 67],
            "D": [62, 66, 69],
            "Dmaj": [62, 66, 69],
            "Emin": [64, 67, 71],
            "F": [65, 69, 72],
            "Fmaj": [65, 69, 72],
            "G": [67, 71, 74],
            "Gmaj": [67, 71, 74],
            "Amin": [69, 72, 76],
            "Bdim": [71, 74, 77]
            // Add more chords as needed
        ]
        
        return chordMap[chordName] ?? [60, 64, 67]
    }
}



class MIDIPlayer: ObservableObject {
    var musicSequence: MusicSequence?
    var musicPlayer: MusicPlayer?
    
    init() {
        // MIDI シーケンスを初期化
        NewMusicSequence(&musicSequence)
        NewMusicPlayer(&musicPlayer)
        if let sequence = musicSequence, let player = musicPlayer {
            MusicPlayerSetSequence(player, sequence)
        }
    }
    
    func play(chords: [Chord], tempo: Double) {
        guard let sequence = musicSequence else { return }
        
        // 既存のシーケンスを破棄して新しいシーケンスを作成
        DisposeMusicSequence(sequence)
        NewMusicSequence(&musicSequence)
        guard let newSequence = musicSequence else { return }
        
        // トラックを作成
        var track: MusicTrack?
        MusicSequenceNewTrack(newSequence, &track)
        guard let midiTrack = track else { return }
        
        // テンポトラックを取得してテンポを設定
        var tempoTrack: MusicTrack?
        MusicSequenceGetTempoTrack(newSequence, &tempoTrack)
        guard let validTempoTrack = tempoTrack else { return }
        
        // テンポイベントを追加 (BPM)
        let tempoEventTime: MusicTimeStamp = 0
        let tempoValue: Float64 = 60.0 / tempo // BPMをテンポ値に変換
        MusicTrackNewExtendedTempoEvent(validTempoTrack, tempoEventTime, tempoValue)
        
        // コードをトラックに追加
        var time: MusicTimeStamp = 0
        let beatsPerChord: Double = 1 / tempo // 各コードの再生時間（1ビート）
        
        print(beatsPerChord)
        
        for chord in chords {
            for note in chord.midiNotes {
                var midiNoteMessage = MIDINoteMessage(
                    channel: 0,           // チャンネル番号
                    note: note,           // ノート番号 (0-127)
                    velocity: 64,         // 音の強さ
                    releaseVelocity: 0,   // リリースの強さ
                    duration: Float32(beatsPerChord) // 持続時間
                )
                MusicTrackNewMIDINoteEvent(midiTrack, time, &midiNoteMessage)
            }
            time += beatsPerChord
        }
        
        // プレーヤーを初期化して再生
        NewMusicPlayer(&musicPlayer)
        guard let player = musicPlayer else { return }
        MusicPlayerSetSequence(player, newSequence)
        MusicPlayerPreroll(player)
        MusicPlayerStart(player)
    }
    
    func stop() {
        guard let player = musicPlayer else { return }
        MusicPlayerStop(player)
    }
}

// MARK: - SwiftUI View
struct ContentView: View {
    @State private var chords: [Chord] = [
        Chord(name: "C"),
        Chord(name: "Emin"),
        Chord(name: "F"),
        Chord(name: "G")
    ]
    @State private var tempo: Double = 120.0
    @State private var isPlaying: Bool = false
    @StateObject private var midiPlayer = MIDIPlayer()
    
    var body: some View {
        VStack(spacing: 30) {
            Text("MIDI Chord Player")
                .font(.largeTitle)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Chords:")
                    .font(.headline)
                ForEach(chords, id: \.name) { chord in
                    Text(chord.name)
                        .font(.body)
                }
            }
            .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Tempo: \(Int(tempo)) BPM")
                    .font(.headline)
                Slider(value: $tempo, in: 60...200, step: 1)
                    .padding()
            }
            
            Button(action: {
                if isPlaying {
                    midiPlayer.stop()
                } else {
                    midiPlayer.play(chords: chords, tempo: tempo)
                }
                isPlaying.toggle()
            }) {
                Text(isPlaying ? "Stop" : "Play")
                    .font(.title)
                    .frame(width: 200, height: 60)
                    .background(isPlaying ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
}
