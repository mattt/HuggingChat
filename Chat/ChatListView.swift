import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @Binding var selectedChat: Chat?

    let viewModel: ChatViewModel

    var body: some View {
        List(selection: $selectedChat) {
            ForEach(groupedChats.keys.sorted(by: >), id: \.self) { dateGroup in
                Section(header: Text(dateGroup.title)) {
                    ForEach(groupedChats[dateGroup] ?? []) { chat in
                        NavigationLink(value: chat) {
                            ChatRowView(chat: chat)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteChat(chat)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteChat(chat)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteChats(in: dateGroup, at: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let newChat = viewModel.createNewChat()
                    selectedChat = newChat
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
        }
    }

    private var groupedChats: [DateGroup: [Chat]] {
        Dictionary(grouping: chats) { chat in
            DateGroup.from(chat.updatedAt)
        }
    }

    private func deleteChats(in group: DateGroup, at offsets: IndexSet) {
        let chatsInGroup = groupedChats[group] ?? []
        for index in offsets {
            viewModel.deleteChat(chatsInGroup[index])
        }
    }
}

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(chat.messages.isEmpty ? .tertiary : .primary)

            if let lastMessage = chat.messages.last {
                Text(lastMessage.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

enum DateGroup: Hashable, Comparable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case older

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .older: return "Older"
        }
    }

    var order: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .thisWeek: return 2
        case .lastWeek: return 3
        case .thisMonth: return 4
        case .older: return 5
        }
    }

    static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
        lhs.order < rhs.order
    }

    static func from(_ date: Date) -> DateGroup {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
            date > weekAgo
        {
            return .thisWeek
        } else if let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now),
            date > twoWeeksAgo
        {
            return .lastWeek
        } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return .thisMonth
        } else {
            return .older
        }
    }
}
