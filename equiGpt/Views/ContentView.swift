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
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if viewModel.isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Spacer()
                                    }
                                    .id("loading")
                                }
                                
                                if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                        .id("error")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
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
                        .padding(.vertical, 8)
                    
                    HStack(spacing: 12) {
                        TextField("Type a message...", text: $viewModel.inputMessage)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .onSubmit {
                                if !viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    viewModel.sendMessage()
                                }
                            }
                        
                        if !viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: {
                                viewModel.sendMessage()
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                            if audioService.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            Image(systemName: audioService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(audioService.isRecording ? .red : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if audioService.isPlaying {
                            Button(action: {
                                audioService.stopPlayback()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if audioService.isRecording {
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.blue.opacity(0.5))
                                    .frame(width: geometry.size.width * CGFloat(audioService.volumeLevel))
                                    .animation(.easeInOut(duration: 0.1), value: audioService.volumeLevel)
                            }
                            .frame(height: 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(viewModel.conversationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        saveCurrentConversation()
                        viewModel.resetConversation()
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        showingSettings = true 
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingHistory = true
                    }) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
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
        .navigationViewStyle(.stack)
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
