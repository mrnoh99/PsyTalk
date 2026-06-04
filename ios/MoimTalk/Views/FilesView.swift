import SwiftUI
import UniformTypeIdentifiers

private struct FileEntry: Identifiable {
    let id = UUID()
    let name: String
    let url: String?
    let description: String
    let keywords: [String]
    let by: String
    let day: String
    let fromCalendar: Bool
    let sortKey: String
}

struct FilesView: View {
    @ObservedObject var vm: MoimViewModel
    let canUpload: Bool

    @State private var sort = "date"   // date | kw
    @State private var showImporter = false
    @State private var pending: (name: String, data: Data)?

    private var entries: [FileEntry] {
        let direct = vm.files.map {
            FileEntry(name: $0.fileName, url: $0.fileUrl, description: $0.description ?? "",
                      keywords: $0.kw, by: vm.name(of: $0.uploadedBy),
                      day: CalDate.dayLabel($0.createdAt), fromCalendar: false, sortKey: $0.createdAt ?? "")
        }
        let fromCal = vm.events.flatMap { e in
            e.attachmentList.map { att in
                FileEntry(name: att.name, url: att.url,
                          description: e.title, keywords: e.kw,
                          by: vm.name(of: e.ownerId), day: CalDate.dayLabel(e.startAt),
                          fromCalendar: true, sortKey: e.startAt)
            }
        }
        return direct + fromCal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    sortButton("📅 날짜순", "date"); sortButton("🏷 키워드별", "kw")
                }
                .padding(.bottom, 12)

                if canUpload {
                    Button { showImporter = true } label: {
                        Text("⬆️ 파일 올리기").font(.system(size: 13.5, weight: .semibold)).foregroundColor(Moim.sub)
                            .frame(maxWidth: .infinity).padding(14)
                            .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .padding(.bottom, 13)
                }

                if entries.isEmpty {
                    EmptyBox(emoji: "📁", title: "자료가 없습니다", subtitle: "채팅·캘린더에 올린 자료가\n여기 모입니다.")
                } else if sort == "date" {
                    ForEach(entries.sorted { $0.sortKey > $1.sortKey }) { fileCard($0) }
                } else {
                    ForEach(groupedKeys(), id: \.self) { key in
                        Text("🏷 \(key)").font(.system(size: 11, weight: .heavy)).foregroundColor(catColor("research"))
                            .padding(.top, 6).padding(.bottom, 8)
                        ForEach(grouped()[key] ?? []) { fileCard($0) }
                    }
                }
            }
            .padding(13)
        }
        .background(Moim.paper)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) { pending = (url.lastPathComponent, data) }
                }
            }
        }
        .sheet(isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            if let p = pending {
                FileUploadView(fileName: p.name) { desc, kw in
                    vm.uploadFile(fileName: p.name, data: p.data, description: desc, keywords: kw) { pending = nil }
                }
            }
        }
    }

    private func grouped() -> [String: [FileEntry]] {
        var dict: [String: [FileEntry]] = [:]
        for f in entries {
            let keys = f.keywords.isEmpty ? ["기타"] : f.keywords
            for k in keys { dict[k, default: []].append(f) }
        }
        return dict
    }
    private func groupedKeys() -> [String] { Array(grouped().keys).sorted() }

    private func sortButton(_ label: String, _ value: String) -> some View {
        let on = sort == value
        return Text(label).font(.system(size: 12.5, weight: .bold))
            .foregroundColor(on ? .white : Moim.sub)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(on ? Moim.accent : Moim.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { sort = value }
    }

    @ViewBuilder private func fileCard(_ f: FileEntry) -> some View {
        let content = HStack(alignment: .top, spacing: 11) {
            Text(f.fromCalendar ? "📎" : "📄").font(.system(size: 18))
                .frame(width: 40, height: 40)
                .background(f.fromCalendar ? catColor("research") : catColor("work"))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(f.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(Moim.ink).lineLimit(1)
                if !f.description.isEmpty {
                    Text(f.description).font(.system(size: 12)).foregroundColor(Moim.ink.opacity(0.75)).lineLimit(2)
                }
                HStack(spacing: 5) {
                    Text("\(f.by) · \(f.day)").font(.system(size: 11)).foregroundColor(Moim.sub)
                    Text(f.fromCalendar ? "캘린더" : "직접")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(f.fromCalendar ? catColor("research") : catColor("work"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(f.fromCalendar ? Color(hex: 0xEFE7F5) : Color(hex: 0xE7F0EB))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                if !f.keywords.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(f.keywords.prefix(4), id: \.self) { k in
                            Text("#\(k)").font(.system(size: 10, weight: .bold)).foregroundColor(catColor("research"))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color(hex: 0xF0EAF6)).clipShape(Capsule())
                        }
                    }
                    .padding(.top, 5)
                }
            }
            Spacer()
        }
        .padding(12).background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.bottom, 9)

        if let url = f.url, let u = URL(string: url) {
            Link(destination: u) { content }
        } else {
            content
        }
    }
}

struct FileUploadView: View {
    let fileName: String
    let onConfirm: (String, [String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var desc = ""
    @State private var kw = ""

    var body: some View {
        NavigationView {
            Form {
                Section("자료 올리기") {
                    Text(fileName).font(.system(size: 13)).foregroundColor(Moim.sub)
                    TextField("설명문 (예: 발표 슬라이드 초안)", text: $desc)
                    TextField("키워드 (쉼표로 구분)", text: $kw)
                }
            }
            .navigationTitle("자료 올리기").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("업로드") { onConfirm(desc.trimmingCharacters(in: .whitespaces), parseKeywords(kw)); dismiss() }
                }
            }
        }
    }
}
