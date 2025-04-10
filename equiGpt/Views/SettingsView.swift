//
// SettingsView.swift
//
// Created by Anonym on 08.04.25
//
 
import SwiftUI

struct SettingsView: View {
    @ObservedObject var apiSettings: APISettings
    @Environment(\.presentationMode) var presentationMode
    @State private var availableModels: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        Text("Configuration de l'API OpenAI")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        SecureField("Clé API", text: $apiSettings.apiKey)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                        
                        Toggle("Utiliser l'API Response", isOn: $apiSettings.useResponseAPI)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                        
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(8)
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal, 16)
                        } else {
                            Picker("Modèle", selection: $apiSettings.model) {
                                ForEach(availableModels, id: \.self) { model in
                                    Text(model)
                                        .font(.system(size: 16))
                                }
                            }
                            .pickerStyle(.navigationLink)
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Group {
                        Text("Fonctionnalités")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        Toggle("Synthèse vocale (TTS)", isOn: $apiSettings.ttsEnabled)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                        
                        if apiSettings.ttsEnabled {
                            Picker("Modèle TTS", selection: $apiSettings.ttsModel) {
                                Text("tts-1").tag("tts-1")
                                Text("tts-1-hd").tag("tts-1-hd")
                                Text("gpt-4o-mini-tts").tag("gpt-4o-mini-tts")
                            }
                            .pickerStyle(.navigationLink)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                            
                            Picker("Voix", selection: $apiSettings.ttsVoice) {
                                Text("alloy").tag("alloy")
                                Text("ash").tag("ash")
                                Text("ballad").tag("ballad")
                                Text("coral").tag("coral")
                                Text("echo").tag("echo")
                                Text("fable").tag("fable")
                                Text("onyx").tag("onyx")
                                Text("nova").tag("nova")
                                Text("sage").tag("sage")
                                Text("shimmer").tag("shimmer")
                                Text("verse").tag("verse")
                            }
                            .pickerStyle(.navigationLink)
                            .font(.system(size: 16))
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    Group {
                        Text("À propos")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        
                        Text("Cette application utilise l'API OpenAI pour générer des réponses. Vous devez fournir votre propre clé API pour utiliser cette application.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16))
                }
            }
            .onAppear {
                fetchModels()
            }
        }
    }
    
    private func fetchModels() {
        guard !apiSettings.apiKey.isEmpty else {
            errorMessage = "Veuillez entrer une clé API"
            isLoading = false
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Erreur: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "Aucune donnée reçue"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
                    availableModels = response.data.map { $0.id }.sorted()
                } catch {
                    errorMessage = "Erreur de décodage: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct ModelsResponse: Codable {
    let data: [Model]
}

struct Model: Codable {
    let id: String
}
