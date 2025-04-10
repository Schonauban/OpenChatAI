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
                    .textSelection(.enabled)
            } else {
                Text(message.content)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(16)
                    .textSelection(.enabled)
                Spacer()
            }
        }
    }
}
