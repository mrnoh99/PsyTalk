import SwiftUI

struct RoomListView: View {
    @ObservedObject var vm: MoimViewModel
    let onOpen: (Room) -> Void
    let onAdmin: () -> Void
    let onWard: () -> Void
    let onCreateRoom: () -> Void

    private var defaultRooms: [Room] {
        vm.rooms.filter { $0.category != "custom" }.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var customRooms: [Room] {
        vm.rooms.filter { $0.category == "custom" }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    WardStatusBanner(onTap: onWard)

                    if vm.rooms.isEmpty {
                        EmptyBox(emoji: "🔒", title: "아직 들어간 방이 없어요",
                                 subtitle: "전체관리자가 방에 배정하면\n여기에 표시됩니다.")
                    } else {
                        if !defaultRooms.isEmpty {
                            SectionHead(title: "📌 기본 방 (우선순위)")
                            ForEach(defaultRooms) { RoomRow(room: $0, onOpen: onOpen) }
                        }
                        SectionHead(
                            title: "👥 모임 방",
                            action: "＋ 만들기",
                            onAction: onCreateRoom
                        )
                        if customRooms.isEmpty {
                            Text("아직 모임방이 없습니다.")
                                .font(.system(size: 13)).foregroundColor(Moim.sub)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 18).padding(.vertical, 12)
                        } else {
                            ForEach(customRooms) { RoomRow(room: $0, onOpen: onOpen) }
                        }
                    }
                }
            }
            if let p = vm.myProfile, isSuperAdmin(p.role) { adminBar }
        }
        .background(Moim.paper.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("아주 정신").font(.system(size: 20, weight: .heavy)).foregroundColor(Moim.ink)
                Text(viewBadgeText(vm.myProfile))
                    .font(.system(size: 10.5, weight: .bold)).foregroundColor(Moim.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Moim.yellow).clipShape(Capsule())
                Spacer()
                Button("로그아웃") { vm.logout() }.font(.system(size: 12))
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            Divider().background(Moim.line)
            if let p = vm.myProfile {
                HStack(spacing: 7) {
                    Text("👁").font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                    ViewChip(name: p.name, memberType: p.memberType)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color(hex: 0xFFF8E0))
                Divider().background(Moim.line)
            }
        }
        .background(Moim.paper)
    }

    private var adminBar: some View {
        Button(action: onAdmin) {
            HStack(spacing: 10) {
                Text("🛡").font(.system(size: 15))
                    .frame(width: 32, height: 32).background(Moim.admin)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("관리자 콘솔").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text("전체관리자 전용 · 멤버/방/권한").font(.system(size: 11)).foregroundColor(Color(hex: 0xBDB4AB))
                }
                Spacer()
                Text("›").foregroundColor(Color(hex: 0xBDB4AB)).font(.system(size: 18))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(Moim.accent)
        }
    }
}

// 방 목록 맨 위 고정 배너
struct WardStatusBanner: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("🛏").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("병실 잔여 현황").font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                    Text("남 · 여 잔여 병상 보기").font(.system(size: 11.5)).foregroundColor(Color(hex: 0xFFE9D6))
                }
                Spacer()
                Text("›").font(.system(size: 20)).foregroundColor(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Moim.orange)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
    }
}

struct ViewChip: View {
    let name: String
    let memberType: String
    var body: some View {
        HStack(spacing: 5) {
            Text(String(memberType.prefix(1)))
                .font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                .frame(width: 19, height: 19)
                .background(typeColor(memberType)).clipShape(RoundedRectangle(cornerRadius: 6))
            Text(name).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
        }
        .padding(.leading, 5).padding(.trailing, 10).padding(.vertical, 5)
        .background(Moim.accent).clipShape(Capsule())
    }
}

struct SectionHead: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .heavy)).foregroundColor(Moim.sub)
            Spacer()
            if let action = action, let onAction = onAction {
                Button(action: onAction) {
                    Text(action).font(.system(size: 11, weight: .bold)).foregroundColor(Moim.accent)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)
    }
}

struct RoomRow: View {
    let room: Room
    let onOpen: (Room) -> Void
    var body: some View {
        Button { onOpen(room) } label: {
            HStack(spacing: 12) {
                Text(room.category != "custom" ? room.name : "#")
                    .font(.system(size: 10.5, weight: .heavy)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(2)
                    .frame(width: 48, height: 48)
                    .background(catColor(room.category)).clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(catLabel(room.category))
                            .font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(catColor(room.category)).clipShape(RoundedRectangle(cornerRadius: 5))
                        Text(room.name).font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
                    }
                    Text(room.postPolicy == "restricted" ? "공지 · 관리자/지정작성자" : "멤버 누구나")
                        .font(.system(size: 12.5)).foregroundColor(Moim.sub).lineLimit(1)
                }
                Spacer()
                Text("›").foregroundColor(Moim.sub).font(.system(size: 20))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        Divider().background(Moim.line.opacity(0.4)).padding(.leading, 18)
    }
}

struct EmptyBox: View {
    let emoji: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 6) {
            Text(emoji).font(.system(size: 38)).opacity(0.5)
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
            Text(subtitle).multilineTextAlignment(.center)
                .font(.system(size: 13)).foregroundColor(Moim.sub)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50).padding(.horizontal, 30)
    }
}
