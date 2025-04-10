//
// ChatViewModel.swift
//
// Created by Anonym on 08.04.25
//
 
import Foundation
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputMessage: String = ""
    @Published var isLoading: Bool = false
    
    private var apiSettings: APISettings
    
    init(apiSettings: APISettings) {
        self.apiSettings = apiSettings
        
        // Message de bienvenue
        self.messages.append(Message(
            content: "Bonjour ! Je suis votre assistant IA. Comment puis-je vous aider aujourd'hui ?",
            isUserMessage: false
        ))
    }
    
    func sendMessage() {
        guard !inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: inputMessage, isUserMessage: true)
        messages.append(userMessage)
        
        let messageText = inputMessage
        inputMessage = ""
        
        // Vérifier si l'API est configurée
        if apiSettings.isConfigured {
            isLoading = true
            fetchResponse(for: messageText)
        } else {
            messages.append(Message(
                content: "Veuillez configurer votre clé API OpenAI dans les paramètres pour utiliser cette fonctionnalité.",
                isUserMessage: false
            ))
        }
    }
    
    private func fetchResponse(for message: String) {
        // Préparer les messages pour l'API
        var apiMessages: [OpenAIMessage] = []
        
        // Ajouter tous les messages précédents pour le contexte
        for msg in messages {
            let role = msg.isUserMessage ? "user" : "assistant"
            apiMessages.append(OpenAIMessage(role: role, content: msg.content))
        }
        
        // Créer la requête
        let request = OpenAIRequest(model: apiSettings.model, messages: apiMessages)
        
        // Convertir en JSON
        guard let jsonData = try? JSONEncoder().encode(request) else {
            self.handleError("Erreur lors de l'encodage de la requête")
            return
        }
        
        // Préparer la requête HTTP
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            self.handleError("URL invalide")
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = jsonData
        
        // Exécuter la requête
        let task = URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.handleError("Erreur réseau: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.handleError("Réponse invalide")
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.handleError("Erreur serveur: \(httpResponse.statusCode)")
                    return
                }
                
                guard let data = data else {
                    self.handleError("Données manquantes")
                    return
                }
                
                do {
                    let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                    if let responseContent = apiResponse.choices.first?.message.content {
                        let assistantMessage = Message(content: responseContent, isUserMessage: false)
                        self.messages.append(assistantMessage)
                    } else {
                        self.handleError("Réponse vide")
                    }
                } catch {
                    self.handleError("Erreur de décodage: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    private func handleError(_ message: String) {
        self.messages.append(Message(
            content: "Erreur: \(message)",
            isUserMessage: false
        ))
    }
}
