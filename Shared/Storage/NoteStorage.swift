import Foundation

enum NoteStorage {
    private static let key = "saved_notes"
    private static let versionKey = "saved_notes_version"
    private static let currentVersion = 1
    private static let appGroup = "group.com.memo.shared"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static func loadNotes() -> [Note] {
        defaults.synchronize()

        guard let data = defaults.data(forKey: key) else {
            return []
        }

        do {
            let notes = try JSONDecoder().decode([Note].self, from: data)
            return notes
        } catch {
            print("[Storage] 解码笔记失败: \(error.localizedDescription)")
            return []
        }
    }

    static func saveNotes(_ notes: [Note]) {
        do {
            let data = try JSONEncoder().encode(notes)
            defaults.set(data, forKey: key)
            defaults.set(currentVersion, forKey: versionKey)
            DispatchQueue.global(qos: .utility).async {
                defaults.synchronize()
            }
        } catch {
            print("[Storage] 编码笔记失败: \(error.localizedDescription)")
        }
    }
}
