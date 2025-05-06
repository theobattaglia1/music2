//
//  EmptyState.swift
//  ArtistMusic
//
//  Created by Theo Battaglia on 5/5/25.
//


//
//  UIHelpers.swift
//  ArtistMusic
//
//  Small, reusable UI helpers shared across screens.
//

import SwiftUI

// ────────────────────────────────────────────────────────────
// MARK: Empty-state placeholder
// ────────────────────────────────────────────────────────────
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(title).font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }
}

// ────────────────────────────────────────────────────────────
// MARK: Reusable “rename” sheet modifier (optional)
// ────────────────────────────────────────────────────────────
extension View {
    /// Presents a simple text-field sheet that calls `onSave`
    /// with the trimmed string when the user taps **Save**.
    func renameSheet(
        name: Binding<String>,
        isPresented: Binding<Bool>,
        onSave: @escaping (String) -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                Form { TextField("Name", text: name) }
                    .navigationTitle("Rename")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isPresented.wrappedValue = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                onSave(name.wrappedValue.trimmingCharacters(in: .whitespaces))
                                isPresented.wrappedValue = false
                            }
                            .disabled(name.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
            }
        }
    }
}
