import SwiftUI
import PhotosUI

// 방표식 아바타 — 사진이 있으면 사진, 없으면 색상+이름
struct RoomAvatarView: View {
    let room: Room
    var size: CGFloat = 48
    var corner: CGFloat = 16
    var font: CGFloat = 10.5
    var body: some View {
        if let u = room.iconUrl, !u.isEmpty, let url = URL(string: u) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { roomColor(room) }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: corner))
        } else {
            Text(room.name)
                .font(.system(size: font, weight: .heavy)).foregroundColor(.white)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6).padding(2)
                .frame(width: size, height: size)
                .background(roomColor(room)).clipShape(RoundedRectangle(cornerRadius: corner))
        }
    }
}

// 사람(프로필) 아바타 — 사진 > 색상 > 직군색 + 이름 머리글자
struct PersonAvatarView: View {
    let profile: Profile?
    var size: CGFloat = 42
    var corner: CGFloat = 13
    var font: CGFloat = 13
    var body: some View {
        if let u = profile?.avatarUrl, !u.isEmpty, let url = URL(string: u) {
            AsyncImage(url: url) { img in img.resizable().scaledToFill() } placeholder: { personColor(profile) }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: corner))
        } else {
            Text(initials(profile?.name))
                .font(.system(size: font, weight: .bold)).foregroundColor(.white)
                .frame(width: size, height: size)
                .background(personColor(profile)).clipShape(RoundedRectangle(cornerRadius: corner))
        }
    }
}

// 직군·자기소개 — 구성원 초대·모임방 만들기 등에서 작은 글씨로
struct MemberTypeIntroLines: View {
    let profile: Profile
    var body: some View {
        Text(profile.memberType).font(.system(size: 11)).foregroundColor(Moim.sub)
        if let intro = profile.intro, !intro.isEmpty {
            Text(intro).font(.system(size: 11)).foregroundColor(Moim.sub).lineLimit(1)
        }
    }
}

// 회원 검색·관리 행의 연락처 줄 — 이메일·전화번호를 작은 글씨로 (있는 것만)
struct MemberContactLines: View {
    let profile: Profile
    var body: some View {
        if let email = profile.email, !email.isEmpty {
            Text("✉ \(email)").font(.system(size: 11)).foregroundColor(Moim.sub).lineLimit(1)
        }
        if let phone = profile.phone, !phone.isEmpty {
            Text("☎ \(phone)").font(.system(size: 11)).foregroundColor(Moim.sub).lineLimit(1)
        }
    }
}

// 1:1 대화 행 스와이프 삭제 — 왼쪽으로 밀면 빨간 '삭제' 배경이 보이고 임계치 넘으면 onDelete 호출
struct DMSwipeRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0

    var body: some View {
        content
            .background(Moim.paper)
            .background(alignment: .trailing) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("🗑 삭제")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 110)
                        .frame(maxHeight: .infinity)
                        .background(Moim.admin)
                }
            }
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { v in if v.translation.width < 0 { offset = max(v.translation.width, -110) } }
                    .onEnded { v in
                        if v.translation.width < -70 { onDelete() }
                        withAnimation(.easeOut(duration: 0.15)) { offset = 0 }
                    }
            )
            .clipped()
    }
}

// 방 목록 행 구분선 — web .room border-bottom 과 동일(행 아래 전체 너비)
private struct RoomListRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Moim.line.opacity(0.4))
            .frame(height: 1 / UIScreen.main.scale)
            .frame(maxWidth: .infinity)
    }
}

// 방표식(색상·사진) 편집기 — 생성/이름변경 공통 (사진 선택 → AvatarAdjustView)
struct RoomAppearanceEditor: View {
    let name: String
    @Binding var color: String
    @Binding var previewData: Data?
    /// 부모(RoomView·CreateRoomView)에서 AvatarAdjustView 표시 — 시트 안 fullScreenCover 는 iOS 에서 동작 안 함
    @Binding var adjustSourceImage: UIImage?
    let existingIconUrl: String?
    let onClear: () -> Void
    var onPhotoConfirmed: (() -> Void)? = nil
    /// true 면 자르기 화면 없이 선택 즉시 미리보기로 사용(web 방식). 시트(이름변경)처럼
    /// 부모 fullScreenCover 가 가려져 안 뜨는 경우에 사용.
    var directPhoto: Bool = false

    @State private var photoItem: PhotosPickerItem?
    @State private var photoPickToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("방표식 색상").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ROOM_COLORS, id: \.self) { hex in
                        let sel = hex.lowercased() == color.lowercased()
                        RoundedRectangle(cornerRadius: 8).fill(Color(hexString: hex) ?? Moim.sub)
                            .frame(width: 30, height: 30)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Moim.ink, lineWidth: sel ? 3 : 0))
                            .onTapGesture { color = hex }
                    }
                }.padding(.vertical, 2)
            }
            Text("방표식 사진 (선택)").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
            HStack(spacing: 10) {
                Group {
                    if let d = previewData, let ui = UIImage(data: d) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else if let u = existingIconUrl, let url = URL(string: u) {
                        AsyncImage(url: url) { i in i.resizable().scaledToFill() } placeholder: { Color(hexString: color) ?? Moim.sub }
                    } else {
                        Color(hexString: color) ?? Moim.sub
                    }
                }
                .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 12))
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("사진 선택").font(.system(size: 13, weight: .bold)).foregroundColor(Moim.accent)
                }
                if previewData != nil || existingIconUrl != nil {
                    Button("제거") { onClear() }.font(.system(size: 13, weight: .bold)).foregroundColor(Moim.admin)
                }
            }
        }
        .onChange(of: photoItem) { newItem in
            if newItem != nil { photoPickToken += 1 }
        }
        .task(id: photoPickToken) {
            guard photoPickToken > 0, let item = photoItem else { return }
            defer { photoItem = nil }
            do {
                guard let picked = try await item.loadTransferable(type: PickedPhoto.self) else { return }
                if directPhoto {
                    // web 방식: 자르기 없이 선택 즉시 미리보기 → 저장 시 업로드
                    if let data = squareThumbnailData(picked.image) {
                        previewData = data
                        onPhotoConfirmed?()
                    }
                } else {
                    adjustSourceImage = picked.image
                }
            } catch {
                guard !(error is CancellationError) else { return }
            }
        }
    }
}

struct RoomListView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject var vm: MoimViewModel
    let onOpen: (Room) -> Void
    let onAdmin: () -> Void
    let onWard: () -> Void
    let onCreateRoom: () -> Void
    let onSettings: () -> Void
    @State private var dmToDelete: Room?   // 1:1 대화 스와이프 삭제 대상

    private var pendingApprovalCount: Int {
        vm.profilesById.values.filter(isSignupPending).count
    }

    // 주간 학술활동(default_view=week)은 목록에서 빼고 별도 바로 표시. 나머지는 전체방(첫번째)+모임방 평면 목록.
    private var weekRoom: Room? {
        vm.rooms.first { $0.category != "custom" && $0.defaultView == "week" }
    }
    // 전체공지(맨 위 고정) + 고정(핀) 우선 + 나머지는 최근 메시지순
    private var listRooms: [Room] {
        // 과 전체공지 방은 항상 맨 위 고정(핀·정렬 대상에서 제외)
        let notice = noticeTopRoom(vm.rooms)
        let bugReport = bugReportRoom(vm.rooms)
        // 홈 목록: 기본 방은 항상, 모임방(custom)·DM(direct)은 내가 가입한 것만 (관리자 콘솔은 전체 vm.rooms 사용)
        let flat = vm.rooms.filter {
            $0.id != weekRoom?.id && $0.id != notice?.id && $0.id != bugReport?.id &&
            (($0.category != "custom" && $0.category != "direct") || vm.myRoomIds.contains($0.id))
        }
        let pinned = vm.roomPins.compactMap { id in flat.first { $0.id == id } }
        let pinnedIds = Set(pinned.map { $0.id })
        let rest = flat.filter { !pinnedIds.contains($0.id) }.sorted {
            let a = vm.lastMsgByRoom[$0.id]?.createdAt ?? ""
            let b = vm.lastMsgByRoom[$1.id]?.createdAt ?? ""
            if a != b { return a > b }
            return $0.sortOrder < $1.sortOrder
        }
        return pinned + rest   // 과 전체공지는 맨 위 고정 바로 별도 표시(목록 행에서 제외)
    }
    private var noticeRoom: Room? { noticeTopRoom(vm.rooms) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    RoomListTopTriBar(
                        noticeRoom: noticeRoom,
                        noticeUnread: noticeRoom.map { vm.unreadByRoom[$0.id] ?? 0 } ?? 0,
                        weekRoom: weekRoom,
                        weekUnread: weekRoom.map { vm.unreadByRoom[$0.id] ?? 0 } ?? 0,
                        onNotice: { if let nr = noticeRoom { onOpen(nr) } },
                        onWard: onWard,
                        onWeek: { if let wr = weekRoom { onOpen(wr) } }
                    )
                    createButton
                    if listRooms.isEmpty {
                        EmptyBox(emoji: "🔒", title: "아직 방이 없어요",
                                 subtitle: "전체관리자가 방에 배정하면\n여기에 표시됩니다.")
                    } else {
                        ForEach(listRooms) { room in
                            VStack(spacing: 0) {
                                if room.category == "direct" {
                                    DMSwipeRow(onDelete: { dmToDelete = room }) {
                                        RoomRow(vm: vm, room: room, unread: vm.unreadByRoom[room.id] ?? 0, lastMsg: vm.lastMsgByRoom[room.id], onOpen: onOpen)
                                    }
                                } else {
                                    RoomRow(vm: vm, room: room, unread: vm.unreadByRoom[room.id] ?? 0, lastMsg: vm.lastMsgByRoom[room.id], onOpen: onOpen)
                                }
                                RoomListRowDivider()
                            }
                        }
                    }
                }
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        // 1:1 대화 삭제 — 확인 후 본인 참여만 제거(상대·이력 유지, 재오픈 시 복구)
        .confirmationDialog("이 대화를 목록에서 삭제할까요?\n상대는 그대로이며, 다시 메시지하면 이전 대화가 복구됩니다.",
                            isPresented: Binding(get: { dmToDelete != nil }, set: { if !$0 { dmToDelete = nil } }),
                            titleVisibility: .visible) {
            Button("삭제", role: .destructive) { if let r = dmToDelete { vm.leaveRoom(r) {} }; dmToDelete = nil }
            Button("취소", role: .cancel) { dmToDelete = nil }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("아주 정신").font(.system(size: 20, weight: .heavy)).foregroundColor(Moim.ink)
                Text(viewBadgeText(vm.myProfile))
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(theme.dark ? Moim.sub : Moim.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(theme.dark ? Moim.white : Moim.yellow)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(theme.dark ? Moim.line : Color.clear, lineWidth: 1))
                Spacer()
                // 관리자 진입: admin·비서='가입승인' / superadmin='관리자모드'
                if vm.myProfile?.role == "superadmin" {
                    Button("관리자모드") { onAdmin() }.font(.system(size: 12, weight: .bold)).foregroundColor(Moim.admin)
                } else if vm.myProfile?.role == "admin" || vm.myProfile?.memberType == "비서" {
                    Button("가입승인") { onAdmin() }.font(.system(size: 12, weight: .bold)).foregroundColor(Moim.admin)
                }
                // 설정(⚙️): 내 정보 / 방 순서 / 회원 검색 + 회원 탈퇴
                Button(action: onSettings) { Text("⚙️").font(.system(size: 16)) }
                Button("로그아웃") { vm.logout() }.font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            Divider().background(Moim.line)
        }
        .background(Moim.paper)
    }

    private var bugReport: Room? { bugReportRoom(vm.rooms) }

    private var createButton: some View {
        let brUnread = bugReport.map {
            effectiveRoomUnread(roomId: $0.id, count: vm.unreadByRoom[$0.id] ?? 0, role: vm.myProfile?.role)
        } ?? 0
        return HStack(spacing: 10) {
            if let br = bugReport {
                Button(action: { onOpen(br) }) {
                    ZStack(alignment: .topTrailing) {
                        Text("BugReport")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.admin)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 10))
                        if brUnread > 0 {
                            UnreadBadge(count: brUnread).padding(.top, 2).padding(.trailing, 6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Button(action: onCreateRoom) {
                Text("＋ 모임방 만들기")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
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
                    Text(pending > 0 ? "회원/방 · 가입 승인 대기 \(pending)명" : "회원/방 · 가입 승인")
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

// 방목록 상단 — 전체공지 · 병실현황 · 학술활동 한 줄 3분할
struct RoomListTopTriBar: View {
    @ObservedObject private var theme = ThemeManager.shared
    let noticeRoom: Room?
    var noticeUnread: Int = 0
    let weekRoom: Room?
    var weekUnread: Int = 0
    let onNotice: () -> Void
    let onWard: () -> Void
    let onWeek: () -> Void

    var body: some View {
        Group {
            if theme.dark {
                HStack(spacing: 8) {
                    triSegPill(label: "전체공지", unread: noticeUnread, enabled: noticeRoom != nil, action: onNotice)
                    triSegPill(label: "병실현황", unread: 0, enabled: true, action: onWard)
                    triSegPill(label: "학술활동", unread: weekUnread, enabled: weekRoom != nil, action: onWeek)
                }
            } else {
                HStack(spacing: 0) {
                    triSeg(label: "전체공지", color: Color(hex: 0xB5651D), unread: noticeUnread, enabled: noticeRoom != nil, action: onNotice)
                    Rectangle().fill(Color.white.opacity(0.28)).frame(width: 1)
                    triSeg(label: "병실현황", color: Moim.orange, unread: 0, enabled: true, action: onWard)
                    Rectangle().fill(Color.white.opacity(0.28)).frame(width: 1)
                    triSeg(label: "학술활동", color: Color(hex: 0x4A6FA5), unread: weekUnread, enabled: weekRoom != nil, action: onWeek)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 10)
    }

    /// 다크 — 병실현황 잔여병실·당직표 세그먼트와 동일
    private func triSegPill(label: String, unread: Int, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(enabled ? Moim.ink : Moim.ink.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                if unread > 0 {
                    UnreadBadge(count: unread).padding(.top, 4).padding(.trailing, 4)
                }
            }
            .background(Moim.white.opacity(enabled ? 1 : 0.45))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func triSeg(label: String, color: Color, unread: Int, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(enabled ? Moim.ink : Moim.ink.opacity(0.45))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                if unread > 0 {
                    UnreadBadge(count: unread).padding(.top, 4).padding(.trailing, 4)
                }
            }
            .background(color.opacity(enabled ? 1 : 0.45))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// 방 목록 맨 위 고정 배너 (레거시·미사용)
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

// 과 전체공지 고정 바 (맨 위, 잔여병실현황·주간학술활동과 동일한 색 바 형식)
struct NoticeRoomBar: View {
    let room: Room
    var unread: Int = 0
    let onOpen: (Room) -> Void
    var body: some View {
        Button(action: { onOpen(room) }) {
            HStack {
                Text("📢").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text(room.name).font(.system(size: 16, weight: .heavy)).foregroundColor(.white)
                    Text("과 전체공지").font(.system(size: 11.5)).foregroundColor(Color(hex: 0xF3E2D2))
                }
                Spacer()
                if unread > 0 { UnreadBadge(count: unread) }
                Text("›").font(.system(size: 20)).foregroundColor(.white)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color(hex: 0xB5651D))
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
            Text(name).font(.system(size: 12, weight: .semibold)).foregroundColor(moimToggleText(selected: true, lightOn: .white, lightOff: Moim.ink))
        }
        .padding(.leading, 5).padding(.trailing, 10).padding(.vertical, 5)
        .background(moimToggleBg(selected: true, lightOn: Moim.accent))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(ThemeManager.shared.dark ? moimToggleBorder(selected: true) : Color.clear, lineWidth: 1))
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
    @ObservedObject var vm: MoimViewModel
    let room: Room
    var unread: Int = 0
    var lastMsg: LastMsg? = nil
    let onOpen: (Room) -> Void

    private var isDM: Bool { room.category == "direct" }
    private var other: Profile? { isDM ? vm.dmOther(room) : nil }

    var body: some View {
        Button { onOpen(room) } label: {
            HStack(spacing: 12) {
                if isDM { PersonAvatarView(profile: other, size: 48, corner: 16) }
                else { RoomAvatarView(room: room) }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(isDM ? "1:1" : catLabel(room.category))
                            .font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(isDM ? Color(hex: 0x7A8A99) : catColor(room.category)).clipShape(RoundedRectangle(cornerRadius: 5))
                        Text(isDM ? vm.roomDisplayName(room) : room.name).font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
                    }
                    Text(msgPreview(lastMsg).isEmpty
                         ? (isDM ? (other?.memberType ?? "") : (room.postPolicy == "restricted" ? "공지 · 관리자" : ""))
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

// 방 순서(핀) 설정 — 최대 5개 고정·드래그 재정렬 (설정 화면 '방 순서' 탭에 임베드)
struct PinOrderTab: View {
    @ObservedObject var vm: MoimViewModel
    let rooms: [Room]
    @State private var draft: [String] = []
    @State private var saving = false
    @State private var savedAt: Date?   // 저장 완료 표시

    var body: some View {
        List {
            if let notice = noticeTopRoom(vm.rooms) {
                Section("항상 맨 위 (변경 불가)") {
                    HStack {
                        Text("📌 \(vm.roomDisplayName(notice))").lineLimit(1)
                        Spacer()
                        Text("고정됨").foregroundColor(Moim.sub).font(.system(size: 12))
                    }
                }
            }
            Section("고정된 방 (\(draft.count)/5) · ☰ 드래그로 순서 변경") {
                if draft.isEmpty {
                    Text("고정된 방 없음").foregroundColor(Moim.sub).font(.system(size: 13))
                }
                ForEach(Array(draft.enumerated()), id: \.element) { idx, id in
                    if let r = rooms.first(where: { $0.id == id }) {
                        HStack {
                            Text("\(idx + 1). \(vm.roomDisplayName(r))").lineLimit(1)
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
                        Text(vm.roomDisplayName(r)).lineLimit(1)
                        Spacer()
                        Button("📌 고정") { if draft.count < 5 { draft.append(r.id) } }
                            .buttonStyle(.borderless)
                            .disabled(draft.count >= 5)
                    }
                }
            }
            Section {
                Button {
                    guard !saving else { return }
                    saving = true; savedAt = nil
                    vm.saveRoomPins(draft) { ok in
                        saving = false
                        if ok { savedAt = Date() }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if saving {
                            ProgressView()
                            Text("저장 중…").font(.system(size: 14, weight: .bold))
                        } else if savedAt != nil {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(Moim.success)
                            Text("저장됨").font(.system(size: 14, weight: .bold)).foregroundColor(Moim.success)
                        } else {
                            Text("순서 저장").font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .disabled(saving)
            }
        }
        // 항상 재정렬 가능(드래그 핸들 ☰ 표시)
        .environment(\.editMode, .constant(.active))
        .onAppear { draft = vm.roomPins.filter { id in rooms.contains { $0.id == id } } }
        .onChange(of: draft) { _ in savedAt = nil }   // 다시 편집하면 '저장됨' 해제
    }
}
