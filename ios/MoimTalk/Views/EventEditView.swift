import SwiftUI
import UniformTypeIdentifiers

struct EventFormData {
    var title: String
    var startAt: String
    var place: String?
    var link: String?
    var scope: String?
    var description: String?
    var keywords: [String]
    var attachmentName: String?
    var attachmentData: Data?
    var attachmentDesc: String?
}

struct EventEditView: View {
    let title: String
    let initial: CalendarEvent?
    let allowAttachment: Bool
    let onSubmit: (EventFormData) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var evTitle = ""
    @State private var date = CalDate.today()
    @State private var time = Date()
    @State private var place = ""
    @State private var link = ""
    @State private var scope = ""
    @State private var desc = ""
    @State private var kw = ""
    @State private var attDesc = ""
    @State private var attachment: (name: String, data: Data)?
    @State private var showImporter = false
    @State private var err: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("제목 (예: 증례 컨퍼런스)", text: $evTitle)
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                    DatePicker("시간", selection: $time, displayedComponents: .hourAndMinute)
                    TextField("장소 (의국 회의실)", text: $place)
                    TextField("링크 (https://zoom.us/...)", text: $link).autocapitalization(.none)
                    TextField("참석 범위 (예: 의국 전공의 전원)", text: $scope)
                    TextField("설명 (안건/준비사항)", text: $desc, axis: .vertical).lineLimit(2...4)
                    TextField("키워드 (쉼표로 구분)", text: $kw)
                }
                if allowAttachment {
                    Section("첨부 자료") {
                        Button { showImporter = true } label: {
                            Text(attachment.map { "📎 \($0.name)" } ?? "📎 파일 첨부").foregroundColor(Moim.sub)
                        }
                        TextField("첨부 자료 설명", text: $attDesc)
                    }
                } else {
                    Section { Text("※ 첨부 파일은 수정 시 변경할 수 없습니다.").font(.system(size: 12)).foregroundColor(Moim.sub) }
                }
                if let err = err {
                    Section { Text(err).foregroundColor(Moim.admin).font(.system(size: 12)) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(initial == nil ? "등록" : "저장") { submit() }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            attachment = (url.lastPathComponent, data)
                        }
                    }
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let e = initial else { return }
        evTitle = e.title
        if let d = CalDate.parse(e.startAt) { date = d; time = d }
        place = e.place ?? ""; link = e.link ?? ""; scope = e.scope ?? ""
        desc = e.description ?? ""; kw = e.kw.joined(separator: ", ")
    }

    private func submit() {
        let t = evTitle.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { err = "제목을 입력하세요"; return }
        let form = EventFormData(
            title: t,
            startAt: CalDate.buildStartAt(date: date, time: time),
            place: place.trimmed(), link: link.trimmed(), scope: scope.trimmed(),
            description: desc.trimmed(), keywords: parseKeywords(kw),
            attachmentName: attachment?.name, attachmentData: attachment?.data,
            attachmentDesc: attDesc.trimmed()
        )
        onSubmit(form)
        dismiss()
    }
}

extension String {
    func trimmed() -> String? {
        let s = trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }
}
