import SwiftUI

struct RoomView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let onBack: () -> Void

    @State private var tab: String
    @State private var input = ""

    init(vm: MoimViewModel, room: Room, onBack: @escaping () -> Void) {
        self.vm = vm; self.room = room; self.onBack = onBack
        // default_view='week' 방은 열자마자 캘린더(주간) 탭으로 (Android 와 동일)
        _tab = State(initialValue: room.defaultView == "week" ? "cal" : "chat")
    }

    private var canPost: Bool { canPostInRoom(vm.myProfile, room) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            tabBar
            Divider().background(Moim.line)

            switch tab {
            case "chat": ChatView(vm: vm)
            case "files": FilesView(vm: vm, canUpload: canPost)
            default: CalendarView(vm: vm, room: room, canPost: canPost)
            }

            if tab == "chat" { inputBar }
        }
        .background(Moim.paper.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) { Text("‹").font(.system(size: 25)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name).font(.system(size: 16, weight: .bold)).foregroundColor(Moim.ink)
                Text(catLabel(room.category)).font(.system(size: 12)).foregroundColor(Moim.sub)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Moim.paper)
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

    @ViewBuilder private var inputBar: some View {
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
}

struct ChatView: View {
    @ObservedObject var vm: MoimViewModel

    var body: some View {
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
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 14)
        }
        .background(Moim.bg)
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
