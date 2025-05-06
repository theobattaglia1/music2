import SwiftUI
import UniformTypeIdentifiers          // UTType.plainText for drag payloads

// ────────────────────────────────────────────────────────────
// MARK: – Artist page
// ────────────────────────────────────────────────────────────
struct ArtistDetailView: View {

    // Store + nav
    @EnvironmentObject private var store: ArtistStore
    @Environment(\.dismiss)       private var dismiss

    // UI state
    @State private var tab: Tab = .allSongs
    @State private var showEditArtist  = false
    @State private var showAddSong     = false
    @State private var showAddPlaylist = false
    @State private var songArtPicker  : UUID?
    @State private var collaboratorSheet: String?

    // Input
    let artistID: UUID
    private var artist: Artist? { store.artists.first { $0.id == artistID } }

    enum Tab: String, CaseIterable, Identifiable {
        case allSongs, playlists, collaborators
        var id: Self { self }
        var title: String { rawValue.capitalized }
    }

    // MARK: body -----------------------------------------------------------
    var body: some View {
        if let artist { content(for: artist) } else { missing }
    }

    // MARK: main content ---------------------------------------------------
    private func content(for artist: Artist) -> some View {

        VStack(spacing: 0) {

            Header(artist: artist) { showEditArtist = true }

            Picker("Tab", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch tab {

            case .allSongs:
                SongsList(artistID: artist.id,
                          onArtTap: { songArtPicker = $0 })

            case .playlists, .collaborators:
                ScrollView {
                    VStack(spacing: 0) {
                        if tab == .playlists {
                            PlaylistsList(artistID: artistID)
                                .id(artist.playlists)   
                        } else {
                            CollaboratorsList(artist: artist,
                                              onTap: { collaboratorSheet = $0 })
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { floatingPlus }

        // sheets ───────────────────────────────────────────────────────────
        .sheet(isPresented: $showAddSong) {
            AddSongSheet(artistID: artistID)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddPlaylist) {
            AddPlaylistSheet(artistID: artistID)
                .environmentObject(store)
        }
        .sheet(item: $songArtPicker) { id in
            ImagePicker(data: Binding(
                get: { artist.songs.first { $0.id == id }?.artworkData },
                set: { store.setArtwork($0, for: id, artistID: artistID) }))
        }
        .sheet(item: $collaboratorSheet) { name in
            CollaboratorDetailView(name: name)
                .environmentObject(store)
        }
        .sheet(isPresented: $showEditArtist) {
            EditArtistSheet(artist: artist)
                .environmentObject(store)
        }
    }

    // floating “＋”
    private var floatingPlus: some View {
        HStack {
            Spacer()
            Button {
                tab == .playlists ? (showAddPlaylist = true)
                                  : (showAddSong     = true)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .padding(22)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(radius: 6)
            }
            .padding(.trailing, 28)
            .padding(.bottom, 220)          // clear Now-Playing bar
        }
    }

    // fallback
    private var missing: some View {
        VStack {
            Spacer()
            Text("Artist not found").foregroundColor(.secondary)
            Spacer()
        }
        .onAppear { dismiss() }
    }
}

// ────────────────────────────────────────────────────────────
// MARK: Header
// ────────────────────────────────────────────────────────────
private struct Header: View {
    let artist: Artist
    let onEdit: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            banner.resizable()
                  .scaledToFill()
                  .frame(height: 260)
                  .clipped()

            HStack(spacing: 12) {

                // ↓↓↓ add the sizing & circle clip back ↓↓↓
                avatar.resizable()
                      .scaledToFill()
                      .frame(width: 72, height: 72)
                      .clipShape(Circle())
                      .shadow(radius: 4)

                Text(artist.name)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .shadow(radius: 3)

                Image(systemName: "pencil")
                    .foregroundColor(.white)
                    .onTapGesture { onEdit() }
            }
            .padding([.leading, .bottom], 16)
        }
    }

    private var banner: Image {
        artist.bannerData
            .flatMap(UIImage.init(data:))
            .map(Image.init(uiImage:))
        ?? Image(systemName: "photo")
    }
    private var avatar: Image {
        artist.avatarData
            .flatMap(UIImage.init(data:))
            .map(Image.init(uiImage:))
        ?? Image(systemName: "person.circle")
    }
}

// ────────────────────────────────────────────────────────────
// MARK: SongsList  (live refresh, swipe, batch)
// ────────────────────────────────────────────────────────────
private struct SongsList: View {

    @EnvironmentObject private var store : ArtistStore
    @EnvironmentObject private var player: AudioPlayer

    let artistID: UUID
    let onArtTap: (UUID) -> Void

    @State private var selection  = Set<UUID>()
    @State private var editMode   : EditMode = .inactive
    @State private var batchSheet = false
    @State private var editSong   : Song?

    private var artist: Artist? { store.artists.first { $0.id == artistID } }

    var body: some View {
        if let artist {
            List(selection: $selection) {
                ForEach(artist.chronologicalSongs) { song in
                    row(for: song)
                }
                .onDelete { idx in
                    let ids = idx.map { artist.chronologicalSongs[$0].id }
                    store.delete(songs: ids, for: artist.id)
                }
            }
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !selection.isEmpty { Button("Batch Edit") { batchSheet = true } }
                    EditButton()
                }
            }
            .sheet(isPresented: $batchSheet) {
                BatchEditSheet(artistID: artist.id,
                               songIDs: Array(selection))
                    .environmentObject(store)
                    .onDisappear { selection.removeAll() }
            }
            .sheet(item: $editSong) { s in
                EditSongSheet(artistID: artist.id, song: s)
                    .environmentObject(store)
            }
        }
    }

    // single row
    @ViewBuilder
    private func row(for song: Song) -> some View {
        HStack {
            art(for: song)
                .onTapGesture { onArtTap(song.id) }

            VStack(alignment: .leading) {
                Text(song.title)
                Text(song.version)
                    .font(.caption).foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if editMode == .inactive { player.playSong(song) }
            }
        }
        .contextMenu { Button("Edit") { editSong = song } }
        .onDrag { NSItemProvider(object: song.id.uuidString as NSString) }
    }

    private func art(for song: Song) -> some View {
        Group {
            if let d = song.artworkData,
               let i = UIImage(data: d) {
                Image(uiImage: i).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").resizable().scaledToFit()
                    .padding(10).foregroundColor(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .background(Color.secondary.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// 
// ────────────────────────────────────────────────────────────
// MARK: CollaboratorsList  (unchanged)
// ────────────────────────────────────────────────────────────
private struct CollaboratorsList: View {
    let artist: Artist
    let onTap : (String) -> Void

    var body: some View {
        let names = Array(Set(artist.songs.flatMap { $0.creators })).sorted()

        if names.isEmpty {
            EmptyState(icon: "person.3",
                       title: "No Collaborators",
                       message: "Add song credits to see collaborators.")
        } else {
            ForEach(names, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture { onTap(name) }
                Divider()
            }
        }
    }
}

