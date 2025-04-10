//
// MessageBubble.swift
//
// Created by Anonym on 08.04.25
//
 
import SwiftUI

struct MessageBubble: View {
    var message: Message
    
    var body: some View {
        HStack {
            if message.isUserMessage {
                Spacer()
                Text(message.content)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(message.content)
                    .padding(12)
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                    .transition(.scale.combined(with: .opacity))
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
