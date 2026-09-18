import SwiftUI
import PhotosUI
import ImageIO
import UniformTypeIdentifiers

enum BakeryLogo {
    /// Downsample before decoding; preserve transparency and photo orientation.
    static func prepare(_ data: Data) throws -> Data {
        try require(!data.isEmpty && data.count <= 20_000_000, "Choose an image smaller than 20 MB.")
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw BakeryError("This file could not be opened as an image.") }
        for pixels in [1024, 768, 512] {
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: pixels, kCGImageSourceShouldCacheImmediately: true]
            if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary), let png = UIImage(cgImage: cg).pngData(), png.count <= 2_000_000 { return png }
        }
        throw BakeryError("This image could not be resized. Try a PNG, JPEG or HEIC logo.")
    }
}

struct BakeryLogoView: View {
    var data: Data?
    var size: CGFloat = 64
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(6)
            } else {
                Image(systemName: "storefront").resizable().scaledToFit().padding(size * 0.23).foregroundStyle(Color.bakeDeep)
            }
        }.frame(width: size, height: size).background(.white, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(data == nil ? "Bakery logo placeholder" : "Bakery logo").accessibilityIdentifier("bakery.logo")
    }
}

struct BakeryProfileView: View {
    @EnvironmentObject private var store: BakeryStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var owner: String
    @State private var profile: BakeryProfile
    private let originalName: String
    private let originalOwner: String
    private let originalProfile: BakeryProfile
    @State private var photo: PhotosPickerItem?
    @State private var importFile = false
    @State private var importing = false
    @State private var error: String?
    @State private var discard = false

    init(settings: Settings) {
        originalName = settings.bakery; originalOwner = settings.owner; originalProfile = settings.profile ?? BakeryProfile()
        _name = State(initialValue: settings.bakery); _owner = State(initialValue: settings.owner)
        _profile = State(initialValue: settings.profile ?? BakeryProfile())
    }
    private var changed: Bool { name != originalName || owner != originalOwner || profile != originalProfile }
    var body: some View {
        Form {
            Section {
                HStack(spacing: 18) {
                    BakeryLogoView(data: profile.logoData, size: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name.isEmpty ? "Your bakery" : name).font(.title3.bold())
                        Text("Your brand, on every receipt.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
                PhotosPicker(selection: $photo, matching: .images) { Label("Choose logo from Photos", systemImage: "photo") }.disabled(importing)
                Button("Choose logo from Files", systemImage: "folder") { importFile = true }.disabled(importing)
                if profile.logoData != nil { Button("Remove logo", role: .destructive) { profile.logoData = nil; photo = nil }.disabled(importing) }
                if importing { ProgressView("Preparing logo…") }
            } footer: { Text("PNG, JPEG and HEIC supported. Transparent PNGs work well. Your logo keeps its proportions.") }
            Section("Bakery identity") {
                TextField("Bakery name", text: $name).accessibilityIdentifier("profile.name")
                TextField("Your first name", text: $owner)
            }
            Section {
                TextField("Contact person (optional)", text: $profile.contactName)
                TextField("Bakery address", text: $profile.address, axis: .vertical).lineLimit(2...5).accessibilityIdentifier("profile.address")
                TextField("Phone", text: $profile.phone).keyboardType(.phonePad)
                TextField("Email", text: $profile.email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Website", text: $profile.website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Business / tax ID (optional)", text: $profile.registrationID)
            } header: { Text("Details on receipts") } footer: { Text("Fill in the details you want customers to see. Empty fields stay off the receipt.") }
            Section("Receipt message") {
                TextField("Thank-you message or pickup instructions", text: $profile.footer, axis: .vertical).lineLimit(3...6)
                Text("Receipts use the order’s agreed prices and recorded payments. Amounts are in CAD.").font(.footnote).foregroundStyle(.secondary)
            }
        }.bakeryBackground().navigationTitle("Bakery profile").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Back", systemImage: "chevron.left") { if changed { discard = true } else { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold).disabled(importing).accessibilityIdentifier("profile.save") }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
        }
        .task(id: photo) {
            guard let photo else { return }
            importing = true
            defer { importing = false }
            do {
                guard let data = try await photo.loadTransferable(type: Data.self) else { throw BakeryError("The selected image could not be loaded.") }
                try Task.checkCancellation()
                profile.logoData = try BakeryLogo.prepare(data)
            } catch is CancellationError { } catch { self.error = error.localizedDescription }
        }
        .fileImporter(isPresented: $importFile, allowedContentTypes: [.png, .jpeg, .heic, .heif]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                try require(size <= 20_000_000, "Choose an image smaller than 20 MB.")
                profile.logoData = try BakeryLogo.prepare(Data(contentsOf: url))
                photo = nil
            } catch { self.error = error.localizedDescription }
        }
        .alert("Check bakery details", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { error = nil } } message: { Text(error ?? "") }
        .confirmationDialog("Discard profile changes?", isPresented: $discard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() } }
    }
    private func save() {
        func trim(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
        var cleaned = profile
        cleaned.contactName = trim(profile.contactName); cleaned.address = trim(profile.address); cleaned.phone = trim(profile.phone)
        cleaned.email = trim(profile.email); cleaned.website = trim(profile.website); cleaned.registrationID = trim(profile.registrationID); cleaned.footer = trim(profile.footer)
        let ok = store.perform { state in state.settings.bakery = trim(name); state.settings.owner = trim(owner); state.settings.profile = cleaned }
        if ok { dismiss() } else { error = store.error; store.error = nil }
    }
}
