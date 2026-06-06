import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        importSharedItems()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        statusLabel.text = "正在保存到备忘录"
        statusLabel.font = .preferredFont(forTextStyle: .title3)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        detailLabel.text = "保存后打开主 App 可立即同步到 Apple Watch。"
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        openButton.setTitle("打开备忘录同步到 Apple Watch", for: .normal)
        openButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(openHostApp), for: .touchUpInside)

        closeButton.setTitle("完成", for: .normal)
        closeButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        closeButton.addTarget(self, action: #selector(closeExtension), for: .touchUpInside)

        activityIndicator.startAnimating()

        let stack = UIStackView(arrangedSubviews: [
            activityIndicator,
            statusLabel,
            detailLabel,
            openButton,
            closeButton
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func importSharedItems() {
        let providers = sharedItemProviders()
        guard !providers.isEmpty else {
            showFailure("没有找到可保存的 Markdown 内容。")
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var loadedContents: [(index: Int, content: String)] = []
        var loadErrors: [String] = []

        for (index, provider) in providers.enumerated() {
            group.enter()
            loadMarkdown(from: provider) { result in
                lock.lock()
                switch result {
                case .success(let content):
                    loadedContents.append((index, content))
                case .failure(let error):
                    loadErrors.append(error.localizedDescription)
                }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !loadedContents.isEmpty else {
                self.showFailure(loadErrors.first ?? "读取 Markdown 文件失败。")
                return
            }

            do {
                var notes = NoteStorage.loadNotes()
                for item in loadedContents.sorted(by: { $0.index < $1.index }).reversed() {
                    notes = try NoteImportService.importMarkdown(item.content, into: notes)
                }
                NoteStorage.saveNotes(notes)
                self.showSuccess(count: loadedContents.count)
            } catch {
                self.showFailure("保存失败：\(error.localizedDescription)")
            }
        }
    }

    private func sharedItemProviders() -> [NSItemProvider] {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return []
        }

        return inputItems.flatMap { item in
            item.attachments ?? []
        }
    }

    private func loadMarkdown(
        from provider: NSItemProvider,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let typeIdentifier = preferredTypeIdentifier(for: provider) else {
            completion(.failure(ShareImportError.unsupportedType))
            return
        }

        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            do {
                completion(.success(try Self.markdownString(from: item)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        let preferred = [
            UTType.fileURL.identifier,
            UTType.utf8PlainText.identifier,
            UTType.plainText.identifier,
            "net.daringfireball.markdown",
            "public.markdown",
            UTType.text.identifier,
            UTType.data.identifier
        ]

        for identifier in preferred where provider.hasItemConformingToTypeIdentifier(identifier) {
            return identifier
        }

        return provider.registeredTypeIdentifiers.first { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .fileURL) ||
                type.conforms(to: .plainText) ||
                type.conforms(to: .text) ||
                type.conforms(to: .data)
        }
    }

    private static func markdownString(from item: NSSecureCoding?) throws -> String {
        if let string = item as? String {
            return string
        }

        if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }

        if let url = item as? URL {
            return try markdownString(from: url)
        }

        if let url = item as? NSURL {
            return try markdownString(from: url as URL)
        }

        throw ShareImportError.unreadableContent
    }

    private static func markdownString(from url: URL) throws -> String {
        guard url.isFileURL else {
            throw ShareImportError.unsupportedType
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ShareImportError.invalidEncoding
        }
        return string
    }

    private func showSuccess(count: Int) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.text = count == 1 ? "已保存到备忘录" : "已保存 \(count) 条备忘录"
        detailLabel.text = "打开主 App 后会触发同步，让 Apple Watch 尽快收到最新笔记。"
        openButton.isHidden = false
    }

    private func showFailure(_ message: String) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        statusLabel.text = "保存失败"
        detailLabel.text = message
        openButton.isHidden = true
    }

    @objc private func openHostApp() {
        guard let url = URL(string: "memoapp://sync") else { return }
        extensionContext?.open(url) { [weak self] success in
            if !success {
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    @objc private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

private enum ShareImportError: LocalizedError {
    case unsupportedType
    case unreadableContent
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "当前分享内容不是可读取的 Markdown 文件或文本。"
        case .unreadableContent:
            return "无法读取分享内容。"
        case .invalidEncoding:
            return "文件不是 UTF-8 编码，暂时无法导入。"
        }
    }
}
