//
// ChatViewModel.swift
//
// Created by Anonym on 08.04.25
//
 
import Foundation
import SwiftUI
import AVFoundation

@MainActor
class ChatViewModel: NSObject, ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var audioService: AudioService
    @Published var streamingMessage: String = ""
    @Published var conversationTitle: String = "New Conversation"
    
    private let apiSettings: APISettings
    private let openAIService: OpenAIService
    private let conversationTitleService: ConversationTitleService
    
    var isRecording: Bool {
        audioService.isRecording
    }
    
    var isPlayingTTS: Bool {
        audioService.isPlaying
    }
    
    init(apiSettings: APISettings) {
        self.apiSettings = apiSettings
        self.openAIService = OpenAIService(apiKey: apiSettings.apiKey)
        self.audioService = AudioService()
        self.conversationTitleService = ConversationTitleService(openAIService: openAIService)
        super.init()
        
       
    }
    
    func startRecording() {
        do {
            try audioService.startRecording()
        } catch {
            errorMessage = ErrorHandler.handle(error)
        }
    }
    
    func stopRecording() {
        guard let audioFileURL = audioService.stopRecording() else { return }
        
        Task {
            do {
                let transcribedText = try await openAIService.transcribeAudio(fileURL: audioFileURL)
                inputMessage = transcribedText
                sendMessage()
            } catch {
                errorMessage = ErrorHandler.handle(error)
            }
        }
    }
    
    func resetConversation() {
        messages.removeAll()
        inputMessage = ""
        errorMessage = nil
        conversationTitle = "New Conversation"
        
        // Add welcome message
        
    }
    
    private func updateConversationTitle() async {
        guard messages.count > 1 else { return } // Don't generate title for just the welcome message
        
        do {
            let title = try await conversationTitleService.generateTitle(for: messages)
            await MainActor.run {
                conversationTitle = title
            }
        } catch {
            print("Failed to generate conversation title: \(error)")
        }
    }
    
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: inputMessage, isUserMessage: true)
        messages.append(userMessage)
        
        let messageText = inputMessage
        inputMessage = ""
        
        Task {
            await fetchResponse(for: messageText)
            await updateConversationTitle()
        }
    }
    
    private func fetchResponse(for message: String) async {
        guard apiSettings.isConfigured else {
            messages.append(Message(
                content: "Veuillez configurer votre clé API OpenAI dans les paramètres pour utiliser cette fonctionnalité.",
                isUserMessage: false
            ))
            return
        }
        
        isLoading = true
        errorMessage = nil
        streamingMessage = ""
        
        do {
            if apiSettings.useResponseAPI {
                let placeholderMessage = Message(content: "", isUserMessage: false)
                messages.append(placeholderMessage)
                
                let (response, annotations) = try await openAIService.sendResponseAPI(
                    input: message,
                    model: apiSettings.model,
                    onDelta: { [weak self] delta in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.streamingMessage += delta
                            //show delta in console
                            print("Delta: \(delta)")
                            if let lastIndex = self.messages.indices.last {
                                self.messages[lastIndex].content = self.streamingMessage
                            }
                        }
                    }
                    
                )
                
                if let lastIndex = messages.indices.last {
                    messages[lastIndex].content = response
                }
                
                if apiSettings.ttsEnabled {
                    try await generateTTS(for: response)
                }
            } else {
                var apiMessages: [OpenAIMessage] = []
                for msg in messages {
                    let role = msg.isUserMessage ? "user" : "assistant"
                    apiMessages.append(OpenAIMessage(role: role, content: msg.content))
                }
                
                let response = try await openAIService.sendChatCompletion(
                    messages: apiMessages,
                    model: apiSettings.model
                )
                
                let assistantMessage = Message(content: response, isUserMessage: false)
                messages.append(assistantMessage)
                
                if apiSettings.ttsEnabled {
                    try await generateTTS(for: response)
                }
            }
        } catch {
            errorMessage = ErrorHandler.handle(error)
        }
        
        isLoading = false
    }
    
    private func generateTTS(for text: String) async throws {
        let audioData = try await openAIService.generateSpeech(
            text: text,
            model: apiSettings.ttsModel,
            voice: apiSettings.ttsVoice
        )
        
        try audioService.playAudio(data: audioData)
    }
}

// Add these structures at the end of the file
struct TTSRequest: Codable {
    let model: String
    let input: String
    let voice: String
}

struct TranscriptionResponse: Codable {
    let text: String
}

struct ResponseAPIRequest: Codable {
    let model: String
    let input: String
    let tools: [Tool]
    let stream: Bool
    
    struct Tool: Codable {
        let type: String
    }
}

struct ResponseAPIResponse: Codable {
    let output: [Output]
    
    struct Output: Codable {
        let type: String
        let content: [Content]?
        
        struct Content: Codable {
            let type: String
            let text: String
            let annotations: [Annotation]?
            
            struct Annotation: Codable {
                let type: String
                let start_index: Int
                let end_index: Int
                let url: String
                let title: String?
            }
        }
    }
}

class StreamingResponseHandler: NSObject, URLSessionDataDelegate {
    private var currentMessage = ""
    private var currentAnnotations: [ResponseAPIResponse.Output.Content.Annotation] = []
    private var onDelta: (String) -> Void
    private var onComplete: (String, [ResponseAPIResponse.Output.Content.Annotation]) -> Void
    private var onError: (Error) -> Void
    private var buffer = ""
    
    init(
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping (String, [ResponseAPIResponse.Output.Content.Annotation]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onDelta = onDelta
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let string = String(data: data, encoding: .utf8) else {
            onError(OpenAIServiceError.invalidResponse)
            return
        }
        
        buffer += string
        
        // Process complete events
        let events = buffer.components(separatedBy: "\n\n")
        buffer = events.last ?? "" // Keep the last potentially incomplete event
        
        for event in events.dropLast() {
            guard !event.isEmpty else { continue }
            
            // Split event into type and data
            let parts = event.components(separatedBy: "\n")
            guard parts.count == 2 else { continue }
            
            let eventType = parts[0].replacingOccurrences(of: "event: ", with: "")
            let eventData = parts[1].replacingOccurrences(of: "data: ", with: "")
            
            guard let jsonData = eventData.data(using: .utf8) else {
                continue
            }
            
            do {
                switch eventType {
                case "response.output_text.delta":
                    if let delta = try? JSONDecoder().decode(OutputTextDelta.self, from: jsonData) {
                        currentMessage += delta.delta
                        onDelta(delta.delta)
                    }
                    
                case "response.output_text.done":
                    if let done = try? JSONDecoder().decode(OutputTextDone.self, from: jsonData) {
                        currentMessage = done.text
                        currentAnnotations = done.annotations ?? []
                        onComplete(done.text, done.annotations ?? [])
                    }
                    
                default:
                    print("Unhandled event type: \(eventType)")
                }
            } catch {
                print("Error decoding event: \(error)")
                // Don't propagate the error for individual events, just log it
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("Task completed with error: \(error)")
            onError(OpenAIServiceError.networkError(error))
        } else {
            print("Task completed successfully")
        }
    }
}

struct OutputTextDelta: Codable {
    let type: String
    let item_id: String
    let output_index: Int
    let content_index: Int
    let delta: String
}

struct OutputTextDone: Codable {
    let type: String
    let item_id: String
    let output_index: Int
    let content_index: Int
    let text: String
    let annotations: [ResponseAPIResponse.Output.Content.Annotation]?
}
