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
            } else if showCreateRoom {
                CreateRoomView(vm: vm, onBack: { showCreateRoom = false })
            } else {
                ZStack {
                    // 방 진입 시에도 목록 뷰 유지 → 뒤로가기 시 스크롤 위치 보존
                    RoomListView(
                        vm: vm,
                        onOpen: { room in withAnimation(.easeOut(duration: 0.26)) { openedRoom = room }; vm.openRoom(room) },
                        onAdmin: { showAdmin = true },
                        onWard: { withAnimation(.easeOut(duration: 0.26)) { showWard = true } },
                        onCreateRoom: { showCreateRoom = true }
                    )
                    if let room = openedRoom {
                        RoomView(vm: vm, room: room, onBack: {
                            withAnimation(.easeOut(duration: 0.26)) { openedRoom = nil }
                            vm.closeRoom()
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .zIndex(1)
                    }
                    if showWard {
                        WardStatusView(vm: vm, onBack: {
                            withAnimation(.easeOut(duration: 0.26)) { showWard = false }
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        .zIndex(2)
                    }
                }
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
                withAnimation(.easeOut(duration: 0.26)) { openedRoom = nil }
                vm.closeRoom()
            }
        }
    }
}
