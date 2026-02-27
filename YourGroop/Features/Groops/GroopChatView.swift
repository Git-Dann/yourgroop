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
    @State private var isAddMenuPresented = false

    init(groopId: UUID, repository: GroopRepository, prefillText: String? = nil) {
        self.prefillText = prefillText
        _viewModel = State(initialValue: GroopChatViewModel(groopId: groopId, repository: repository))
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView("Loading chat")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isFromCurrentUser { Spacer(minLength: 56) }

                                VStack(alignment: .leading, spacing: 4) {
                                    if !message.isFromCurrentUser {
                                        Text(message.senderName)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(message.body)
                                        .font(.body)
                                    Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.82) : .secondary)
                                }
                                .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: geo.size.width * 0.74, alignment: .leading)
                                .background(
                                    message.isFromCurrentUser
                                        ? AnyShapeStyle(Color(uiColor: .systemBlue))
                                        : AnyShapeStyle(.regularMaterial),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(
                                            message.isFromCurrentUser ? .clear : Color(uiColor: .separator).opacity(0.22),
                                            lineWidth: 1
                                        )
                                )
                                .id(message.id)

                                if !message.isFromCurrentUser { Spacer(minLength: 56) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background(
                    LinearGradient(
                        colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemGroupedBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 10) {
                            Button {
                                isAddMenuPresented = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color(uiColor: .systemBlue))
                                    .frame(width: 34, height: 34)
                                    .background(.regularMaterial, in: Circle())
                                    .overlay(
                                        Circle()
                                            .strokeBorder(Color(uiColor: .separator).opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open chat features")
                            .popover(isPresented: $isAddMenuPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                                chatFeaturesPopover
                                    .presentationCompactAdaptation(.popover)
                            }

                            TextField(
                                "",
                                text: $viewModel.draftMessage,
                                prompt: Text("iMessage").foregroundStyle(.secondary)
                            )
                            .lineLimit(1...4)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .foregroundStyle(.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color(uiColor: .separator).opacity(0.28), lineWidth: 1)
                            )

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
                                Image(systemName: "arrow.up")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Color(uiColor: .systemBlue), in: Circle())
                            }
                            .disabled(!viewModel.canSend)
                            .opacity(viewModel.canSend ? 1 : 0.45)
                            .accessibilityLabel("Send message")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .background(.bar)
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

    private var chatFeaturesPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow(icon: "chart.bar.doc.horizontal", title: "Poll")
            featureRow(icon: "calendar.badge.plus", title: "Event")
            featureRow(icon: "questionmark.bubble", title: "Question")
            featureRow(icon: "calendar", title: "Calendar")
        }
        .padding(12)
        .frame(width: 180, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}
