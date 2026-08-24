import Foundation
import CoreSpotlight
import UIKit

// MARK: - Core Spotlight Indexer
@MainActor
class NASpotlightService {
    static let shared = NASpotlightService()

    func indexNotes(_ notes: [(id: String, title: String, text: String)]) {
        let searchableItems = notes.map { note -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = note.title
            attributeSet.contentDescription = String(note.text.prefix(100))
            attributeSet.keywords = note.title.split(separator: " ").map(String.init)

            return CSSearchableItem(
                uniqueIdentifier: "naice_note_\(note.id)",
                domainIdentifier: "com.santoslab.naice.notes",
                attributeSet: attributeSet
            )
        }

        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("[Spotlight] Index error: \(error.localizedDescription)")
            } else {
                print("[Spotlight] ✅ \(searchableItems.count) notes indexed")
            }
        }
    }

    func indexContact(_ id: String, name: String, org: String?, phone: String?) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .contact)
        attributeSet.title = name
        attributeSet.contentDescription = org ?? phone ?? ""
        attributeSet.keywords = name.split(separator: " ").map(String.init)
        if let p = phone { attributeSet.phoneNumbers = [p] }

        let item = CSSearchableItem(
            uniqueIdentifier: "naice_contact_\(id)",
            domainIdentifier: "com.santoslab.naice.contacts",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("[Spotlight] Contact index error: \(error.localizedDescription)")
            }
        }
    }

    func indexExpense(_ id: String, amount: Double, category: String, note: String) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
        attributeSet.title = "\(category): \(Int(amount))€"
        attributeSet.contentDescription = note
        attributeSet.keywords = [category, note]

        let item = CSSearchableItem(
            uniqueIdentifier: "naice_expense_\(id)",
            domainIdentifier: "com.santoslab.naice.expenses",
            attributeSet: attributeSet
        )

        CSSearchableIndex.default().indexSearchableItems([item])
    }

    func clearAll() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("[Spotlight] Clear error: \(error.localizedDescription)")
            } else {
                print("[Spotlight] ✅ All items cleared")
            }
        }
    }
}