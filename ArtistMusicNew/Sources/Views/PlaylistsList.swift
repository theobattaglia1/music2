//
//  PlaylistsList.swift
//  ArtistMusic
//

import SwiftUI
import UniformTypeIdentifiers

/// Live list of playlists that automatically refreshes
/// whenever `ArtistStore.artists` changes.
struct PlaylistsList: View {

    // live store
    @EnvironmentObject private var store: ArtistStore
    @State           private var editMode: EditMode = .active

    // input
    let artistID: UUID
    private let type = UTType.plainText   // drag-and-drop

    // computed every render – always up-to-date
    private var artist: Artist? {
        store.artists.first { $0.id == artistID }
    }

    // MARK: body
    var body: some View {
        if let artist {
            List {
                ForEach(artist.playlists) { list in
                    HStack {
                        Text(list.name)
                        Spacer()
                        Text("\(list.songIDs.count) tracks")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .onDrop(of: [type],
                            isTargeted: nil,
                            perform: drop(into: list))
                }
                .onMove { src, dst in
                    store.movePlaylists(of: artistID,
                                        from: src,
                                        to: dst)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .frame(maxHeight: .infinity)
        } else {
            EmptyState(icon: "exclamationmark.circle",
                       title: "Artist missing",
                       message: "The referenced artist no longer exists.")
        }
    }

    // accept dragged-in song IDs
    private func drop(into list: Playlist)
         -> ([NSItemProvider]) -> Bool {

        { providers in
            guard let first = providers.first else { return false }

            _ = first.loadObject(ofClass: NSString.self) { item, _ in
                guard let s = item as? String,
                      let uuid = UUID(uuidString: s)
                else { return }

                DispatchQueue.main.async {
                    store.add(songID: uuid,
                              to: list.id,
                              for: artistID)
                }
            }
            return true
        }
    }
}
