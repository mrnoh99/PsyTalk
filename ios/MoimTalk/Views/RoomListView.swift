import SwiftUI

struct RoomListView: View {
    @ObservedObject var vm: MoimViewModel
    let onOpen: (Room) -> Void
    let onAdmin: () -> Void
    let onWard: () -> Void
    let onCreateRoom: () -> Void
    @State private var showPinSettings = false

    private var pendingApprovalCount: Int {
        vm.profilesById.values.filter { $0.approved == false }.count
    }

    // 주간 학술활동(default_view=week)은 목록에서 빼고 별도 바로 표시. 나머지는 전체방(첫번째)+모임방 평면 목록.
    private var weekRoom: Room? {
        vm.rooms.first { $0.category != "custom" && $0.defaultView == "week" }
    }
    // 고정(핀) 우선 + 나머지는 최근 메시지순
    private var listRooms: [Room] {
        let flat = vm.rooms.filter { $0.id != weekRoom?.id }
        let pinned = vm.roomPins.compactMap { id in flat.first { $0.id == id } }
        let pinnedIds = Set(pinned.map { $0.id })
        let rest = flat.filter { !pinnedIds.contains($0.id) }.sorted {
            let a = vm.lastMsgByRoom[$0.id]?.createdAt ?? ""
            let b = vm.lastMsgByRoom[$1.id]?.createdAt ?? ""
            if a != b { return a > b }
            return $0.sortOrder < $1.sortOrder
        }
        return pinned + rest
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
                        ForEach(listRooms) { RoomRow(room: $0, unread: vm.unreadByRoom[$0.id] ?? 0, lastMsg: vm.lastMsgByRoom[$0.id], onOpen: onOpen) }
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
                // 설정(⚙️): 방 순서 + 회원 탈퇴·로그아웃
                Button { showPinSettings = true } label: { Text("⚙️").font(.system(size: 16)) }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            Divider().background(Moim.line)
        }
        .sheet(isPresented: $showPinSettings) {
            PinSettingsView(vm: vm, rooms: vm.rooms.filter { $0.id != weekRoom?.id })
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
    var lastMsg: LastMsg? = nil
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
                    Text(msgPreview(lastMsg).isEmpty
                         ? (room.postPolicy == "restricted" ? "공지 · 관리자/지정작성자" : "")
                         : msgPreview(lastMsg))
                        .font(.system(size: 12.5)).foregroundColor(Moim.sub).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    let t = fmtListTime(lastMsg?.createdAt)
                    if !t.isEmpty { Text(t).font(.system(size: 11)).foregroundColor(Moim.sub) }
                    if unread > 0 { UnreadBadge(count: unread) }
                }
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

// 방 순서(핀) 설정 — 최대 5개 고정·드래그 재정렬 + 회원 탈퇴·로그아웃
struct PinSettingsView: View {
    @ObservedObject var vm: MoimViewModel
    let rooms: [Room]
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [String] = []
    @State private var showDelete = false

    var body: some View {
        NavigationView {
            List {
                // 회원 탈퇴 · 로그아웃 (방 순서 위)
                Section {
                    Button("로그아웃") { dismiss(); vm.logout() }
                        .foregroundColor(Moim.sub)
                    // 전체관리자(superadmin)는 탈퇴 불가
                    if !vm.isSuperAdmin {
                        Button("회원 탈퇴") { showDelete = true }
                            .foregroundColor(Moim.admin)
                    }
                }
                Section("고정된 방 (\(draft.count)/5) · ☰ 드래그로 순서 변경") {
                    if draft.isEmpty {
                        Text("고정된 방 없음").foregroundColor(Moim.sub).font(.system(size: 13))
                    }
                    ForEach(Array(draft.enumerated()), id: \.element) { idx, id in
                        if let r = rooms.first(where: { $0.id == id }) {
                            HStack {
                                Text("\(idx + 1). \(r.name)").lineLimit(1)
                                Spacer()
                                Button(role: .destructive) { draft.removeAll { $0 == id } } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                            }
                        }
                    }
                    .onMove { from, to in draft.move(fromOffsets: from, toOffset: to) }
                }
                Section("방 목록") {
                    ForEach(rooms.filter { !draft.contains($0.id) }) { r in
                        HStack {
                            Text(r.name).lineLimit(1)
                            Spacer()
                            Button("📌 고정") { if draft.count < 5 { draft.append(r.id) } }
                                .buttonStyle(.borderless)
                                .disabled(draft.count >= 5)
                        }
                    }
                }
            }
            // 항상 재정렬 가능(드래그 핸들 ☰ 표시)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("방 순서 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { vm.saveRoomPins(draft); dismiss() } }
            }
            .onAppear { draft = vm.roomPins.filter { id in rooms.contains { $0.id == id } } }
            .alert("회원 탈퇴", isPresented: $showDelete) {
                Button("취소", role: .cancel) {}
                Button("탈퇴", role: .destructive) { dismiss(); vm.deleteAccount() }
            } message: {
                Text("정말 탈퇴할까요?\n계정과 내 데이터(보낸 메시지·올린 자료 등)가 삭제되며 되돌릴 수 없습니다.")
            }
        }
    }
}
