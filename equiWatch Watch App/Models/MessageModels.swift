//
// MessageModels.swift
//
// Created by Anonym on 08.04.25
//
 
import Foundation

struct Message: Identifiable, Codable {
    var id: UUID
    var content: String
    var isUserMessage: Bool
    var timestamp: Date
    
    init(id: UUID = UUID(), content: String, isUserMessage: Bool, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.isUserMessage = isUserMessage
        self.timestamp = timestamp
    }
}

// Structures pour l'API OpenAI
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Float
    
    init(model: String, messages: [OpenAIMessage], temperature: Float = 0.7) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIMessage
    let finish_reason: String
}
