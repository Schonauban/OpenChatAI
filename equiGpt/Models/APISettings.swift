//
// APISettings.swift
//
// Created by Anonym on 08.04.25
//
 
import Foundation
import SwiftUI

class APISettings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "OpenAIAPIKey")
        }
    }
    
    @Published var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: "OpenAIModel")
        }
    }
    
    @Published var ttsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(ttsEnabled, forKey: "TTSEnabled")
        }
    }
    
    @Published var ttsModel: String {
        didSet {
            UserDefaults.standard.set(ttsModel, forKey: "TTSModel")
        }
    }
    
    @Published var ttsVoice: String {
        didSet {
            UserDefaults.standard.set(ttsVoice, forKey: "TTSVoice")
        }
    }
    
    @Published var useResponseAPI: Bool {
        didSet {
            UserDefaults.standard.set(useResponseAPI, forKey: "UseResponseAPI")
        }
    }
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? "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"
        self.model = UserDefaults.standard.string(forKey: "OpenAIModel") ?? "gpt-3.5-turbo"
        self.ttsEnabled = UserDefaults.standard.bool(forKey: "TTSEnabled") || true
        self.ttsModel = UserDefaults.standard.string(forKey: "TTSModel") ?? "tts-1"
        self.ttsVoice = UserDefaults.standard.string(forKey: "TTSVoice") ?? "alloy"
        self.useResponseAPI = UserDefaults.standard.bool(forKey: "UseResponseAPI")
    }
    
    var isConfigured: Bool {
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
