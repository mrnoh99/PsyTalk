import SwiftUI

// 병실 잔여 현황 — 메모 형식 자유 텍스트 (편집 → 게시, 모두에게 공유)
struct WardStatusView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void

    @State private var editing = false
    @State private var draft = ""

    private var updatedLabel: String? {
        guard let iso = vm.wardStatusUpdatedAt, let d = CalDate.parse(iso) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = CalDate.kst
        f.dateFormat = "M/d HH:mm"
        return f.string(from: d)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("병실 잔여 현황").font(.system(size: 18, weight: .bold))
                Spacer()
                if !editing {
                    Button("편집") { draft = vm.wardStatus; editing = true }.font(.system(size: 15, weight: .bold))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.paper)
            Divider().background(Moim.line)

            if editing {
                VStack(spacing: 12) {
                    TextEditor(text: $draft)
                        .font(.system(size: 15))
                        .padding(8)
                        .background(Moim.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Moim.line))
                    HStack(spacing: 10) {
                        Button { editing = false } label: {
                            Text("취소").frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Moim.line).foregroundColor(Moim.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button { vm.saveWardStatus(draft) { editing = false } } label: {
                            Text("게시").frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Moim.accent).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Text("🛏").font(.system(size: 22))
                            Text("병실 잔여 현황").font(.system(size: 18, weight: .heavy)).foregroundColor(Moim.ink)
                        }
                        if let label = updatedLabel {
                            Text("최종 수정: \(label)").font(.system(size: 11)).foregroundColor(Moim.sub).padding(.top, 4)
                        }
                        Spacer().frame(height: 14)

                        if vm.wardStatus.isEmpty {
                            EmptyBox(emoji: "🛏", title: "작성된 내용이 없습니다",
                                     subtitle: "우측 상단 ‘편집’을 눌러\n병실 잔여 현황을 작성하세요.")
                        } else {
                            Text(vm.wardStatus)
                                .font(.system(size: 15)).foregroundColor(Moim.ink)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .onAppear { vm.loadWardStatus() }
    }
}
