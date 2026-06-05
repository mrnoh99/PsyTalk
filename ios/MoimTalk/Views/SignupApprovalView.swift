import SwiftUI

// 가입 승인 / 회원 — Android ApprovalScreen 과 동일
// · 전체관리자(superadmin) 제외
// · 미승인 → ‘승인’, 승인됨 → ‘퇴출’
// · 기본 가나다순(이름) → 상태가 바뀌어도 줄 위치 유지 / 직군별 보기 토글
struct SignupApprovalView: View {
    @ObservedObject var vm: MoimViewModel

    @State private var byType = false   // false=가나다순(기본), true=직군별
    // 승인/퇴출은 한 번 선택 후 confirm 단계를 거친다
    @State private var approveTarget: Profile?
    @State private var revokeTarget: Profile?

    private var members: [Profile] {
        vm.profilesById.values
            .filter { $0.role != "superadmin" }
            .sorted {
                if byType, $0.memberType != $1.memberType { return $0.memberType < $1.memberType }
                return $0.name < $1.name
            }
    }

    // 직군별: 등장 순서 유지하며 그룹화
    private var groups: [(String, [Profile])] {
        var order: [String] = []
        var dict: [String: [Profile]] = [:]
        for p in members {
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

            Text("미승인 → ‘승인’, 승인됨 → ‘퇴출’. 줄 순서는 가나다순으로 유지됩니다. (전체관리자 제외)")
                .font(.system(size: 12)).foregroundColor(Moim.sub)
                .padding(.bottom, 12)

            if members.isEmpty {
                Text("회원 정보가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
            } else if byType {
                ForEach(groups, id: \.0) { g in
                    Text("\(g.0) · \(g.1.count)")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(typeColor(g.0))
                        .padding(.top, 4).padding(.bottom, 6)
                    ForEach(g.1) { p in approvalRow(p) }
                }
            } else {
                ForEach(members) { p in approvalRow(p) }
            }
        }
        // 승인 confirm
        .confirmationDialog("‘\(approveTarget?.name ?? "")’ 님의 가입을 승인할까요?\n승인하면 앱을 바로 이용할 수 있습니다.",
                            isPresented: Binding(get: { approveTarget != nil }, set: { if !$0 { approveTarget = nil } }),
                            titleVisibility: .visible) {
            Button("승인") { if let p = approveTarget { vm.setApproved(p.id, true) }; approveTarget = nil }
            Button("취소", role: .cancel) { approveTarget = nil }
        }
        // 퇴출 confirm
        .confirmationDialog("‘\(revokeTarget?.name ?? "")’ 님을 퇴출할까요?\n다시 승인 대기 상태가 되어 앱을 이용할 수 없습니다.",
                            isPresented: Binding(get: { revokeTarget != nil }, set: { if !$0 { revokeTarget = nil } }),
                            titleVisibility: .visible) {
            Button("퇴출", role: .destructive) { if let p = revokeTarget { vm.setApproved(p.id, false) }; revokeTarget = nil }
            Button("취소", role: .cancel) { revokeTarget = nil }
        }
    }

    private func approvalRow(_ p: Profile) -> some View {
        let approved = (p.approved == true)
        let stColor = approved ? catColor("work") : Moim.admin
        return HStack(spacing: 11) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(p.name).font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink)
                    // 상태 분류: 대기 / 승인됨 (줄은 안 움직이고 칩으로 구분)
                    Text(approved ? "승인됨" : "대기")
                        .font(.system(size: 9.5, weight: .bold)).foregroundColor(stColor)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(stColor.opacity(0.12)).clipShape(Capsule())
                }
                Text("\(p.memberType) · \(roleLabel(p.role))").font(.system(size: 11.5)).foregroundColor(Moim.sub)
            }
            Spacer()
            if approved {
                Button { revokeTarget = p } label: {
                    Text("퇴출").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Moim.admin).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button { approveTarget = p } label: {
                    Text("승인").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(catColor("work")).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 9)
    }
}
