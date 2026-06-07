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
    @State private var showRoomOverlay = false   // 복귀 애니 중 RoomView 유지
    @State private var overlayRoom: Room?
    @State private var showAdmin = false
    @State private var showWard = false
    @State private var showCreateRoom = false
    @State private var showSettings = false

    private var pinRooms: [Room] {
        let week = vm.rooms.first { $0.category != "custom" && $0.defaultView == "week" }
        let notice = noticeTopRoom(vm.rooms)
        let bugReport = bugReportRoom(vm.rooms)
        return vm.rooms.filter {
            $0.id != week?.id && $0.id != notice?.id && $0.id != bugReport?.id &&
            (($0.category != "custom" && $0.category != "direct") || vm.myRoomIds.contains($0.id))
        }
    }

    private func openRoomOverlay(_ room: Room) {
        overlayRoom = room
        openedRoom = room
        withAnimation(MoimOverlayAnim.anim) { showRoomOverlay = true }
        vm.openRoom(room)
    }

    private func closeRoomOverlay() {
        withAnimation(MoimOverlayAnim.anim) { showRoomOverlay = false }
        vm.closeRoom()
        openedRoom = nil
    }

    var body: some View {
        Group {
            if !vm.loggedIn {
                LoginView(vm: vm)
            } else if vm.myProfile != nil && vm.myProfile?.approved != true {
                // 기본값 불승인: approved 가 true 가 아니면(false·nil·미설정) 승인 대기
                PendingApprovalView(vm: vm)
            } else {
                ZStack {
                    // 방 진입 시에도 목록 뷰 유지 → 뒤로가기 시 스크롤 위치 보존
                    RoomListView(
                        vm: vm,
                        onOpen: { openRoomOverlay($0) },
                        onAdmin: { withAnimation(MoimOverlayAnim.anim) { showAdmin = true } },
                        onWard: { withAnimation(MoimOverlayAnim.anim) { showWard = true } },
                        onCreateRoom: { withAnimation(MoimOverlayAnim.anim) { showCreateRoom = true } },
                        onSettings: { withAnimation(MoimOverlayAnim.anim) { showSettings = true } }
                    )
                    if showRoomOverlay, let room = overlayRoom {
                        RoomView(vm: vm, room: room, onBack: { closeRoomOverlay() })
                            .transition(MoimOverlayAnim.transition)
                            .zIndex(1)
                            .onDisappear {
                                if !showRoomOverlay { overlayRoom = nil }
                            }
                    }
                    if showSettings {
                        SettingsView(vm: vm, pinRooms: pinRooms, onBack: {
                            withAnimation(MoimOverlayAnim.anim) { showSettings = false }
                        })
                        .transition(MoimOverlayAnim.transition)
                        .zIndex(2)
                    }
                    if showAdmin {
                        AdminPlaceholderView(vm: vm, onBack: {
                            withAnimation(MoimOverlayAnim.anim) { showAdmin = false }
                        })
                        .transition(MoimOverlayAnim.transition)
                        .zIndex(2)
                    }
                    if showCreateRoom {
                        CreateRoomView(vm: vm, onBack: {
                            withAnimation(MoimOverlayAnim.anim) { showCreateRoom = false }
                        })
                        .transition(MoimOverlayAnim.transition)
                        .zIndex(2)
                    }
                    if showWard {
                        WardStatusView(vm: vm, onBack: {
                            withAnimation(MoimOverlayAnim.anim) { showWard = false }
                        })
                        .transition(MoimOverlayAnim.transition)
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
                withAnimation(MoimOverlayAnim.anim) { showSettings = false }
                openRoomOverlay(room)
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
                closeRoomOverlay()
            }
        }
    }
}
