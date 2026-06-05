import SwiftUI

enum AdminConsoleTab: String, CaseIterable {
    case approval = "가입 승인"
    case members = "회원 관리"
    case rooms = "방 관리"
}

// 관리자 콘솔 (전체관리자) — iPad/Mac·iPhone 공통
struct AdminPlaceholderView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void
    var initialTab: AdminConsoleTab = .approval

    @State private var tab: AdminConsoleTab = .approval
    @State private var showRename = false
    @State private var renameText = ""
    @State private var renameTargetId = ""
    @State private var selectedRoom: Room?
    @State private var deactivateTarget: Profile?

    // 전체관리자=3탭 전부 / 관리자=가입 승인만
    private var allowedTabs: [AdminConsoleTab] {
        vm.isSuperAdmin ? AdminConsoleTab.allCases : [.approval]
    }

    // 회원 관리 명단: 승인됨 + 미탈퇴 (전체관리자 제외)
    private var members: [Profile] {
        vm.profilesById.values
            .filter { $0.role != "superadmin" && $0.withdrawn != true && ($0.approved == true) }
            .sorted { $0.name < $1.name }
    }

    // 가입 승인 대기: 미승인 + 미탈퇴 (전체관리자 제외)
    private var pendingCount: Int {
        vm.profilesById.values.filter { $0.role != "superadmin" && $0.withdrawn != true && $0.approved == false }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)).foregroundColor(.white) }
                Text("관리자 콘솔").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.accent)

            if allowedTabs.count > 1 {
                Picker("탭", selection: $tab) {
                    ForEach(allowedTabs, id: \.self) { t in
                        if t == .approval && pendingCount > 0 {
                            Text("\(t.rawValue) (\(pendingCount))").tag(t)
                        } else {
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Moim.paper)
            }

            ScrollView {
                Group {
                    switch tab {
                    case .approval:
                        SignupApprovalView(vm: vm)
                    case .members:
                        membersContent
                    case .rooms:
                        if let room = selectedRoom {
                            AdminRoomManageView(vm: vm, room: room) { selectedRoom = nil }
                        } else {
                            roomsContent
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .onAppear {
            tab = initialTab
            vm.loadRoomMemberCounts()
        }
        .alert("이름 변경", isPresented: $showRename) {
            TextField("이름", text: $renameText)
            Button("저장") { vm.setName(renameTargetId, to: renameText) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("새 이름을 입력하세요.")
        }
        .confirmationDialog(
            "‘\(deactivateTarget?.name ?? "")’ 님의 계정을 비활성화할까요?\n로그인·활동이 막히고 모든 방에서 제외됩니다.\n(작성한 글·올린 자료는 그대로 남습니다.)",
            isPresented: Binding(get: { deactivateTarget != nil }, set: { if !$0 { deactivateTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("계정 비활성화", role: .destructive) {
                if let p = deactivateTarget { vm.adminDeactivate(p.id) }
                deactivateTarget = nil
            }
            Button("취소", role: .cancel) { deactivateTarget = nil }
        }
    }

    @ViewBuilder
    private var membersContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            card(title: "👥 회원 관리 · \(members.count)명 · 관리자 지위 지정 / 계정 비활성화") {
                if members.isEmpty {
                    Text("승인된 회원이 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
                } else {
                    ForEach(members) { p in memberRow(p) }
                }
            }
        }
    }

    @ViewBuilder
    private var roomsContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            card(title: "🏠 방 관리 · \(vm.rooms.count)개 · 방을 눌러 구성원 편집") {
                ForEach(vm.rooms) { r in roomRow(r) }
            }
        }
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 11.5, weight: .heavy)).foregroundColor(Moim.sub).padding(.bottom, 11)
            content()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func memberRow(_ p: Profile) -> some View {
        let role: (Color, String) = p.role == "superadmin" ? (Moim.admin, "전체관리자")
            : p.role == "admin" ? (Color(hex: 0xB5651D), "관리자") : (Moim.line, "회원")
        let pending = p.approved == false
        return HStack(spacing: 10) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(p.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(Moim.ink)
                    Text("✏️").font(.system(size: 10)).opacity(0.5)
                    if pending {
                        Text("대기").font(.system(size: 9, weight: .bold)).foregroundColor(Moim.admin)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Moim.admin.opacity(0.12)).clipShape(Capsule())
                    }
                }
                Text(p.memberType).font(.system(size: 11.5)).foregroundColor(Moim.sub)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                renameTargetId = p.id
                renameText = p.name
                showRename = true
            }
            Spacer()
            Menu {
                Button("관리자") { vm.setRole(p.id, to: "admin") }
                Button("회원") { vm.setRole(p.id, to: "user") }
            } label: {
                HStack(spacing: 3) {
                    Text(role.1).font(.system(size: 10, weight: .bold))
                        .foregroundColor(p.role == "user" ? Moim.accent : .white)
                    Text("▾").font(.system(size: 8))
                        .foregroundColor(p.role == "user" ? Moim.accent : .white)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(role.0).clipShape(Capsule())
            }
            Button { deactivateTarget = p } label: {
                Text("계정 비활성화").font(.system(size: 10, weight: .bold)).foregroundColor(Moim.admin)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .overlay(Capsule().stroke(Moim.admin, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
    }

    private func roomRow(_ r: Room) -> some View {
        Button { selectedRoom = r } label: {
            HStack(spacing: 10) {
                Text(r.name)
                    .font(.system(size: 8.5, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(2)
                    .frame(width: 36, height: 36)
                    .background(catColor(r.category)).clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text(r.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(Moim.ink)
                    Text("\(catLabel(r.category)) · \(r.postPolicy) · \(vm.roomMemberCounts[r.id, default: 0])명")
                        .font(.system(size: 11.5)).foregroundColor(Moim.sub)
                }
                Spacer()
                Text("›").font(.system(size: 18, weight: .bold)).foregroundColor(Moim.sub)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// 방 선택 후 — 참여 회원·초대 가능 회원를 체크 목록으로 편집
struct AdminRoomManageView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let onBack: () -> Void

    @State private var confirmDelete = false

    private var memberIds: Set<String> { Set(vm.roomMemberIds) }

    /// 승인된 회원 전체 (전체관리자 제외) — 참여 여부는 체크로 표시
    private var selectableProfiles: [Profile] {
        vm.profilesById.values
            .filter { $0.role != "superadmin" && ($0.approved ?? true) }
            .sorted { $0.name < $1.name }
    }

    private var canDelete: Bool {
        vm.isSuperAdmin && room.category == "custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Text("‹").font(.system(size: 20, weight: .bold))
                    Text("방 목록").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Moim.accent)
            }

            HStack(spacing: 12) {
                Text(room.name)
                    .font(.system(size: 8.5, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(4)
                    .frame(width: 44, height: 44)
                    .background(catColor(room.category)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).font(.system(size: 17, weight: .bold)).foregroundColor(Moim.ink)
                    Text("\(catLabel(room.category)) · \(memberIds.count)명 참여")
                        .font(.system(size: 12)).foregroundColor(Moim.sub)
                }
            }

            if canDelete {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Text("이 방 삭제")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Moim.admin)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("구성원 · 체크=참여 · 해제=제거 · 미체크 탭=초대")
                    .font(.system(size: 11.5, weight: .heavy))
                    .foregroundColor(Moim.sub)
                    .padding(.bottom, 10)

                if !vm.roomMembersLoaded {
                    Text("회원 목록 불러오는 중…").font(.system(size: 13)).foregroundColor(Moim.sub)
                        .padding(.vertical, 12)
                } else if selectableProfiles.isEmpty {
                    Text("표시할 회원가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
                        .padding(.vertical, 12)
                } else {
                    ForEach(selectableProfiles) { p in
                        memberCheckRow(p)
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Moim.white)
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .onAppear { vm.loadRoomMembers(room.id) }
        .confirmationDialog(
            "‘\(room.name)’ 방을 삭제할까요?\n채팅·일정·자료가 모두 삭제되며 되돌릴 수 없습니다.",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("방 삭제", role: .destructive) {
                vm.deleteRoom(room) { onBack() }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func memberCheckRow(_ p: Profile) -> some View {
        let isMember = memberIds.contains(p.id)
        let isCreator = p.id == room.createdBy
        let tag = isCreator ? " (방장)" : ""

        return Button {
            toggleMember(p, isMember: isMember, isCreator: isCreator)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isMember ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isMember ? catColor("work") : Moim.line)
                Text(String(p.name.prefix(3)))
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.name + tag)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Moim.ink)
                    Text(p.memberType)
                        .font(.system(size: 11))
                        .foregroundColor(Moim.sub)
                }
                Spacer()
                Text(isMember ? "참여" : "초대 가능")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isMember ? catColor("work") : Moim.sub)
            }
            .padding(.vertical, 8)
            .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
        }
        .buttonStyle(.plain)
        .disabled(isCreator)
        .opacity(isCreator ? 0.65 : 1)
    }

    private func toggleMember(_ p: Profile, isMember: Bool, isCreator: Bool) {
        guard !isCreator else { return }
        if isMember {
            vm.removeRoomMember(roomId: room.id, userId: p.id)
        } else {
            vm.inviteRoomMember(roomId: room.id, userId: p.id)
        }
    }
}

// 방 구성원 초대/제거 선택 시트 (일반 모임방 설정용 — 관리자 콘솔과 별도)
struct RoomMemberPicker: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let mode: Mode
    let onClose: () -> Void
    enum Mode { case invite, remove }

    @State private var confirmRemove: Profile?

    private var candidates: [Profile] {
        let memberIds = Set(vm.roomMemberIds)
        switch mode {
        case .invite:
            return vm.profilesById.values
                .filter {
                    $0.id != MoimRepository.currentUserId()
                        && ($0.approved ?? true)
                        && !memberIds.contains($0.id)
                }
                .sorted { $0.name < $1.name }
        case .remove:
            return vm.roomMemberIds.compactMap { vm.profilesById[$0] }
                .sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if candidates.isEmpty {
                    Text(mode == .invite ? "초대할 수 있는 회원가 없습니다." : "구성원이 없습니다.")
                        .font(.system(size: 13)).foregroundColor(Moim.sub)
                }
                ForEach(candidates) { p in
                    HStack(spacing: 10) {
                        Text(String(p.name.prefix(3)))
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name + (p.id == room.createdBy ? " (방장)" : "")).font(.system(size: 14, weight: .semibold)).foregroundColor(Moim.ink)
                            Text(p.memberType).font(.system(size: 11)).foregroundColor(Moim.sub)
                        }
                        Spacer()
                        if mode == .invite {
                            Button("초대") { vm.inviteRoomMember(roomId: room.id, userId: p.id) }
                                .font(.system(size: 13, weight: .bold)).foregroundColor(catColor("work"))
                        } else if p.id != room.createdBy {
                            Button("제거") { confirmRemove = p }
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.admin)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(mode == .invite ? "구성원 초대" : "구성원 제거")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { onClose() } } }
            .confirmationDialog("‘\(confirmRemove?.name ?? "")’ 님을 이 방에서 제거할까요?",
                                isPresented: Binding(get: { confirmRemove != nil }, set: { if !$0 { confirmRemove = nil } }),
                                titleVisibility: .visible) {
                Button("구성원 제거", role: .destructive) {
                    if let p = confirmRemove { vm.removeRoomMember(roomId: room.id, userId: p.id) }
                    confirmRemove = nil
                }
                Button("취소", role: .cancel) { confirmRemove = nil }
            }
        }
        .onAppear { vm.loadRoomMembers(room.id) }
    }
}
