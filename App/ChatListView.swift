import SwiftUI
import SwiftData

struct ChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @Binding var selectedItem: ChatSelection?

    let viewModel: ChatViewModel

    var body: some View {
        List(selection: $selectedItem) {
            // Persistent "New Chat" item
            NavigationLink(value: ChatSelection.newChat) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.secondary)
                    Text("New Chat")
                        .font(.body)
                }
                .padding(.vertical, 4)
            }

            // Only show chats that have messages
            let nonEmptyChats = chats.filter { !$0.messages.isEmpty }

            ForEach(groupedChats(from: nonEmptyChats).keys.sorted(), id: \.self) { dateGroup in
                Section(header: Text(dateGroup.title)) {
                    ForEach(groupedChats(from: nonEmptyChats)[dateGroup] ?? []) { chat in
                        NavigationLink(value: ChatSelection.existing(chat)) {
                            ChatRowView(chat: chat)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteChat(chat)
                                if case .existing(let selectedChat) = selectedItem, selectedChat == chat {
                                    selectedItem = .newChat
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteChat(chat)
                                if case .existing(let selectedChat) = selectedItem, selectedChat == chat {
                                    selectedItem = .newChat
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteChats(from: nonEmptyChats, in: dateGroup, at: indexSet)
                    }
                }
            }
        }
        .navigationTitle("Chats")
    }

    private func groupedChats(from chatList: [Chat]) -> [DateGroup: [Chat]] {
        Dictionary(grouping: chatList) { chat in
            DateGroup.from(chat.updatedAt)
        }
    }

    private func deleteChats(from chatList: [Chat], in group: DateGroup, at offsets: IndexSet) {
        let chatsInGroup = groupedChats(from: chatList)[group] ?? []
        for index in offsets {
            let chat = chatsInGroup[index]
            viewModel.deleteChat(chat)
            if case .existing(let selectedChat) = selectedItem, selectedChat == chat {
                selectedItem = .newChat
            }
        }
    }
}

private struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        Text(chat.title ?? "New Chat")
            .font(.body)
            .lineLimit(1)
            .foregroundStyle(chat.title == nil ? .tertiary : .primary)
            .padding(.vertical, 4)
            .help(chat.title ?? "New Chat")
    }
}

private enum DateGroup: Hashable, Comparable {
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
