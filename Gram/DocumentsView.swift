import SwiftUI
import WebKit

struct DocumentsView: View {
    @AppStorage("gramHost") private var host = "192.168.0.202"
    @State private var query = ""
    @State private var docs: [Doc] = []
    @State private var error: String?
    @State private var loaded = false

    private var client: GramClient { GramClient(host: host) }

    var body: some View {
        NavigationStack {
            List {
                if let error { ErrorBanner(message: error) }
                if loaded && docs.isEmpty && error == nil {
                    Text(query.isEmpty ? "No documents yet." : "No matches.")
                        .foregroundStyle(Theme.muted)
                        .cardRow()
                }

                ForEach(docs) { doc in
                    NavigationLink {
                        DocDetailView(doc: doc, fileURL: client.docFileURL(id: doc.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(doc.displayTitle)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.text)
                                .lineLimit(2)
                            if let snippet = doc.cleanSnippet, !snippet.isEmpty {
                                Text(snippet).font(.caption).foregroundStyle(Theme.muted).lineLimit(3)
                            }
                            HStack(spacing: 8) {
                                if !doc.category.isEmpty {
                                    Chip(text: doc.category, color: Theme.docs)
                                }
                                if !doc.doc_date.isEmpty {
                                    Text(doc.doc_date).font(.caption2).foregroundStyle(Theme.muted)
                                }
                                Text(sizeLabel(doc.size))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .cardRow()
                }
            }
            .listStyle(.insetGrouped)
            .gramScreen(Theme.docs)
            .navigationTitle("Documents")
            .searchable(text: $query, prompt: "Search every PDF and scan")
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: query) { Task { await load() } }
            .onChange(of: host) { Task { await load() } }
        }
    }

    private func sizeLabel(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func load() async {
        do {
            docs = try await client.docs(query: query)
            error = nil
        } catch {
            self.error = "Docvault unreachable (\(host):4327)"
        }
        loaded = true
    }
}

private struct DocDetailView: View {
    let doc: Doc
    let fileURL: URL

    var body: some View {
        FileWebView(url: fileURL)
            .ignoresSafeArea(edges: .bottom)
            .background(Theme.bg)
            .navigationTitle(doc.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ShareLink(item: fileURL) { Image(systemName: "square.and.arrow.up") }
            }
            .tint(Theme.docs)
    }
}

// WKWebView renders PDFs and images natively — exactly what docvault stores.
private struct FileWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView()
        v.isOpaque = false
        v.backgroundColor = UIColor(Theme.bg)
        v.scrollView.backgroundColor = UIColor(Theme.bg)
        v.load(URLRequest(url: url))
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
