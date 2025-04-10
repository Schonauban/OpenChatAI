import Foundation

struct Conversation: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let messages: [Message]
    let timestamp: Date
    
    init(id: UUID = UUID(), title: String, messages: [Message], timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.timestamp = timestamp
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
}

class ConversationHistory: ObservableObject {
    @Published var conversations: [Conversation] = []
    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "savedConversations"
    
    init() {
        loadConversations()
    }
    
    func addConversation(_ conversation: Conversation) {
        conversations.insert(conversation, at: 0)
        saveConversations()
    }
    
    func removeConversation(at indexSet: IndexSet) {
        conversations.remove(atOffsets: indexSet)
        saveConversations()
    }
    
    private func saveConversations() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
        }
    }
    
    private func loadConversations() {
        if let data = userDefaults.data(forKey: conversationsKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }
    }
} 