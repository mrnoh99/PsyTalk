import SwiftUI

// 가입 승인 — 신규 가입자(미승인)만 표시. 승인하면 '회원 관리' 명단으로 이동.
// · 전체관리자(superadmin)·탈퇴(비활성) 회원 제외
// · 기본 가나다순(이름) / 직군별 보기 토글
struct SignupApprovalView: View {
    @ObservedObject var vm: MoimViewModel

    @State private var byType = false   // false=가나다순(기본), true=직군별
    @State private var approveTarget: Profile?

    // 신규 가입자(미승인 + 미탈퇴, 전체관리자 제외)
    private var pending: [Profile] {
        vm.profilesById.values.filter(isSignupPending)
            .sorted {
                if byType, $0.memberType != $1.memberType { return $0.memberType < $1.memberType }
                return $0.name < $1.name
            }
    }

    // 직군별: 등장 순서 유지하며 그룹화
    private var groups: [(String, [Profile])] {
        var order: [String] = []
        var dict: [String: [Profile]] = [:]
        for p in pending {
            if dict[p.memberType] == nil { order.append(p.memberType) }
            dict[p.memberType, default: []].append(p)
        }
        return order.map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("정렬", selection: $byType) {
                Text("가나다순").tag(false)
                Text("직군별").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 10)

            Text("신규 가입자를 ‘승인’하면 바로 앱을 이용할 수 있고, 회원 관리 명단으로 이동합니다. (전체관리자 제외)")
                .font(.system(size: 12)).foregroundColor(Moim.sub)
                .padding(.bottom, 12)

            if pending.isEmpty {
                Text("승인 대기 중인 신규 가입자가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
            } else if byType {
                ForEach(groups, id: \.0) { g in
                    Text("\(g.0) · \(g.1.count)")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(typeColor(g.0))
                        .padding(.top, 4).padding(.bottom, 6)
                    ForEach(g.1) { p in approvalRow(p) }
                }
            } else {
                ForEach(pending) { p in approvalRow(p) }
            }
        }
        // 승인 confirm
        .confirmationDialog("‘\(approveTarget?.name ?? "")’ 님의 가입을 승인할까요?\n승인하면 앱을 바로 이용할 수 있습니다.",
                            isPresented: Binding(get: { approveTarget != nil }, set: { if !$0 { approveTarget = nil } }),
                            titleVisibility: .visible) {
            Button("승인") { if let p = approveTarget { vm.approveUser(p.id) }; approveTarget = nil }
            Button("취소", role: .cancel) { approveTarget = nil }
        }
    }

    private func approvalRow(_ p: Profile) -> some View {
        HStack(spacing: 11) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(p.name).font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink)
                    Text("대기")
                        .font(.system(size: 9.5, weight: .bold)).foregroundColor(Moim.admin)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Moim.admin.opacity(0.12)).clipShape(Capsule())
                }
                Text("\(p.memberType) · \(roleLabel(p.role))").font(.system(size: 11.5)).foregroundColor(Moim.sub)
                MemberContactLines(profile: p)
            }
            Spacer()
            Button { approveTarget = p } label: {
                Text("승인").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(catColor("work")).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 9)
    }
}
