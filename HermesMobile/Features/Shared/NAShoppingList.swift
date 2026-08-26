import Foundation
import SwiftUI

// MARK: - Model

struct ShoppingItem: Identifiable, Codable {
    let id: String
    var name: String
    var category: String
    var isCompleted: Bool
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        category: String = "",
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

// MARK: - Service

/// Thread-safe shopping list service with local (UserDefaults) + remote (REST) persistence.
@MainActor
final class NAShoppingListService: ObservableObject {
    @Published var items: [ShoppingItem] = []

    private let userDefaultsKey = "NAShoppingListItems"
    private let baseURL = URL(string: "https://health.santoslab.de/api/naice/shopping")!
    private var pollingTask: Task<Void, Never>?
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Init

    init() {
        loadFromUserDefaults()
    }

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - Local CRUD

    func addItem(name: String, category: String = "") {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let item = ShoppingItem(name: trimmedName, category: category)
        items.append(item)
        saveToUserDefaults()
    }

    func toggleItem(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()
        saveToUserDefaults()
    }

    func deleteItem(_ id: String) {
        items.removeAll { $0.id == id }
        saveToUserDefaults()
    }

    // MARK: - UserDefaults Persistence

    private func saveToUserDefaults() {
        guard let data = try? encoder.encode(items) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? decoder.decode([ShoppingItem].self, from: data)
        else { return }
        items = decoded
    }

    // MARK: - Remote Server

    /// Fetch the full list from the server (replaces local items).
    func reloadFromServer() async {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                print("[NAShoppingListService] reloadFromServer: non-200 response")
                return
            }

            let remoteItems = try decoder.decode([ShoppingItem].self, from: data)
            self.items = remoteItems
            saveToUserDefaults()
        } catch {
            print("[NAShoppingListService] reloadFromServer error: \(error.localizedDescription)")
        }
    }

    /// Upload the current local list to the server.
    func syncToServer() async {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try encoder.encode(items)

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ... 299).contains(httpResponse.statusCode)
            else {
                print("[NAShoppingListService] syncToServer: non-200 response")
                return
            }
        } catch {
            print("[NAShoppingListService] syncToServer error: \(error.localizedDescription)")
        }
    }

    /// Start polling the server every `interval` seconds (default 30).
    /// Call this once during app launch.
    func subscribeToServer(interval: TimeInterval = 30) {
        pollingTask?.cancel()

        pollingTask = Task { [weak self] in
            guard let self else { return }

            // Initial load
            await self.reloadFromServer()

            // Periodic refresh
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await self.reloadFromServer()
            }
        }
    }

    /// Stop polling.
    func unsubscribeFromServer() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}