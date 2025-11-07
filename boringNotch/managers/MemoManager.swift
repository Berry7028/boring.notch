//
//  MemoManager.swift
//  boringNotch
//
//  Manages persistent memo items for the notch header
//

import Foundation
import Combine

struct MemoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var order: Int
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), text: String, order: Int, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

class MemoManager: ObservableObject {
    static let shared = MemoManager()

    @Published private(set) var items: [MemoItem] = []

    private let storageKey = "persistentMemoItems"

    private init() {
        loadItems()
    }

    // MARK: - Public Methods

    func addItem(text: String) {
        let newOrder = items.isEmpty ? 0 : (items.map { $0.order }.max() ?? 0) + 1
        let newItem = MemoItem(text: text, order: newOrder)
        items.append(newItem)
        saveItems()
    }

    func updateItem(id: UUID, text: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].text = text
        items[index].updatedAt = Date()
        saveItems()
    }

    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        // Re-order remaining items
        for (index, item) in items.enumerated() {
            items[index].order = index
        }
        saveItems()
    }

    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        // Re-order remaining items
        for (index, _) in items.enumerated() {
            items[index].order = index
        }
        saveItems()
    }

    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        // Update order for all items
        for (index, _) in items.enumerated() {
            items[index].order = index
        }
        saveItems()
    }

    func clearAll() {
        items.removeAll()
        saveItems()
    }

    // MARK: - Private Methods

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decoder = JSONDecoder()
            items = try decoder.decode([MemoItem].self, from: data)
            // Sort by order
            items.sort { $0.order < $1.order }
        } catch {
            print("Failed to load memo items: \(error)")
            items = []
        }
    }

    private func saveItems() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save memo items: \(error)")
        }
    }
}
