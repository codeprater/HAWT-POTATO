import Contacts
import ContactsUI
import Foundation
import SwiftUI
import UIKit
import HAWTPotatoCore

struct PhoneContact: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var phone: String

    var player: PlayerRef {
        PlayerRef(id: "contact:\(phone)", displayName: name)
    }

    var initials: String {
        player.initials
    }

    static func from(_ contact: CNContact, phone: String) -> PhoneContact {
        let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
        return PhoneContact(
            id: "\(contact.identifier)-\(phone)",
            name: name.isEmpty ? phone : name,
            phone: phone
        )
    }
}

@MainActor
@Observable
final class ContactDirectory {
    static let shared = ContactDirectory()

    var contacts: [PhoneContact] = []
    var recent: [PhoneContact] = []
    var status: CNAuthorizationStatus = CNContactStore.authorizationStatus(for: .contacts)

    private let recentKey = "hp.recentPhoneContacts"

    var canRead: Bool {
        status == .authorized || status == .limited
    }

    init() {
        loadRecent()
    }

    func refreshIfAuthorized() async {
        status = CNContactStore.authorizationStatus(for: .contacts)
        guard canRead else { return }
        await fetchContacts()
    }

    func requestAccessFromTap() async {
        status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            let store = CNContactStore()
            _ = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                store.requestAccess(for: .contacts) { granted, _ in
                    cont.resume(returning: granted)
                }
            }
            status = CNContactStore.authorizationStatus(for: .contacts)
        }
        if canRead {
            await fetchContacts()
        }
    }

    func remember(_ contact: PhoneContact) {
        recent.removeAll { $0.phone == contact.phone }
        recent.insert(contact, at: 0)
        if recent.count > 16 { recent = Array(recent.prefix(16)) }
        saveRecent()
    }

    func matching(_ query: String) -> [PhoneContact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.phone.contains(trimmed)
        }
    }

    func recentForDisplay(players: [PlayerRef]) -> [PhoneContact] {
        var seen = Set<String>()
        var out: [PhoneContact] = []
        for contact in recent where seen.insert(contact.phone).inserted {
            out.append(contact)
        }
        for player in players {
            guard let phone = player.contactPhone else { continue }
            let contact = PhoneContact(id: player.id, name: player.displayName, phone: phone)
            if seen.insert(phone).inserted {
                out.append(contact)
            }
        }
        return Array(out.prefix(12))
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func fetchContacts() async {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var next: [PhoneContact] = []
        try? store.enumerateContacts(with: request) { contact, _ in
            guard let number = contact.phoneNumbers.first?.value.stringValue, !number.isEmpty else { return }
            next.append(.from(contact, phone: number))
        }
        contacts = next
    }

    private func loadRecent() {
        guard let data = UserDefaults.standard.data(forKey: recentKey),
              let saved = try? JSONDecoder().decode([PhoneContact].self, from: data) else { return }
        recent = saved
    }

    private func saveRecent() {
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }
}

struct SystemContactPicker: UIViewControllerRepresentable {
    var onPick: (PhoneContact) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        context.coordinator.onPick = onPick
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var onPick: (PhoneContact) -> Void

        init(onPick: @escaping (PhoneContact) -> Void) {
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            let phone: String
            if let value = contactProperty.value as? CNPhoneNumber {
                phone = value.stringValue
            } else {
                phone = contactProperty.contact.phoneNumbers.first?.value.stringValue ?? ""
            }
            guard !phone.isEmpty else { return }
            onPick(.from(contactProperty.contact, phone: phone))
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            guard let phone = contact.phoneNumbers.first?.value.stringValue, !phone.isEmpty else { return }
            onPick(.from(contact, phone: phone))
        }
    }
}

struct ContactPickList: View {
    @Binding var query: String
    var limit: Int = 40
    var onPick: (PhoneContact) -> Void
    @Bindable private var contacts = ContactDirectory.shared
    @State private var showPicker = false

    var body: some View {
        Group {
            Button {
                Task {
                    await contacts.requestAccessFromTap()
                    showPicker = true
                }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text(contacts.canRead ? "Pick from Contacts" : "Allow Contacts for iMessage")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(HPColor.potatoOrange)
                .padding(.vertical, 4)
            }
            .buttonStyle(.hapticPlain)

            if contacts.status == .denied {
                Button("Open Settings to allow Contacts") {
                    contacts.openSettings()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(HPColor.muted)
            } else if !contacts.canRead {
                Text("Opens your phone’s contact list. Names and numbers stay on this device.")
                    .font(.caption)
                    .foregroundStyle(HPColor.faint)
            }

            if contacts.canRead {
                TextField("Search contacts", text: $query)
                    .foregroundStyle(HPColor.ink)
                let rows = Array(contacts.matching(query).prefix(limit))
                if rows.isEmpty {
                    Text(query.isEmpty ? "No contacts with phone numbers." : "No match.")
                        .font(.subheadline)
                        .foregroundStyle(HPColor.faint)
                } else {
                    ForEach(rows) { contact in
                        contactRow(contact)
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            SystemContactPicker { contact in
                contacts.remember(contact)
                showPicker = false
                onPick(contact)
            }
            .ignoresSafeArea()
        }
        .task { await contacts.refreshIfAuthorized() }
    }

    private func contactRow(_ contact: PhoneContact) -> some View {
        Button {
            contacts.remember(contact)
            onPick(contact)
        } label: {
            HStack {
                Text(contact.initials)
                    .font(.caption.bold())
                    .frame(width: 32, height: 32)
                    .background(HPColor.tan, in: Circle())
                    .foregroundStyle(HPColor.darkBrown)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .foregroundStyle(HPColor.ink)
                    Text(contact.phone)
                        .font(.caption2)
                        .foregroundStyle(HPColor.faint)
                }
                Spacer()
                Text("iMESSAGE")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
            }
        }
        .buttonStyle(.hapticPlain)
    }
}

struct RecentContactStrip: View {
    var players: [PlayerRef] = []
    var onPick: (PhoneContact) -> Void
    @Bindable private var contacts = ContactDirectory.shared
    @State private var showPicker = false

    var body: some View {
        let people = contacts.recentForDisplay(players: players)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT CONTACTS")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.faint)
                Spacer()
                Button {
                    Task {
                        await contacts.requestAccessFromTap()
                        showPicker = true
                    }
                } label: {
                    Label("All", systemImage: "person.crop.circle.badge.plus")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HPColor.potatoOrange)
                }
                .buttonStyle(.hapticPlain)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    Button {
                        Task {
                            await contacts.requestAccessFromTap()
                            showPicker = true
                        }
                    } label: {
                        chip(initials: "+", name: "Contacts", accent: true)
                    }
                    .buttonStyle(.hapticPlain)
                    ForEach(people) { contact in
                        Button {
                            contacts.remember(contact)
                            onPick(contact)
                        } label: {
                            chip(initials: contact.initials, name: contact.name, accent: false)
                        }
                        .buttonStyle(.hapticPlain)
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            SystemContactPicker { contact in
                contacts.remember(contact)
                showPicker = false
                onPick(contact)
            }
            .ignoresSafeArea()
        }
        .task { await contacts.refreshIfAuthorized() }
    }

    private func chip(initials: String, name: String, accent: Bool) -> some View {
        VStack(spacing: 6) {
            Text(initials)
                .font(.caption.weight(.heavy))
                .frame(width: 52, height: 52)
                .background(accent ? HPColor.potatoOrange : HPColor.tan, in: Circle())
                .foregroundStyle(accent ? .black : HPColor.darkBrown)
            Text(name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(HPColor.ink)
                .lineLimit(1)
                .frame(width: 64)
        }
    }
}
