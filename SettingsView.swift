//
// SettingsView.swift
//
// Created by Anonym on 08.04.25
//
 
import SwiftUI

struct SettingsView: View {
    @ObservedObject var apiSettings: APISettings
    @Environment(\.presentationMode) var presentationMode
    
    let availableModels = ["gpt-3.5-turbo", "gpt-4", "gpt-4-turbo"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configuration de l'API OpenAI")) {
                    SecureField("Clé API", text: $apiSettings.apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Picker("Modèle", selection: $apiSettings.model) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model)
                        }
                    }
                }
                
                Section(header: Text("À propos")) {
                    Text("Cette application utilise l'API OpenAI pour générer des réponses. Vous devez fournir votre propre clé API pour utiliser cette application.")
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarItems(trailing: Button("Fermer") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
