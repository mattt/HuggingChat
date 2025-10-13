import SwiftData
import SwiftUI

struct MessageComposerView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Binding var text: String
    @State private var selection: TextSelection?
    let isGenerating: Bool
    @Binding var model: Model
    var chat: Chat?
    let modelContext: ModelContext
    var viewModel: ChatViewModel?
    let onSend: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField("Send a message", text: $text, selection: $selection, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(1 ... 10)
                .frame(minWidth: 300)
                .disabled(isGenerating)
                .focused($isFocused)
                .onAppear {
                    isFocused = true
                }
                .onKeyPress { press in
                    if press.key == .return {
                        if press.modifiers.isEmpty {
                            if !isGenerating && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSend()
                                return .handled
                            }
                        } else if press.modifiers == [.shift] {
                            insertNewlineAtCursor()
                            return .handled
                        }
                    }
                    return .ignored
                }
                .glassEffectTransition(.materialize)

            HStack(spacing: 8) {
                Spacer()

                Menu {
                    Button {
                        if let chat {
                            chat.updateModel(.system)
                            try? modelContext.save()
                        } else {
                            model = .system
                        }
                    } label: {
                        Image(systemName: "apple.logo")
                        Text("Apple Intelligence")
                        Text("System Foundation Model")
                        if model == .system {
                            Image(systemName: "checkmark")
                        }
                    }

                    if authManager.isAuthenticated {
                        Divider()

                        Text("HuggingFace Inference")

                        ForEach(huggingFaceModels, id: \.id) { model in
                            Button {
                                if let chat {
                                    chat.updateModel(.huggingFace(model.id))
                                    try? modelContext.save()
                                } else {
                                    self.model = .huggingFace(model.id)
                                }
                            } label: {
                                Image(systemName: "bolt.fill")
                                Text(model.name)
                                Text(model.id)
                                let isSelected =
                                    if case .huggingFace(let selectedId) = self.model {
                                        selectedId == model.id
                                    } else {
                                        false
                                    }
                                if isSelected {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(model.shortName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    if isGenerating, let viewModel {
                        viewModel.stopGenerating()
                    } else {
                        onSend()
                    }
                } label: {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(
                    !isGenerating && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding()
    }

    private var huggingFaceModels: [(id: String, name: String)] {
        [
            (id: "meta-llama/Llama-3.3-70B-Instruct", name: "Llama 3.3 70B"),
            (id: "meta-llama/Llama-3.1-8B-Instruct", name: "Llama 3.1 8B"),
            (id: "Qwen/Qwen2.5-72B-Instruct", name: "Qwen 2.5 72B"),
            (id: "mistralai/Mistral-7B-Instruct-v0.3", name: "Mistral 7B"),
            (id: "google/gemma-2-9b-it", name: "Gemma 2 9B"),
        ]
    }
    
    private func insertNewlineAtCursor() {
        let selection = selection ?? TextSelection(insertionPoint: text.endIndex)
        if case let .selection(range) = selection.indices {
            self.selection = nil
            text.replaceSubrange(range, with: "\n")
            if let index = text.index(range.lowerBound, offsetBy: 1, limitedBy: text.endIndex) {
                self.selection = TextSelection(insertionPoint: index)
            }
        }
    }
}
