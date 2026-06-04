import SwiftUI

@main
struct MoimTalkApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

// Android App() 네비게이션과 동일한 화면 전환
struct RootView: View {
    @StateObject private var vm = MoimViewModel()
    @State private var openedRoom: Room?
    @State private var showAdmin = false
    @State private var showWard = false
    @State private var showCreateRoom = false

    var body: some View {
        Group {
            if !vm.loggedIn {
                LoginView(vm: vm)
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
            } else {
                RoomListView(
                    vm: vm,
                    onOpen: { room in openedRoom = room; vm.openRoom(room) },
                    onAdmin: { showAdmin = true },
                    onWard: { showWard = true },
                    onCreateRoom: { showCreateRoom = true }
                )
            }
        }
        .onAppear { if vm.loggedIn { vm.loadRooms() } }
        .onChange(of: vm.loggedIn) { newValue in
            if newValue { vm.loadRooms() }
        }
    }
}
