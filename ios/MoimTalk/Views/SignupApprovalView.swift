import SwiftUI

// 가입 승인 전용 — Android ApprovalScreen 과 동일
struct SignupApprovalView: View {
    @ObservedObject var vm: MoimViewModel

    private var members: [Profile] {
        vm.profilesById.values.sorted {
            let a = ($0.approved ?? true) ? 1 : 0
            let b = ($1.approved ?? true) ? 1 : 0
            if a != b { return a < b }
            if $0.role != $1.role { return $0.role < $1.role }
            return $0.name < $1.name
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("미승인자가 위에 표시됩니다. 승인하면 앱을 이용할 수 있습니다.")
                .font(.system(size: 12)).foregroundColor(Moim.sub)
                .padding(.bottom, 12)

            if members.isEmpty {
                Text("멤버 정보가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
            } else {
                ForEach(members) { p in approvalRow(p) }
            }
        }
    }

    private func approvalRow(_ p: Profile) -> some View {
        HStack(spacing: 11) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink)
                Text("\(p.memberType) · \(roleLabel(p.role))").font(.system(size: 11.5)).foregroundColor(Moim.sub)
            }
            Spacer()
            if p.approved == false {
                Button { vm.setApproved(p.id, true) } label: {
                    Text("승인").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(catColor("work")).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button { vm.setApproved(p.id, false) } label: {
                    Text("✓ 승인취소").font(.system(size: 11.5, weight: .bold)).foregroundColor(Moim.sub)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Moim.bg).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 9)
    }
}
