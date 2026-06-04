import SwiftUI

// 관리자 콘솔 (전체관리자) — iPad/Mac 관리 프로그램 용도
// 멤버(직군·역할) 목록 + 방 목록. Android/웹의 관리자 콘솔과 동일.
struct AdminPlaceholderView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void

    private var members: [Profile] {
        vm.profilesById.values.sorted { ($0.role, $0.name) < ($1.role, $1.name) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)).foregroundColor(.white) }
                Text("관리자 콘솔").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    card(title: "👥 멤버 (직군·역할) · \(members.count)명") {
                        if members.isEmpty {
                            Text("멤버 정보가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
                        } else {
                            ForEach(members) { p in memberRow(p) }
                        }
                    }
                    card(title: "🏠 방 목록 · \(vm.rooms.count)개") {
                        ForEach(vm.rooms) { r in roomRow(r) }
                    }
                }
                .padding(16)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 11.5, weight: .heavy)).foregroundColor(Moim.sub).padding(.bottom, 11)
            content()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func memberRow(_ p: Profile) -> some View {
        let role: (Color, String) = p.role == "superadmin" ? (Moim.admin, "전체관리자")
            : p.role == "admin" ? (Color(hex: 0xB5651D), "관리자") : (Moim.line, "멤버")
        return HStack(spacing: 10) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(Moim.ink)
                Text(p.memberType).font(.system(size: 11.5)).foregroundColor(Moim.sub)
            }
            Spacer()
            // 전체관리자만 역할 직접 지정 (SQL 없이)
            Menu {
                Button("전체관리자") { vm.setRole(p.id, to: "superadmin") }
                Button("관리자") { vm.setRole(p.id, to: "admin") }
                Button("멤버") { vm.setRole(p.id, to: "user") }
            } label: {
                HStack(spacing: 3) {
                    Text(role.1).font(.system(size: 10, weight: .bold))
                        .foregroundColor(p.role == "user" ? Moim.accent : .white)
                    Text("▾").font(.system(size: 8))
                        .foregroundColor(p.role == "user" ? Moim.accent : .white)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(role.0).clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
    }

    private func roomRow(_ r: Room) -> some View {
        HStack(spacing: 10) {
            Text(r.category != "custom" ? "\(r.sortOrder)" : "#")
                .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(catColor(r.category)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(r.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(Moim.ink)
                Text("\(catLabel(r.category)) · \(r.postPolicy)").font(.system(size: 11.5)).foregroundColor(Moim.sub)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
    }
}
