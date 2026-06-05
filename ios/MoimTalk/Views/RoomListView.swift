import SwiftUI

struct RoomListView: View {
    @ObservedObject var vm: MoimViewModel
    let onOpen: (Room) -> Void
    let onAdmin: () -> Void
    let onWard: () -> Void
    let onCreateRoom: () -> Void

    private var pendingApprovalCount: Int {
        vm.profilesById.values.filter { $0.approved == false }.count
    }

    // 주간 학술활동(default_view=week)은 목록에서 빼고 별도 바로 표시. 나머지는 전체방(첫번째)+모임방 평면 목록.
    private var weekRoom: Room? {
        vm.rooms.first { $0.category != "custom" && $0.defaultView == "week" }
    }
    private var listRooms: [Room] {
        vm.rooms.filter { $0.id != weekRoom?.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    WardStatusBanner(onTap: onWard)
                    if let wr = weekRoom { WeekRoomBar(room: wr, unread: vm.unreadByRoom[wr.id] ?? 0, onOpen: onOpen) }
                    createButton
                    if listRooms.isEmpty {
                        EmptyBox(emoji: "🔒", title: "아직 방이 없어요",
                                 subtitle: "전체관리자가 방에 배정하면\n여기에 표시됩니다.")
                    } else {
                        ForEach(listRooms) { RoomRow(room: $0, unread: vm.unreadByRoom[$0.id] ?? 0, onOpen: onOpen) }
                    }
                }
            }
            if let p = vm.myProfile, isSuperAdmin(p.role) { adminBar(pending: pendingApprovalCount) }
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
        }
        .background(Moim.paper)
    }

    private var createButton: some View {
        HStack {
            Spacer()
            Button(action: onCreateRoom) {
                Text("＋ 모임방 만들기")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.accent)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 4)
    }

    private func adminBar(pending: Int) -> some View {
        Button(action: onAdmin) {
            HStack(spacing: 10) {
                Text("🛡").font(.system(size: 15))
                    .frame(width: 32, height: 32).background(Moim.admin)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("관리자 콘솔").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    Text(pending > 0 ? "멤버/방 · 가입 승인 대기 \(pending)명" : "멤버/방 · 가입 승인")
                        .font(.system(size: 11)).foregroundColor(Color(hex: 0xBDB4AB))
                }
                Spacer()
                if pending > 0 {
                    Text("\(pending)")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Moim.admin).clipShape(Capsule())
                }
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
                    Text("잔여 병실 현황").font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
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

// 주간 학술활동 고정 바 (잔여 병실 현황 아래, 파란색)
struct WeekRoomBar: View {
    let room: Room
    var unread: Int = 0
    let onOpen: (Room) -> Void
    var body: some View {
        Button(action: { onOpen(room) }) {
            HStack {
                Text("📅").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text(room.name).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                    Text("주간 학술활동 · 일정 보기").font(.system(size: 11.5)).foregroundColor(Color(hex: 0xDDE6F3))
                }
                Spacer()
                if unread > 0 { UnreadBadge(count: unread) }
                Text("›").font(.system(size: 20)).foregroundColor(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(hex: 0x4A6FA5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 14).padding(.bottom, 10)
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

struct UnreadBadge: View {
    let count: Int
    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
            .padding(.horizontal, 6).frame(minWidth: 19, minHeight: 19)
            .background(Moim.admin).clipShape(Capsule())
    }
}

struct RoomRow: View {
    let room: Room
    var unread: Int = 0
    let onOpen: (Room) -> Void
    var body: some View {
        Button { onOpen(room) } label: {
            HStack(spacing: 12) {
                Text(room.name)
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
                if unread > 0 { UnreadBadge(count: unread) }
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
