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
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "OpenAIAPIKey") ?? ""
        self.model = UserDefaults.standard.string(forKey: "OpenAIModel") ?? "gpt-3.5-turbo"
    }
    
    var isConfigured: Bool {
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
