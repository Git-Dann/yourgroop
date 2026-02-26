import SwiftUI
import Observation

@MainActor
@Observable
final class GroopChatViewModel {
    private let repository: GroopRepository
    let groopId: UUID

    var messages: [GroopMessage] = []
    var draftMessage = ""
    var isLoading = false

    init(groopId: UUID, repository: GroopRepository) {
        self.groopId = groopId
        self.repository = repository
    }

    var canSend: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        messages = await repository.fetchMessages(for: groopId)
    }

    func send() async {
        let trimmed = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        _ = await repository.sendMessage(groopId: groopId, body: trimmed, senderName: "Taylor", isFromCurrentUser: true)
        draftMessage = ""
        messages = await repository.fetchMessages(for: groopId)
    }
}

struct GroopChatView: View {
    @State private var viewModel: GroopChatViewModel
    let prefillText: String?

    init(groopId: UUID, repository: GroopRepository, prefillText: String? = nil) {
        self.prefillText = prefillText
        _viewModel = State(initialValue: GroopChatViewModel(groopId: groopId, repository: repository))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView("Loading chat")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.isFromCurrentUser { Spacer(minLength: 48) }

                            VStack(alignment: .leading, spacing: 4) {
                                if !message.isFromCurrentUser {
                                    Text(message.senderName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text(message.body)
                                    .font(.body)
                                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                message.isFromCurrentUser ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .id(message.id)

                            if !message.isFromCurrentUser { Spacer(minLength: 48) }
                        }
                    }
                }
                .padding()
            }
            .background(.thinMaterial)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    TextField("Message this groop", text: $viewModel.draftMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    Button {
                        Task {
                            await viewModel.send()
                            if let last = viewModel.messages.last {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                    }
                    .disabled(!viewModel.canSend)
                    .accessibilityLabel("Send message")
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Groop Chat")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.load()
                if viewModel.draftMessage.isEmpty, let prefillText {
                    viewModel.draftMessage = prefillText
                }
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
