import Foundation

enum NoteStorage {
    private static let key = "saved_notes"
    private static let appGroup = "group.com.memo.shared"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func loadNotes() -> [Note] {
        defaults.synchronize()
        guard let data = defaults.data(forKey: key),
              let notes = try? JSONDecoder().decode([Note].self, from: data) else {
            return []
        }
        return notes
    }

    static func saveNotes(_ notes: [Note]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: key)
        DispatchQueue.global(qos: .utility).async {
            defaults.synchronize()
        }
    }
}
