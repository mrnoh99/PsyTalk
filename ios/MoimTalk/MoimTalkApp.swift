import SwiftUI
import UIKit

@main
struct MoimTalkApp: App {
    init() {
        Push.configure()
        if let uid = MoimRepository.currentUserId() { Push.login(uid) }
    }
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// Android App() 네비게이션과 동일한 화면 전환
struct RootView: View {
    @StateObject private var vm = MoimViewModel()
    @ObservedObject private var theme = ThemeManager.shared   // 다크/라이트 전환 시 전체 재렌더
    @State private var openedRoom: Room?
    @State private var showAdmin = false
    @State private var showWard = false
    @State private var showCreateRoom = false

    var body: some View {
        Group {
            if !vm.loggedIn {
                LoginView(vm: vm)
            } else if vm.myProfile != nil && vm.myProfile?.approved != true {
                // 기본값 불승인: approved 가 true 가 아니면(false·nil·미설정) 승인 대기
                PendingApprovalView(vm: vm)
            } else if showAdmin {
                AdminPlaceholderView(vm: vm, onBack: { showAdmin = false })
            } else if showWard {
                WardStatusView(vm: vm, onBack: { showWard = false })
            } else if showCreateRoom {
                CreateRoomView(vm: vm, onBack: { showCreateRoom = false })
            } else if let room = openedRoom {
                RoomView(vm: vm, room: room, onBack: {
                    vm.closeRoom(); openedRoom = nil
                })
                // 채팅방 열릴 때 오른쪽 → 왼쪽으로 펼쳐 나오는 효과
                .transition(.move(edge: .trailing))
            } else {
                RoomListView(
                    vm: vm,
                    onOpen: { room in withAnimation(.easeOut(duration: 0.26)) { openedRoom = room }; vm.openRoom(room) },
                    onAdmin: { showAdmin = true },
                    onWard: { showWard = true },
                    onCreateRoom: { showCreateRoom = true }
                )
            }
        }
        .preferredColorScheme(theme.dark ? .dark : .light)
        .alert("오류", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("확인", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        .alert("알림", isPresented: Binding(
            get: { vm.loggedIn && vm.notice != nil },
            set: { if !$0 { vm.notice = nil } }
        )) {
            Button("확인", role: .cancel) { vm.notice = nil }
        } message: {
            Text(vm.notice ?? "")
        }
        // 회원 검색에서 1:1 DM 열기 → 해당 방으로 전환
        .onChange(of: vm.pendingOpenRoom) { room in
            if let room = room {
                withAnimation(.easeOut(duration: 0.26)) { openedRoom = room }
                vm.openRoom(room)
                vm.pendingOpenRoom = nil
            }
        }
        .onAppear { if vm.loggedIn { vm.loadRooms() } }
        .onChange(of: vm.loggedIn) { newValue in
            if newValue { vm.loadRooms() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if vm.loggedIn { vm.refreshOnForeground() }
        }
        .onChange(of: vm.rooms) { _ in
            if let r = openedRoom, !vm.rooms.contains(where: { $0.id == r.id }) {
                vm.closeRoom()
                openedRoom = nil
            }
        }
    }
}
