import SwiftUI
import UniformTypeIdentifiers

struct FileImportView: View {
    @EnvironmentObject var store: NoteStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingFilePicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("导入 Markdown 文件")
                .font(.title2.bold())

            Text("支持 .md 格式的文件\n导入后自动同步到 Apple Watch")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingFilePicker = true
            } label: {
                Label("选择文件", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            // 手动输入
            NavigationLink {
                ManualInputView()
            } label: {
                Label("手动输入", systemImage: "keyboard")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.gray.opacity(0.15))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationTitle("导入")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    importFile(url)
                }
            case .failure(let error):
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
        .alert("导入失败", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func importFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            alertMessage = "无法访问文件"
            showingAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            store.addNote(from: content)
            dismiss()
        } catch {
            alertMessage = "读取文件失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

struct ManualInputView: View {
    @EnvironmentObject var store: NoteStore
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""

    var body: some View {
        VStack {
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.gray.opacity(0.3), lineWidth: 1)
                )
                .padding()
        }
        .navigationTitle("新建笔记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    store.addNote(from: content)
                    dismiss()
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
