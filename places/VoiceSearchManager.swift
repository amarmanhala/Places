//
//  VoiceSearchManager.swift
//  places
//
//  Speech-to-Text Voice Search using Apple's Speech Framework
//

import Foundation
import Speech
import AVFoundation
import Combine

class VoiceSearchManager: ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
            }
        }
    }

    // MARK: - Voice Recognition

    func startListening(completion: @escaping (String) -> Void) {
        // Check if already listening
        guard !isListening else {
            stopListening()
            return
        }

        // Check authorization
        guard authorizationStatus == .authorized else {
            print("❌ Speech recognition not authorized")
            requestAuthorization()
            return
        }

        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            return
        }

        // Cancel any ongoing task
        if let task = recognitionTask {
            task.cancel()
            recognitionTask = nil
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session setup failed: \(error)")
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ Unable to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input node
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = transcription
                    completion(transcription)
                }
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                DispatchQueue.main.async {
                    self.isListening = false
                }
            }
        }

        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
                self.transcribedText = ""
            }
            print("🎤 Voice recognition started")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()

            // Remove tap on the input node
            audioEngine.inputNode.removeTap(onBus: 0)

            isListening = false
            print("🛑 Voice recognition stopped")
        }
    }

    func toggleListening(completion: @escaping (String) -> Void) {
        if isListening {
            stopListening()
        } else {
            startListening(completion: completion)
        }
    }
}
