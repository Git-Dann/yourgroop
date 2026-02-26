import SwiftUI

struct CreateAnnouncementView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""

    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Announcement") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Body", text: $bodyText, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("New Announcement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines), bodyText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Post announcement")
                }
            }
        }
    }
}
