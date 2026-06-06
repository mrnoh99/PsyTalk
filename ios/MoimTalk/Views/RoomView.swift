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
            case "chat": ChatView(vm: vm, canPost: canPost, input: $input,
                                  noticeLayout: isNoticeTopRoom(liveRoom, vm.rooms))
            case "files": FilesView(vm: vm, canUpload: canPost)
            default: CalendarView(vm: vm, room: liveRoom, canPost: canPost)
                .id(liveRoom.id)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .task(id: liveRoom.id) {
            tab = isNoticeTopRoom(liveRoom, vm.rooms) ? "chat"
                : (opensWeekCalendar(liveRoom) ? "cal" : "chat")
            if !isDM { vm.loadRoomMembers(liveRoom.id) }
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
                // 개설자·참여자 이름 나열 (작은 글씨, 넘치면 ... — DM 제외)
                if !isDM, vm.memberListRoomId == liveRoom.id {
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
        return [("chat", "💬 채팅"), ("files", "📁 자료실"), ("cal", "📅 캘린더")]
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.0) { id, label in
                let on = tab == id
                VStack(spacing: 8) {
                    Text(label).font(.system(size: 13, weight: .bold))
                        .foregroundColor(on ? Moim.ink : Moim.sub)
                    Rectangle().fill(on ? Moim.yellow : Color.clear)
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
    var noticeLayout: Bool = false
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
                                        sender: vm.profilesById[m.senderId]
                                    )
                                    .id(m.id)
                                } else {
                                    MessageBubble(
                                        message: m, mine: vm.isMine(m), senderName: vm.name(of: m.senderId),
                                        attachUrl: m.attachmentUrl.flatMap { url in
                                            vm.attachmentUrls[url] ?? (url.hasPrefix("http") ? url : nil)
                                        },
                                        onDelete: { deleteTarget = m },
                                        unread: vm.unreadByMsg[m.id] ?? 0,
                                        sender: vm.profilesById[m.senderId]
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
                HStack(alignment: noticeLayout ? .bottom : .center, spacing: 8) {
                    Menu {
                        Button { pickPhoto = true } label: { Label("사진", systemImage: "photo") }
                        Button { pickFile = true } label: { Label("파일", systemImage: "paperclip") }
                    } label: {
                        Text("＋").font(.system(size: 20)).foregroundColor(Moim.sub)
                            .frame(width: 33, height: 33).background(Moim.white).clipShape(Circle())
                    }
                    if noticeLayout {
                        TextField("공지 내용 입력 (줄바꿈 가능)", text: $input, axis: .vertical)
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

struct MessageBubble: View {
    let message: Message
    let mine: Bool
    let senderName: String
    var attachUrl: String? = nil   // path 에서 해석된 서명 URL (방 구성원만)
    var onDelete: () -> Void = {}
    var unread: Int = 0
    var sender: Profile? = nil     // 보낸이 프로필(사진/색)

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
                } else if message.type == "file", message.attachmentUrl != nil {
                    let chip = HStack(spacing: 7) {
                        Text("📎").font(.system(size: 15))
                        Text(message.attachmentName ?? "파일")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(Moim.ink)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 16))
                    if let u = attachUrl.flatMap({ URL(string: $0) }) {
                        Link(destination: u) { chip }
                    } else {
                        chip
                    }
                } else {
                    Text(message.content ?? "")
                        .font(.system(size: 14.5)).foregroundColor(Moim.ink)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(mine ? Moim.yellow : Moim.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private var authorLine: String {
        let mt = sender?.memberType ?? ""
        return mt.isEmpty ? senderName : "\(senderName) · \(mt)"
    }

    private var caption: String? {
        message.content?.trimmingCharacters(in: .whitespacesAndNewlines).flatMap { $0.isEmpty ? nil : $0 }
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
                if mine {
                    Button(action: onDelete) {
                        Text("🗑 삭제").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.admin)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .frame(maxWidth: 400)
            .background(Moim.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Moim.line, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var noticeBody: some View {
        if let cap = caption {
            Text(cap)
                .font(.system(size: 15))
                .foregroundColor(Moim.ink)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if message.type == "image", message.attachmentUrl != nil {
            if caption != nil { Spacer().frame(height: 12) }
            noticeImageBlock
        } else if message.type == "file", message.attachmentUrl != nil {
            if caption != nil { Spacer().frame(height: 12) }
            noticeFileBlock
        } else if caption == nil {
            Text(message.content ?? "")
                .font(.system(size: 15))
                .foregroundColor(Moim.ink)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var noticeImageBlock: some View {
        let u = attachUrl.flatMap { URL(string: $0) }
        Group {
            if let u {
                AsyncImage(url: u) { phase in
                    if let img = phase.image { img.resizable().scaledToFit() }
                    else if phase.error != nil { Color.gray.opacity(0.15) }
                    else { ProgressView() }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    noticeDownloadAttachment(from: u.absoluteString, fileName: message.attachmentName ?? "photo.jpg")
                }
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        Text("탭하여 다운로드")
            .font(.system(size: 11))
            .foregroundColor(Moim.sub)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    @ViewBuilder private var noticeFileBlock: some View {
        let chip = HStack(spacing: 8) {
            Text("📎").font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(message.attachmentName ?? "파일")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(Moim.ink).lineLimit(2)
                Text("탭하여 다운로드").font(.system(size: 11)).foregroundColor(Moim.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Moim.paper)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        if let u = attachUrl.flatMap({ URL(string: $0) }) {
            chip.onTapGesture { noticeDownloadAttachment(from: u.absoluteString, fileName: message.attachmentName ?? "file") }
        } else { chip }
    }
}

private func noticeDownloadAttachment(from urlString: String, fileName: String) {
    guard let url = URL(string: urlString) else { return }
    Task {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: dest)
            await MainActor.run {
                guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                      let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
                let vc = UIActivityViewController(activityItems: [dest], applicationActivities: nil)
                if let pop = vc.popoverPresentationController {
                    pop.sourceView = root.view
                    pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
                }
                root.present(vc, animated: true)
            }
        } catch {}
    }
}
