import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct RoomView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let onBack: () -> Void

    @State private var tab: String
    @State private var input = ""
    @State private var showRename = false
    @State private var renameText = ""
    @State private var editColor = ROOM_COLORS[1]
    @State private var editIconData: Data?
    @State private var editIconCleared = false
    @State private var showSettings = false
    @State private var showLeave = false
    @State private var showDeleteRoom = false

    init(vm: MoimViewModel, room: Room, onBack: @escaping () -> Void) {
        self.vm = vm; self.room = room; self.onBack = onBack
        let startTab: String = {
            if isNoticeTopRoom(room, vm.rooms) { return "chat" }
            return opensWeekCalendar(room) ? "cal" : "chat"
        }()
        _tab = State(initialValue: startTab)
    }

    // 이름 변경이 반영되도록 최신 방 정보를 vm.rooms 에서 조회
    private var liveRoom: Room { vm.rooms.first { $0.id == room.id } ?? room }
    private var isDM: Bool { liveRoom.category == "direct" }
    private var canPost: Bool { isDM ? true : canPostInRoom(vm.myProfile, room) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if !tabItems.isEmpty {
                tabBar
            }
            Divider().background(Moim.line)

            switch tab {
            case "chat": ChatView(vm: vm, canPost: canPost, input: $input, roomId: liveRoom.id,
                                  noticeLayout: isNoticeTopRoom(liveRoom, vm.rooms),
                                  bugReportLayout: isBugReportRoom(liveRoom))
            case "files": FilesView(vm: vm, canUpload: canPost)
            default: CalendarView(vm: vm, room: liveRoom, canPost: canPost)
                .id(liveRoom.id)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .task(id: liveRoom.id) {
            tab = isNoticeTopRoom(liveRoom, vm.rooms) ? "chat"
                : (opensWeekCalendar(liveRoom) ? "cal" : "chat")
            if !isDM, showRoomHeaderMembers(liveRoom, vm.rooms) { vm.loadRoomMembers(liveRoom.id) }
            input = isBugReportRoom(liveRoom)
                ? (vm.replyTarget != nil ? "" : bugReportDraftFor(role: vm.myProfile?.role))
                : ""
        }
        .onChange(of: vm.replyTarget?.id) { _ in
            guard isBugReportRoom(liveRoom) else { return }
            input = vm.replyTarget != nil ? "" : bugReportDraftFor(role: vm.myProfile?.role)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onBack) { Text("‹").font(.system(size: 25)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.roomDisplayName(liveRoom))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Moim.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                // 개설자·참여자 이름 나열 (모임방 등 — DM·과 전체공지 제외)
                if !isDM, showRoomHeaderMembers(liveRoom, vm.rooms), vm.memberListRoomId == liveRoom.id {
                    let line = roomMemberNames(liveRoom, memberIds: vm.roomMemberIds, profiles: vm.profilesById).joined(separator: ", ")
                    if !line.isEmpty {
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundColor(Moim.sub)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            if !isDM, canRenameRoom(vm.myProfile, liveRoom) {
                Button("이름변경") {
                    renameText = liveRoom.name
                    editColor = liveRoom.color ?? ROOM_COLORS[1]
                    editIconData = nil; editIconCleared = false
                    showRename = true
                }
                .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.accent)
            }
            if !isDM, vm.canManageRoom(liveRoom) {
                Button {
                    vm.loadRoomMembers(liveRoom.id)
                    showSettings = true
                } label: {
                    Text("⚙️").font(.system(size: 17))
                }
            }
            // 본인이 만들지 않은 모임방: 나가기
            if !isDM, vm.canLeaveRoom(liveRoom) {
                Button("나가기") { showLeave = true }
                    .font(.system(size: 13)).foregroundColor(Moim.admin)
            }
            // 1:1 대화: 목록에서 삭제 — 우상단
            if isDM {
                Button("방삭제") { showDeleteRoom = true }
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.admin)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .background(Moim.paper)
        .sheet(isPresented: $showRename) {
            NavigationView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("방 이름", text: $renameText).textFieldStyle(.roundedBorder)
                    RoomAppearanceEditor(
                        name: renameText, color: $editColor,
                        previewData: $editIconData,
                        existingIconUrl: editIconCleared ? nil : liveRoom.iconUrl,
                        onClear: { editIconData = nil; editIconCleared = true },
                        onPhotoConfirmed: { editIconCleared = false }
                    )
                    Spacer()
                }
                .padding(16)
                .navigationTitle("방 정보 변경")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("취소") { showRename = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            vm.updateRoomAppearance(liveRoom, name: renameText, color: editColor, iconData: editIconData, iconName: "icon.jpg", clearIcon: editIconCleared) {}
                            showRename = false
                        }
                    }
                }
            }
        }
        .alert("방 나가기", isPresented: $showLeave) {
            Button("취소", role: .cancel) {}
            Button("나가기", role: .destructive) { vm.leaveRoom(liveRoom) { onBack() } }
        } message: {
            Text("'\(liveRoom.name)' 방에서 나갈까요?")
        }
        .alert("대화 삭제", isPresented: $showDeleteRoom) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) { vm.leaveRoom(liveRoom) { onBack() } }
        } message: {
            Text("이 대화를 목록에서 삭제할까요?\n상대는 그대로이며, 다시 메시지하면 이전 대화가 복구됩니다.")
        }
        .sheet(isPresented: $showSettings) {
            RoomSettingsView(vm: vm, room: liveRoom,
                             onClose: { showSettings = false },
                             onDeleted: { showSettings = false; onBack() })
        }
    }

    // 자료실·캘린더·채팅 탭 — 주간 학술활동 등 기본 방만. 과 전체공지·모임방·1:1은 채팅만.
    private var tabItems: [(String, String)] {
        if isDM || room.category == "custom" { return [] }
        if isNoticeTopRoom(liveRoom, vm.rooms) { return [] }
        if isBugReportRoom(liveRoom) { return [] }
        return [("chat", "💬 채팅"), ("files", "📁 자료실"), ("cal", "📅 캘린더")]
    }

    @ObservedObject private var theme = ThemeManager.shared

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.0) { id, label in
                let on = tab == id
                VStack(spacing: 8) {
                    Text(label).font(.system(size: 13, weight: .bold))
                        .foregroundColor(on ? Moim.ink : Moim.sub)
                    Rectangle().fill(on ? (theme.dark ? Moim.sub : Moim.yellow) : Color.clear)
                        .frame(height: 2.5).frame(maxWidth: .infinity).padding(.horizontal, 20)
                }
                .padding(.vertical, 12).frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { tab = id }
            }
        }
        .background(Moim.paper)
    }
}

struct ChatView: View {
    @ObservedObject var vm: MoimViewModel
    let canPost: Bool
    @Binding var input: String
    var roomId: String = ""
    var noticeLayout: Bool = false
    var bugReportLayout: Bool = false
    private var multilineCompose: Bool { noticeLayout || bugReportLayout }
    @State private var pickPhoto = false
    @State private var pickFile = false
    @State private var photoItem: PhotosPickerItem?
    // 선택 후 ➤ 누르면 전송 (name, data, type)
    @State private var pendingAttach: (name: String, data: Data, type: String)?
    @State private var deleteTarget: Message?

    // 메시지 + 날짜 구분선 (날짜 바뀌면 divider 삽입) — 전체공지는 카드마다 일시 표시
    private var chatItems: [ChatRowItem] {
        var out: [ChatRowItem] = []
        if noticeLayout {
            for m in mergeNoticeMessages(vm.messages) { out.append(.message(m)) }
            return out
        }
        var lastDay = ""
        for m in vm.messages {
            let d = dayKey(m.createdAt)
            if d != lastDay { out.append(.divider(id: d, label: fmtDateDivider(m.createdAt))); lastDay = d }
            out.append(.message(m))
        }
        return out
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if vm.messages.isEmpty {
                        Text("대화를 시작해보세요").font(.system(size: 14)).foregroundColor(Moim.sub).padding(32)
                    } else {
                        ForEach(chatItems) { item in
                            switch item {
                            case .divider(_, let label):
                                DateDividerView(text: label)
                            case .message(let m):
                                if noticeLayout {
                                    NoticePostCard(
                                        message: m, mine: vm.isMine(m), senderName: vm.name(of: m.senderId),
                                        attachUrl: m.attachmentUrl.flatMap { url in
                                            vm.attachmentUrls[url] ?? (url.hasPrefix("http") ? url : nil)
                                        },
                                        onDelete: { deleteTarget = m },
                                        sender: vm.profilesById[m.senderId],
                                        reactions: vm.reactions.filter { $0.messageId == m.id },
                                        myUserId: vm.myProfile?.id ?? "",
                                        onReact: { e in vm.toggleReaction(m.id, e) }
                                    )
                                    .id(m.id)
                                } else {
                                    MessageBubble(
                                        message: m, mine: vm.isMine(m), senderName: vm.name(of: m.senderId),
                                        attachUrl: m.attachmentUrl.flatMap { url in
                                            vm.attachmentUrls[url] ?? (url.hasPrefix("http") ? url : nil)
                                        },
                                        onDelete: { deleteTarget = m },
                                        unread: effectiveMsgUnread(
                                            roomId: roomId,
                                            count: vm.unreadByMsg[m.id] ?? 0,
                                            role: vm.myProfile?.role
                                        ),
                                        sender: vm.profilesById[m.senderId],
                                        reactions: vm.reactions.filter { $0.messageId == m.id },
                                        myUserId: vm.myProfile?.id ?? "",
                                        onReact: { e in vm.toggleReaction(m.id, e) },
                                        onReply: { vm.setReply(m) },
                                        repliedMessage: m.replyTo.flatMap { vm.message(by: $0) },
                                        repliedName: m.replyTo.flatMap { vm.message(by: $0) }.map { vm.name(of: $0.senderId) }
                                    )
                                    .id(m.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 14)
            }
            .background(Moim.bg)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                chatInputBar
            }
            .onChange(of: vm.messages.count) { _ in
                scrollToBottom(proxy, animated: true)
                vm.resolveAttachments()
            }
            .onAppear { vm.resolveAttachments() }
            .confirmationDialog("이 메시지를 삭제할까요?",
                                isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
                                titleVisibility: .visible) {
                Button("삭제", role: .destructive) { if let t = deleteTarget { vm.deleteMessage(t.id) }; deleteTarget = nil }
                Button("취소", role: .cancel) { deleteTarget = nil }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                scrollToBottom(proxy, animated: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    @ViewBuilder private var chatInputBar: some View {
        if canPost {
            VStack(spacing: 0) {
                // 답장 대상 미리보기 (✕로 취소)
                if let rt = vm.replyTarget {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("↩ \(vm.name(of: rt.senderId)) 에게 답장").font(.system(size: 11, weight: .semibold)).foregroundColor(Moim.accent)
                            Text((rt.content?.isEmpty == false) ? (rt.content ?? "") : (rt.type == "image" ? "사진" : (rt.type == "file" ? "파일" : "")))
                                .font(.system(size: 12)).foregroundColor(Moim.sub).lineLimit(1)
                        }
                        Spacer()
                        Button { vm.setReply(nil) } label: {
                            Text("✕").font(.system(size: 15, weight: .bold)).foregroundColor(Moim.admin)
                        }
                    }
                    .padding(.horizontal, 12).padding(.top, 8)
                }
                if let p = pendingAttach {
                    HStack(spacing: 8) {
                        Text("\(p.type == "image" ? "🖼" : "📎")  \(p.name)")
                            .font(.system(size: 12.5)).foregroundColor(Moim.ink).lineLimit(1)
                        Spacer()
                        Button { pendingAttach = nil } label: {
                            Text("✕").font(.system(size: 15, weight: .bold)).foregroundColor(Moim.admin)
                        }
                    }
                    .padding(.horizontal, 12).padding(.top, 8)
                }
                HStack(alignment: multilineCompose ? .bottom : .center, spacing: 8) {
                    Menu {
                        Button { pickPhoto = true } label: { Label("사진", systemImage: "photo") }
                        Button { pickFile = true } label: { Label("파일", systemImage: "paperclip") }
                    } label: {
                        Text("＋").font(.system(size: 20)).foregroundColor(Moim.sub)
                            .frame(width: 33, height: 33).background(Moim.white).clipShape(Circle())
                    }
                    if multilineCompose {
                        TextField(
                            noticeLayout ? "공지 내용 입력 (줄바꿈 가능)"
                                : (vm.isSuperAdmin ? "메시지 입력" : "버그·제안 내용 입력 (아래 템플릿 참고)"),
                            text: $input, axis: .vertical
                        )
                            .lineLimit(3...8)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("메시지 입력", text: $input)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button {
                        let t = input.trimmingCharacters(in: .whitespaces)
                        if let p = pendingAttach {
                            vm.sendAttachment(fileName: p.name, data: p.data, type: p.type, caption: t.isEmpty ? nil : t)
                            pendingAttach = nil
                            input = ""
                        } else if !t.isEmpty {
                            vm.send(t)
                            input = ""
                        }
                    } label: {
                        Text("➤").font(.system(size: 14))
                            .frame(width: 33, height: 33).background(Moim.yellow).clipShape(Circle())
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
            }
            .background(Moim.paper)
            .photosPicker(isPresented: $pickPhoto, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        pendingAttach = (name: "photo_\(Int(Date().timeIntervalSince1970)).jpg", data: data, type: "image")
                    }
                    photoItem = nil
                }
            }
            .fileImporter(isPresented: $pickFile, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        pendingAttach = (name: url.lastPathComponent, data: data, type: "file")
                    }
                }
            }
        } else {
            Text("🔒 공지 전용 방 · 관리자만 글을 쓸 수 있어요")
                .font(.system(size: 12.5, weight: .semibold)).foregroundColor(Moim.sub)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(14)
                .background(Color(hex: 0xF3EDE3))
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let last = vm.messages.last else { return }
        let scroll = {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2), scroll)
        } else {
            scroll()
        }
    }
}

enum ChatRowItem: Identifiable {
    case divider(id: String, label: String)
    case message(Message)
    var id: String {
        switch self {
        case .divider(let id, _): return "div_\(id)"
        case .message(let m): return m.id
        }
    }
}

// 채팅 가운데 날짜 구분선
struct DateDividerView: View {
    let text: String
    var body: some View {
        HStack {
            Spacer()
            Text(text).font(.system(size: 11)).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Color.black.opacity(0.2)).clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// 카톡식 빠른 리액션 이모지
let REACTION_EMOJIS = ["👍", "❤️", "😂", "😮", "😢", "👏"]

private func replyQuotePreview(_ msg: Message) -> String {
    if let c = msg.content, !c.isEmpty { return c }
    if msg.type == "image" { return "사진" }
    if msg.type == "file" { return "파일" }
    return ""
}

private struct ReplyQuoteInBubble: View {
    let repliedMessage: Message
    let repliedName: String?
    let mine: Bool

    var body: some View {
        let nameColor = mine ? Color.white.opacity(0.92) : Moim.sub
        let bodyColor = mine ? Color.white.opacity(0.78) : Moim.sub
        let dividerColor = mine ? Color.white.opacity(0.32) : Moim.line
        VStack(alignment: .leading, spacing: 1) {
            Text("\(repliedName ?? "상대")에게")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(nameColor)
            Text(replyQuotePreview(repliedMessage))
                .font(.system(size: 11))
                .foregroundColor(bodyColor)
                .lineLimit(1)
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MessageBubble: View {
    let message: Message
    let mine: Bool
    let senderName: String
    var attachUrl: String? = nil   // path 에서 해석된 서명 URL (방 구성원만)
    var onDelete: () -> Void = {}
    var unread: Int = 0
    var sender: Profile? = nil     // 보낸이 프로필(사진/색)
    var reactions: [Reaction] = []
    var myUserId: String = ""
    var onReact: (String) -> Void = { _ in }
    var onReply: () -> Void = {}
    var repliedMessage: Message? = nil
    var repliedName: String? = nil

    private var unreadText: some View {
        Text(unread > 99 ? "99+" : "\(unread)")
            .font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: 0xE0922F))
    }
    private var timeText: some View {
        Text(fmtMsgTime(message.createdAt)).font(.system(size: 10)).foregroundColor(Moim.sub)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if mine {
                Spacer(minLength: 40)
                Button { onDelete() } label: {
                    Text("🗑").font(.system(size: 13)).opacity(0.5)
                }
                .buttonStyle(.plain)
            }
            if mine && unread > 0 { unreadText }
            if mine { timeText }
            if !mine {
                // 보낸이 썸네일: 사진 있으면 사진, 없으면 색/이니셜
                if let s = sender {
                    PersonAvatarView(profile: s, size: 36, corner: 13, font: 13)
                } else {
                    Text(String(senderName.prefix(3)))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .frame(width: 36, height: 36).background(Moim.sub)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if !mine {
                    Text(senderName).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0x6B635C))
                }
                if message.type == "image", message.attachmentUrl != nil {
                    // 서명 URL 해석 전이면 placeholder
                    let u = attachUrl.flatMap { URL(string: $0) }
                    VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                        if let r = repliedMessage {
                            ReplyQuoteInBubble(repliedMessage: r, repliedName: repliedName, mine: mine)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(mine ? Moim.accent : Moim.youBubble)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: 230, alignment: .leading)
                        }
                        Group {
                            if let u {
                                Link(destination: u) {
                                    AsyncImage(url: u) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFit()
                                        } else if phase.error != nil {
                                            Color.gray.opacity(0.15)
                                        } else {
                                            ProgressView().frame(width: 120, height: 120)
                                        }
                                    }
                                    .frame(maxWidth: 200, maxHeight: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            } else {
                                Color.gray.opacity(0.12)
                                    .frame(width: 140, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(ProgressView())
                            }
                        }
                    }
                } else if message.type == "file", message.attachmentUrl != nil {
                    let chip = HStack(spacing: 7) {
                        Text("📎").font(.system(size: 15))
                        Text(message.attachmentName ?? "파일")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(mine ? .white : Moim.ink)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(mine ? Moim.accent : Moim.youBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                        if let r = repliedMessage {
                            ReplyQuoteInBubble(repliedMessage: r, repliedName: repliedName, mine: mine)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(mine ? Moim.accent : Moim.youBubble)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: 230, alignment: .leading)
                        }
                        if let u = attachUrl.flatMap({ URL(string: $0) }) {
                            Link(destination: u) { chip }
                        } else {
                            chip
                        }
                    }
                } else {
                    // 길게 누르기 → 카톡식 메뉴(이모지 리액션 + 복사·답장)
                    VStack(alignment: .leading, spacing: 6) {
                        if let r = repliedMessage {
                            ReplyQuoteInBubble(repliedMessage: r, repliedName: repliedName, mine: mine)
                        }
                        Text(message.content ?? "")
                            .font(.system(size: 14.5))
                            .foregroundColor(mine ? .white : Moim.ink)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(mine ? Moim.accent : Moim.youBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        ForEach(REACTION_EMOJIS, id: \.self) { e in
                            Button(e) { onReact(e) }
                        }
                        Divider()
                        Button { UIPasteboard.general.string = message.content ?? "" } label: {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                        Button { onReply() } label: {
                            Label("답장", systemImage: "arrowshape.turn.up.left")
                        }
                    }
                }
                // 이모지 리액션 칩 (탭하면 내 리액션 토글)
                if !reactions.isEmpty {
                    let grouped = Dictionary(grouping: reactions, by: { $0.emoji })
                    HStack(spacing: 4) {
                        ForEach(grouped.keys.sorted(), id: \.self) { emoji in
                            let list = grouped[emoji] ?? []
                            let mineReacted = list.contains { $0.userId == myUserId }
                            Button { onReact(emoji) } label: {
                                HStack(spacing: 3) {
                                    Text(emoji).font(.system(size: 12))
                                    if list.count > 1 { Text("\(list.count)").font(.system(size: 11)).foregroundColor(Moim.sub) }
                                }
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(mineReacted ? Moim.accent.opacity(0.20) : Moim.bg)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !mine { timeText }
            if !mine && unread > 0 { unreadText }
            if !mine { Spacer(minLength: 40) }
        }
    }
}

struct NoticePostCard: View {
    let message: Message
    let mine: Bool
    let senderName: String
    var attachUrl: String? = nil
    var onDelete: () -> Void = {}
    var sender: Profile? = nil
    var reactions: [Reaction] = []
    var myUserId: String = ""
    var onReact: (String) -> Void = { _ in }

    private var authorLine: String {
        let mt = sender?.memberType ?? ""
        return mt.isEmpty ? senderName : "\(senderName) · \(mt)"
    }

    private var caption: String? {
        guard let text = message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private func copyNoticeText() {
        guard let txt = caption else { return }
        UIPasteboard.general.string = txt
    }

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xB5651D)).frame(height: 3)
                Text(fmtPublishTime(message.createdAt))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Moim.ink)
                    .lineSpacing(4)
                    .padding(.top, 14)
                Text(authorLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Moim.sub)
                    .padding(.top, 6)
                Divider().background(Moim.line).padding(.vertical, 14)
                noticeBody
                if !reactions.isEmpty {
                    let grouped = Dictionary(grouping: reactions, by: { $0.emoji })
                    HStack(spacing: 4) {
                        ForEach(grouped.keys.sorted(), id: \.self) { emoji in
                            let list = grouped[emoji] ?? []
                            let mineReacted = list.contains { $0.userId == myUserId }
                            Button { onReact(emoji) } label: {
                                HStack(spacing: 3) {
                                    Text(emoji).font(.system(size: 12))
                                    if list.count > 1 { Text("\(list.count)").font(.system(size: 11)).foregroundColor(Moim.sub) }
                                }
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(mineReacted ? Moim.accent.opacity(0.20) : Moim.bg)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 6)
                }
                HStack(spacing: 16) {
                    Spacer()
                    if caption != nil {
                        Button(action: copyNoticeText) {
                            Text("📋 복사").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    if mine {
                        Button(action: onDelete) {
                            Text("🗑 삭제").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.admin)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .frame(maxWidth: 400)
            .background(Moim.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Moim.line, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            .contextMenu {
                ForEach(REACTION_EMOJIS, id: \.self) { e in
                    Button(e) { onReact(e) }
                }
                if caption != nil {
                    Divider()
                    Button { copyNoticeText() } label: {
                        Label("복사", systemImage: "doc.on.doc")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var noticeBody: some View {
        if let cap = caption {
            Text(linkifiedNoticeText(cap))
                .font(.system(size: 15))
                .foregroundColor(Moim.ink)
                .tint(Moim.accent)
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if message.type == "image", message.attachmentUrl != nil {
            if caption != nil { Spacer().frame(height: 12) }
            noticeImageBlock
        } else if message.type == "file", message.attachmentUrl != nil {
            if caption != nil { Spacer().frame(height: 12) }
            noticeFileBlock
        } else if caption == nil {
            Text(linkifiedNoticeText(message.content ?? ""))
                .font(.system(size: 15))
                .foregroundColor(Moim.ink)
                .tint(Moim.accent)
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var noticeImageBlock: some View {
        let u = attachUrl.flatMap { URL(string: $0) }
        Group {
            if let u {
                Link(destination: u) {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image { img.resizable().scaledToFit() }
                        else if phase.error != nil { Color.gray.opacity(0.15) }
                        else { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
    }

    @ViewBuilder private var noticeFileBlock: some View {
        let chip = HStack(spacing: 8) {
            Text("📎").font(.system(size: 16))
            Text(message.attachmentName ?? "파일")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Moim.ink).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Moim.paper)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        if let u = attachUrl.flatMap({ URL(string: $0) }) {
            Link(destination: u) { chip }
        } else { chip }
    }
}
