import SwiftUI

struct ConversationHistoryView: View {
    @ObservedObject var history: ConversationHistory
    @Binding var selectedConversation: Conversation?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(history.conversations) { conversation in
                Button(action: {
                    selectedConversation = conversation
                    dismiss()
                }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title)
                            .font(.headline)
                        Text(conversation.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDelete { indexSet in
                history.removeConversation(at: indexSet)
            }
        }
        .navigationTitle("History")
    }
} 