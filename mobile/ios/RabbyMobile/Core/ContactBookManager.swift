import Foundation
import Combine

/// Contact Book Manager - Manage trusted addresses and contacts
/// Equivalent to Web version's contactBook.ts
@MainActor
class ContactBookManager: ObservableObject {
    static let shared = ContactBookManager()
    
    @Published var contacts: [Contact] = []
    private let storage = StorageManager.shared
    private let database = DatabaseManager.shared
    
    private let contactsKey = "rabby_contacts"
    
    // MARK: - Contact Model
    
    struct Contact: Codable, Identifiable, Equatable {
        let id: String
        var name: String
        var address: String
        var isAlias: Bool  // Is this an alias for owned account
        var isContact: Bool  // Is this a manually added contact
        var cexId: String?  // CEX exchange ID if detected
        var note: String?
        var createdAt: Date
        var updatedAt: Date
        
        init(name: String, address: String, isAlias: Bool = false, isContact: Bool = true, note: String? = nil) {
            self.id = UUID().uuidString
            self.name = name
            self.address = address.lowercased()
            self.isAlias = isAlias
            self.isContact = isContact
            self.note = note
            self.createdAt = Date()
            self.updatedAt = Date()
        }

        init(
            id: String,
            name: String,
            address: String,
            isAlias: Bool,
            isContact: Bool,
            cexId: String?,
            note: String?,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.name = name
            self.address = address.lowercased()
            self.isAlias = isAlias
            self.isContact = isContact
            self.cexId = cexId
            self.note = note
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadContacts()
    }
    
    // MARK: - Public Methods
    
    /// Get contact by address
    func getContact(by address: String) -> Contact? {
        return contacts.first { $0.address.lowercased() == address.lowercased() }
    }
    
    /// Check if a contact exists for the given address
    func hasContact(address: String) -> Bool {
        return contacts.contains(where: { $0.address.lowercased() == address.lowercased() })
    }
    
    /// Get all contacts (excluding aliases)
    func listContacts() -> [Contact] {
        return contacts.filter { $0.isContact }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Get all aliases (account names)
    func listAliases() -> [Contact] {
        return contacts.filter { $0.isAlias }.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Add new contact
    func addContact(name: String, address: String, note: String? = nil) throws {
        // Validate address
        guard EthereumUtil.isValidAddress(address) else {
            throw ContactError.invalidAddress
        }
        
        // Check for duplicates
        if contacts.contains(where: { $0.address.lowercased() == address.lowercased() }) {
            throw ContactError.contactExists
        }
        
        let contact = Contact(name: name, address: address, note: note)
        contacts.append(contact)
        saveContacts()
    }
    
    /// Update contact
    func updateContact(_ contactId: String, name: String? = nil, note: String? = nil) throws {
        guard let index = contacts.firstIndex(where: { $0.id == contactId }) else {
            throw ContactError.contactNotFound
        }
        
        if let name = name {
            contacts[index].name = name
        }
        if let note = note {
            contacts[index].note = note
        }
        contacts[index].updatedAt = Date()
        
        saveContacts()
    }
    
    /// Update alias for owned account
    func updateAlias(address: String, alias: String) {
        if let index = contacts.firstIndex(where: { 
            $0.address.lowercased() == address.lowercased() && $0.isAlias 
        }) {
            contacts[index].name = alias
            contacts[index].updatedAt = Date()
        } else {
            let contact = Contact(name: alias, address: address, isAlias: true, isContact: false)
            contacts.append(contact)
        }
        saveContacts()
    }
    
    /// Delete contact
    func deleteContact(_ contactId: String) throws {
        guard let index = contacts.firstIndex(where: { $0.id == contactId }) else {
            throw ContactError.contactNotFound
        }
        
        contacts.remove(at: index)
        saveContacts()
    }
    
    /// Delete contact by address
    func deleteContact(byAddress address: String) {
        contacts.removeAll { $0.address.lowercased() == address.lowercased() }
        saveContacts()
    }
    
    /// Get display name for address (alias > contact name > formatted address)
    func getDisplayName(for address: String) -> String {
        if let contact = getContact(by: address) {
            return contact.name
        }
        return EthereumUtil.formatAddress(address)
    }
    
    /// Update CEX ID for address (detected from API)
    func updateCexId(address: String, cexId: String) {
        if let index = contacts.firstIndex(where: { $0.address.lowercased() == address.lowercased() }) {
            contacts[index].cexId = cexId
            contacts[index].updatedAt = Date()
            saveContacts()
        }
    }
    
    /// Search contacts by name or address
    func searchContacts(query: String) -> [Contact] {
        guard !query.isEmpty else {
            return listContacts()
        }
        
        let lowercasedQuery = query.lowercased()
        return contacts.filter { contact in
            contact.name.lowercased().contains(lowercasedQuery) ||
            contact.address.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadContacts() {
        if let rows = try? database.getContacts() {
            contacts = rows.map { row in
                Contact(
                    id: row.id,
                    name: row.name,
                    address: row.address,
                    isAlias: row.isAlias,
                    isContact: row.isContact,
                    cexId: row.cexId,
                    note: row.note,
                    createdAt: row.addedAt,
                    updatedAt: row.updatedAt
                )
            }
            if !contacts.isEmpty {
                return
            }
        }

        if let data = storage.getData(forKey: contactsKey),
           let decoded = try? JSONDecoder().decode([Contact].self, from: data) {
            contacts = decoded
        }
    }
    
    private func saveContacts() {
        let rows = contacts.map { contact in
            DatabaseManager.ContactRecord(
                id: contact.id,
                address: contact.address,
                name: contact.name,
                isAlias: contact.isAlias,
                isContact: contact.isContact,
                cexId: contact.cexId,
                note: contact.note,
                addedAt: contact.createdAt,
                updatedAt: contact.updatedAt
            )
        }
        try? database.replaceContacts(rows)

        if let encoded = try? JSONEncoder().encode(contacts) {
            storage.setData(encoded, forKey: contactsKey)
        }
    }
}

// MARK: - Errors

enum ContactError: Error, LocalizedError {
    case invalidAddress
    case contactExists
    case contactNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .contactExists:
            return "Contact already exists"
        case .contactNotFound:
            return "Contact not found"
        }
    }
}
