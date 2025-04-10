//
// ContentView.swift
//
// Created by Anonym on 08.04.25
//
 
import SwiftUI

struct ContentView: View {
    @StateObject private var apiSettings = APISettings()
    @StateObject private var viewModel: ChatViewModel
    @State private var showingSettings = false
    
    init() {
        let settings = APISettings()
        _apiSettings = StateObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: ChatViewModel(apiSettings: settings))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                        
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(16)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                
                HStack {
                    TextField("Message", text: $viewModel.inputMessage)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.blue)
                            .padding(10)
                    }
                    .disabled(viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("OpenAI Chat")
            .navigationBarItems(trailing:
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            )
            .sheet(isPresented: $showingSettings) {
                SettingsView(apiSettings: apiSettings)
            }
        }
    }
}
