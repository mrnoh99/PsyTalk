import SwiftUI

struct RoomView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let onBack: () -> Void

    @State private var tab: String
    @State private var input = ""
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showSettings = false

    init(vm: MoimViewModel, room: Room, onBack: @escaping () -> Void) {
        self.vm = vm; self.room = room; self.onBack = onBack
        // default_view='week' 방은 열자마자 캘린더(주간) 탭으로 (Android 와 동일)
        _tab = State(initialValue: room.defaultView == "week" ? "cal" : "chat")
    }

    // 이름 변경이 반영되도록 최신 방 정보를 vm.rooms 에서 조회
    private var liveRoom: Room { vm.rooms.first { $0.id == room.id } ?? room }
    private var canPost: Bool { canPostInRoom(vm.myProfile, room) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabBar
            Divider().background(Moim.line)

            switch tab {
            case "chat": ChatView(vm: vm, canPost: canPost, input: $input)
            case "files": FilesView(vm: vm, canUpload: canPost)
            default: CalendarView(vm: vm, room: room, canPost: canPost)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) { Text("‹").font(.system(size: 25)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(liveRoom.name).font(.system(size: 16, weight: .bold)).foregroundColor(Moim.ink)
                Text(catLabel(liveRoom.category)).font(.system(size: 12)).foregroundColor(Moim.sub)
            }
            Spacer()
            if canRenameRoom(vm.myProfile, liveRoom) {
                Button {
                    renameText = liveRoom.name
                    showRename = true
                } label: {
                    Text("✏️").font(.system(size: 17))
                }
            }
            if vm.canManageRoom(liveRoom) {
                Button {
                    vm.loadRoomMembers(liveRoom.id)
                    showSettings = true
                } label: {
                    Text("⚙️").font(.system(size: 17))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Moim.paper)
        .alert("방 이름 변경", isPresented: $showRename) {
            TextField("방 이름", text: $renameText)
            Button("취소", role: .cancel) {}
            Button("저장") { vm.renameRoom(liveRoom, to: renameText) {} }
        }
        .sheet(isPresented: $showSettings) {
            RoomSettingsView(vm: vm, room: liveRoom,
                             onClose: { showSettings = false },
                             onDeleted: { showSettings = false; onBack() })
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([("chat", "💬 채팅"), ("files", "📁 자료실"), ("cal", "📅 캘린더")], id: \.0) { id, label in
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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    Text("2026년 6월 3일 화요일")
                        .font(.system(size: 11)).foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Color.black.opacity(0.18)).clipShape(Capsule())
                        .padding(.vertical, 8)
                    if vm.messages.isEmpty {
                        Text("대화를 시작해보세요").font(.system(size: 14)).foregroundColor(Moim.sub).padding(32)
                    } else {
                        ForEach(vm.messages) { m in
                            MessageBubble(message: m, mine: vm.isMine(m), senderName: vm.name(of: m.senderId))
                                .id(m.id)
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
            HStack(spacing: 8) {
                TextField("메시지 입력", text: $input)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let t = input.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { vm.send(t); input = "" }
                } label: {
                    Text("➤").font(.system(size: 14))
                        .frame(width: 33, height: 33).background(Moim.yellow).clipShape(Circle())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Moim.paper)
        } else {
            Text("🔒 공지 전용 방 · 관리자와 지정 작성자만 글을 쓸 수 있어요")
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

struct MessageBubble: View {
    let message: Message
    let mine: Bool
    let senderName: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if mine { Spacer(minLength: 40) }
            if !mine {
                Text(String(senderName.prefix(3)))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .frame(width: 36, height: 36).background(Moim.sub)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if !mine {
                    Text(senderName).font(.system(size: 12, weight: .semibold)).foregroundColor(Color(hex: 0x6B635C))
                }
                Text(message.content ?? "")
                    .font(.system(size: 14.5)).foregroundColor(Moim.ink)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(mine ? Moim.yellow : Moim.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            if !mine { Spacer(minLength: 40) }
        }
    }
}
