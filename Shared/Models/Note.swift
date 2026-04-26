import Foundation

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var lastModified: Date

    init(id: UUID = UUID(), title: String, content: String, lastModified: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.lastModified = lastModified
    }

    /// 从 markdown 内容自动提取标题（第一个 # 行，或前20字符）
    static func titleFromContent(_ content: String) -> String {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        // fallback: 前30字符
        let prefix = String(content.prefix(30))
        return prefix.components(separatedBy: .newlines).first ?? "无标题"
    }
}
