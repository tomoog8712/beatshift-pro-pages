import Foundation

final class SetlistStore {
    private let key = AppConstants.setlistKey

    func load() -> [SetlistItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SetlistItem].self, from: data)) ?? []
    }

    func save(_ items: [SetlistItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
