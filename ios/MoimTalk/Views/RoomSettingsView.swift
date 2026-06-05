import SwiftUI

// 모임방 설정 — 멤버 내보내기 + 모임방 삭제 (생성자/관리자만)
struct RoomSettingsView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let onClose: () -> Void
    let onDeleted: () -> Void

    @State private var confirmDelete = false
    @State private var kickTarget: String?
    @State private var showInvite = false

    // 방 삭제는 생성자(방장) 또는 전체관리자만
    private var canDelete: Bool {
        room.createdBy == MoimRepository.currentUserId() || vm.isSuperAdmin
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        showInvite = true
                    } label: {
                        Label("구성원 초대", systemImage: "person.badge.plus")
                    }
                }

                Section(header: Text("참여 멤버 (\(vm.roomMemberIds.count)명)")) {
                    if !vm.roomMembersLoaded {
                        Text("멤버 정보를 불러오는 중…").font(.system(size: 13)).foregroundColor(Moim.sub)
                    } else if vm.roomMemberIds.isEmpty {
                        Text("참여 구성원이 없습니다. 위에서 초대하세요.").font(.system(size: 13)).foregroundColor(Moim.sub)
                    }
                    ForEach(vm.roomMemberIds, id: \.self) { uid in
                        let isCreator = uid == room.createdBy
                        let isMe = uid == MoimRepository.currentUserId()
                        HStack {
                            Text(vm.name(of: uid) + (isCreator ? " (방장)" : (isMe ? " (나)" : "")))
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(Moim.ink)
                            Spacer()
                            if !isCreator {
                                Button("내보내기") { kickTarget = uid }
                                    .font(.system(size: 13)).foregroundColor(Moim.admin)
                            }
                        }
                    }
                }

                if canDelete {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("이 모임방 삭제").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("모임방 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { onClose() }
                }
            }
            // 모임방 삭제 확인
            .confirmationDialog("‘\(room.name)’ 모임방을 삭제할까요?\n채팅·일정·자료가 모두 삭제되며 되돌릴 수 없습니다.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { vm.deleteRoom(room) { onDeleted() } }
                Button("취소", role: .cancel) {}
            }
            // 멤버 내보내기 확인
            .confirmationDialog("‘\(kickTarget.map { vm.name(of: $0) } ?? "")’ 님을 내보낼까요?",
                                isPresented: Binding(get: { kickTarget != nil },
                                                     set: { if !$0 { kickTarget = nil } }),
                                titleVisibility: .visible) {
                Button("내보내기", role: .destructive) {
                    if let uid = kickTarget { vm.removeRoomMember(roomId: room.id, userId: uid) }
                    kickTarget = nil
                }
                Button("취소", role: .cancel) { kickTarget = nil }
            }
            .sheet(isPresented: $showInvite) {
                RoomMemberPicker(vm: vm, room: room, mode: .invite) { showInvite = false }
            }
        }
        .onAppear { vm.loadRoomMembers(room.id) }
    }
}
