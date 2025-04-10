//
// ContentView.swift
//
// Created by Anonym on 08.04.25
//

import SwiftUI

struct ContentView: View {
    @StateObject private var apiSettings = APISettings()
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var history = ConversationHistory()
    @ObservedObject private var audioService: AudioService
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedConversation: Conversation?
    
    init() {
        let settings = APISettings()
        _apiSettings = StateObject(wrappedValue: settings)
        let viewModel = ChatViewModel(apiSettings: settings)
        _viewModel = StateObject(wrappedValue: viewModel)
        _audioService = ObservedObject(wrappedValue: viewModel.audioService)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.5)
                                        Spacer()
                                    }
                                    .id("loading")
                                }
                                
                                if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption2)
                                        .id("error")
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                        .onAppear {
                            scrollProxy = proxy
                            scrollToBottom()
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            scrollToBottom()
                        }
                        .onChange(of: viewModel.isLoading) { _ in
                            scrollToBottom()
                        }
                        .onChange(of: viewModel.errorMessage) { _ in
                            scrollToBottom()
                        }
                    }
                    .frame(maxHeight: .infinity)
                    
                    Divider()
                        .padding(.vertical, 1)
                    
                    HStack(spacing: 4) {
                        TextField("Type a message...", text: $viewModel.inputMessage)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .padding(.horizontal, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                            .onSubmit {
                                if !viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    WKInterfaceDevice.current().play(.click)
                                    viewModel.sendMessage()
                                }
                            }
                        
                        if !viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                WKInterfaceDevice.current().play(.click)
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                            WKInterfaceDevice.current().play(.click)
                            if audioService.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            Image(systemName: audioService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(audioService.isRecording ? .red : .blue)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if audioService.isPlaying {
                            Button(action: {
                                WKInterfaceDevice.current().play(.click)
                                audioService.stopPlayback()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if audioService.isRecording {
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.blue.opacity(0.3))
                                    .frame(width: geometry.size.width * CGFloat(audioService.volumeLevel))
                                    .animation(.easeInOut(duration: 0.1), value: audioService.volumeLevel)
                            }
                            .frame(height: 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(2)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            .navigationTitle(viewModel.conversationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        saveCurrentConversation()
                        viewModel.resetConversation()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { 
                        WKInterfaceDevice.current().play(.click)
                        showingSettings = true 
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 14))
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        showingHistory = true
                    }) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(apiSettings: apiSettings)
            }
            .sheet(isPresented: $showingHistory) {
                ConversationHistoryView(history: history, selectedConversation: $selectedConversation)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: selectedConversation) { newConversation in
            if let conversation = newConversation {
                viewModel.messages = conversation.messages
                viewModel.conversationTitle = conversation.title
            }
        }
    }
    
    private func scrollToBottom() {
        withAnimation {
            if let lastMessage = viewModel.messages.last {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            } else if viewModel.isLoading {
                scrollProxy?.scrollTo("loading", anchor: .bottom)
            } else if viewModel.errorMessage != nil {
                scrollProxy?.scrollTo("error", anchor: .bottom)
            }
        }
    }
    
    private func saveCurrentConversation() {
        if !viewModel.messages.isEmpty {
            let conversation = Conversation(
                title: viewModel.conversationTitle,
                messages: viewModel.messages
            )
            history.addConversation(conversation)
        }
    }
}
