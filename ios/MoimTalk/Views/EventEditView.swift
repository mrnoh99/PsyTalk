import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct EventFormData {
    var title: String
    var startAt: String
    var place: String?
    var link: String?
    var scope: String?
    var description: String?
    var presenter: String?
    var keywords: [String]
    var keptUrls: [String]
    var keptNames: [String]
    var newAttachments: [(name: String, data: Data)]
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
    @State private var presenter = ""
    @State private var existing: [(name: String, url: String)] = []   // 기존 첨부
    @State private var picked: [(name: String, data: Data)] = []       // 새로 추가
    @State private var showImporter = false
    @State private var err: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("제목 (예: 증례 컨퍼런스)", text: $evTitle)
                    DatePicker("날짜", selection: $date, displayedComponents: .date).datePickerStyle(.compact)
                    DatePicker("시간", selection: $time, displayedComponents: .hourAndMinute).datePickerStyle(.compact)
                    TextField("장소 (의국 회의실)", text: $place)
                    TextField("발표자 (이름·직위, 여러 명은 쉼표로)", text: $presenter, axis: .vertical).lineLimit(2...4)
                    TextField("링크 (https://zoom.us/...)", text: $link).autocapitalization(.none)
                    TextField("참석 범위 (예: 의국 전공의 전원)", text: $scope)
                    TextField("설명 (안건/준비사항)", text: $desc, axis: .vertical).lineLimit(2...4)
                }
                Section("첨부 자료 (여러 개 가능)") {
                    Button { showImporter = true } label: {
                        Text("📎 파일 추가").foregroundColor(catColor("work"))
                    }
                    ForEach(Array(existing.enumerated()), id: \.offset) { idx, item in
                        HStack {
                            Text("📎 \(item.name)").lineLimit(1)
                            Spacer()
                            Button("제거", role: .destructive) { existing.remove(at: idx) }
                                .font(.system(size: 12))
                        }
                    }
                    ForEach(Array(picked.enumerated()), id: \.offset) { idx, item in
                        HStack {
                            Text("🆕 \(item.name)").lineLimit(1).foregroundColor(catColor("work"))
                            Spacer()
                            Button("제거", role: .destructive) { picked.remove(at: idx) }
                                .font(.system(size: 12))
                        }
                    }
                }
                if let err = err {
                    Section { Text(err).foregroundColor(Moim.admin).font(.system(size: 12)) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(initial == nil ? "등록" : "저장") { submit() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            if let data = try? Data(contentsOf: url) {
                                picked.append((name: url.lastPathComponent, data: data))
                            }
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
        desc = e.description ?? ""; presenter = e.presenter ?? ""
        existing = e.attachmentList.map { (name: $0.name, url: $0.url) }
    }

    private func submit() {
        let t = evTitle.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { err = "제목을 입력하세요"; return }
        let form = EventFormData(
            title: t,
            startAt: CalDate.buildStartAt(date: date, time: time),
            place: place.trimmed(), link: link.trimmed(), scope: scope.trimmed(),
            description: desc.trimmed(), presenter: presenter.trimmed(), keywords: [],
            keptUrls: existing.map { $0.url },
            keptNames: existing.map { $0.name },
            newAttachments: picked
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
