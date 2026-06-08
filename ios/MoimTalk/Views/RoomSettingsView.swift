import SwiftUI

// 모임방 설정 — 구성원 초대·제거 + 모임방 삭제 (web #smodal 과 동일: 위 참여 / 아래 초대)
struct RoomSettingsView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let onClose: () -> Void
    let onDeleted: () -> Void

    @State private var confirmDelete = false
    @State private var confirmRemove: Profile?

    private var canDelete: Bool {
        room.createdBy == MoimRepository.currentUserId() || vm.isSuperAdmin
    }

    /// 본인 제외 · 승인 · 미탈퇴 · 미참여 (web renderInviteList)
    private var inviteCandidates: [Profile] {
        let memberIds = Set(vm.roomMemberIds)
        return vm.profilesById.values
            .filter {
                $0.id != MoimRepository.currentUserId()
                    && $0.approved != false
                    && $0.withdrawn != true
                    && !memberIds.contains($0.id)
            }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("참여 회원 (제거)")) {
                    if !vm.roomMembersLoaded {
                        Text("회원 정보를 불러오는 중…").font(.system(size: 13)).foregroundColor(Moim.sub)
                    } else if vm.roomMemberIds.isEmpty {
                        Text("참여 구성원이 없습니다. 아래에서 초대하세요.").font(.system(size: 13)).foregroundColor(Moim.sub)
                    }
                    ForEach(orderedRoomMemberIds(room, memberIds: vm.roomMemberIds, profiles: vm.profilesById), id: \.self) { uid in
                        let isCreator = uid == room.createdBy
                        let isMe = uid == MoimRepository.currentUserId()
                        let tag = isCreator ? " (개설자)" : (isMe ? " (나)" : "")
                        HStack(alignment: .center, spacing: 10) {
                            if let p = vm.profilesById[uid] {
                                roomMemberInfo(p, nameSuffix: tag)
                            } else {
                                Text(vm.name(of: uid) + tag)
                                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Moim.ink)
                            }
                            Spacer()
                            if !isCreator {
                                Button("제거") {
                                    if let p = vm.profilesById[uid] { confirmRemove = p }
                                }
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.admin)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(header: Text("구성원 초대")) {
                    if !vm.roomMembersLoaded {
                        Text("회원 정보를 불러오는 중…").font(.system(size: 13)).foregroundColor(Moim.sub)
                    } else if inviteCandidates.isEmpty {
                        Text("초대할 수 있는 회원가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
                    }
                    ForEach(inviteCandidates) { p in
                        HStack(alignment: .center, spacing: 10) {
                            roomMemberInfo(p)
                            Spacer()
                            Button("초대") { vm.inviteRoomMember(roomId: room.id, userId: p.id) }
                                .font(.system(size: 13, weight: .bold)).foregroundColor(catColor("work"))
                        }
                        .buttonStyle(.plain)
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
            .confirmationDialog("'\(room.name)' 모임방을 삭제할까요?\n채팅·일정·자료가 모두 삭제되며 되돌릴 수 없습니다.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { vm.deleteRoom(room) { onDeleted() } }
                Button("취소", role: .cancel) {}
            }
            .confirmationDialog("'\(confirmRemove?.name ?? "")' 님을 이 모임방에서 제거할까요?",
                                isPresented: Binding(get: { confirmRemove != nil },
                                                     set: { if !$0 { confirmRemove = nil } }),
                                titleVisibility: .visible) {
                Button("구성원 제거", role: .destructive) {
                    if let p = confirmRemove { vm.removeRoomMember(roomId: room.id, userId: p.id) }
                    confirmRemove = nil
                }
                Button("취소", role: .cancel) { confirmRemove = nil }
            }
        }
        .onAppear {
            vm.loadRoomMembers(room.id)
            vm.loadProfiles()
        }
    }

    @ViewBuilder
    private func roomMemberInfo(_ p: Profile, nameSuffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.name + nameSuffix).font(.system(size: 14, weight: .semibold)).foregroundColor(Moim.ink)
            MemberTypeIntroLines(profile: p)
        }
    }
}
