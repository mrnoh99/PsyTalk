import SwiftUI

// 잔여 병실 현황 — 메모 형식 자유 텍스트 (편집 → 게시, 모두에게 공유)
struct WardStatusView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void

    @State private var editing = false
    @State private var draft = ""

    private var publishLabel: String? {
        guard let iso = vm.wardStatusUpdatedAt else { return nil }
        return CalDate.detailTimeLabel(iso)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("잔여 병실 현황").font(.system(size: 18, weight: .bold))
                Spacer()
                if !editing && canEditWard(vm.myProfile) {
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
                    WardStatusDocument(content: vm.wardStatus, publishLabel: publishLabel)
                        .padding(16)
                }
                .background(Moim.bg)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .onAppear { vm.loadWardStatus() }
    }
}

private struct WardStatusDocument: View {
    let content: String
    let publishLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xEA7317)).frame(height: 3)
            if let label = publishLabel {
                Text("게시").font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                    .padding(.top, 16)
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Moim.ink)
                    .lineSpacing(4)
                    .padding(.top, 4)
                Divider().background(Moim.line).padding(.vertical, 14)
            } else {
                Spacer().frame(height: 16)
            }
            if content.isEmpty {
                VStack(spacing: 8) {
                    Text("🛏").font(.system(size: 36))
                    Text("작성된 내용이 없습니다").font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
                    Text("우측 상단 ‘편집’을 눌러\n잔여 병실 현황을 작성하세요.")
                        .font(.system(size: 13)).foregroundColor(Moim.sub)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Text(content)
                    .font(.system(size: 15))
                    .foregroundColor(Moim.ink)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Moim.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Moim.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
