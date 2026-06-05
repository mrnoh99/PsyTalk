import SwiftUI

enum AdminConsoleTab: String, CaseIterable {
    case manage = "방 관리"
    case approval = "가입 승인"
}

// 관리자 콘솔 (전체관리자) — iPad/Mac·iPhone 공통
struct AdminPlaceholderView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void
    var initialTab: AdminConsoleTab = .manage

    @State private var tab: AdminConsoleTab = .manage
    @State private var showRename = false
    @State private var renameText = ""
    @State private var renameTargetId = ""
    // 방 관리: 구성원 초대 / 제거 / 삭제
    @State private var inviteRoom: Room?
    @State private var removeRoom: Room?
    @State private var deleteRoom: Room?

    private var members: [Profile] {
        vm.profilesById.values.sorted {
            if $0.role != $1.role { return $0.role < $1.role }
            return $0.name < $1.name
        }
    }

    private var pendingCount: Int {
        vm.profilesById.values.filter { $0.approved == false }.count
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

            Picker("탭", selection: $tab) {
                ForEach(AdminConsoleTab.allCases, id: \.self) { t in
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

            ScrollView {
                Group {
                    switch tab {
                    case .manage: manageContent
                    case .approval: SignupApprovalView(vm: vm)
                    }
                }
                .padding(16)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .onAppear { tab = initialTab }
        .alert("이름 변경", isPresented: $showRename) {
            TextField("이름", text: $renameText)
            Button("저장") { vm.setName(renameTargetId, to: renameText) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("새 이름을 입력하세요.")
        }
        .sheet(item: $inviteRoom) { r in
            RoomMemberPicker(vm: vm, room: r, mode: .invite) { inviteRoom = nil }
        }
        .sheet(item: $removeRoom) { r in
            RoomMemberPicker(vm: vm, room: r, mode: .remove) { removeRoom = nil }
        }
        // 방 삭제 confirm (superadmin·모임방만)
        .confirmationDialog("‘\(deleteRoom?.name ?? "")’ 방을 삭제할까요?\n채팅·일정·자료가 모두 삭제되며 되돌릴 수 없습니다.",
                            isPresented: Binding(get: { deleteRoom != nil }, set: { if !$0 { deleteRoom = nil } }),
                            titleVisibility: .visible) {
            Button("방 삭제", role: .destructive) { if let r = deleteRoom { vm.deleteRoom(r) {} }; deleteRoom = nil }
            Button("취소", role: .cancel) { deleteRoom = nil }
        }
    }

    @ViewBuilder
    private var manageContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            card(title: "👥 멤버 (직군·역할) · \(members.count)명") {
                if members.isEmpty {
                    Text("멤버 정보가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
                } else {
                    ForEach(members) { p in memberRow(p) }
                }
            }
            card(title: "🏠 방 관리 · \(vm.rooms.count)개 · 방을 눌러 초대·제거·삭제") {
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
            : p.role == "admin" ? (Color(hex: 0xB5651D), "관리자") : (Moim.line, "멤버")
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
                // 지정 가능한 역할은 관리자·멤버 둘만 (전체관리자는 콘솔에서 지정 불가)
                Button("관리자") { vm.setRole(p.id, to: "admin") }
                Button("멤버") { vm.setRole(p.id, to: "user") }
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
        }
        .padding(.vertical, 8)
        .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
    }

    private func roomRow(_ r: Room) -> some View {
        let isDefault = r.category != "custom"   // 기본 방(전체공지·학술활동)은 삭제 불가
        return Menu {
            Button { inviteRoom = r } label: { Label("구성원 초대", systemImage: "person.badge.plus") }
            Button { removeRoom = r } label: { Label("구성원 제거", systemImage: "person.badge.minus") }
            if vm.isSuperAdmin && !isDefault {
                Button(role: .destructive) { deleteRoom = r } label: { Label("방 삭제", systemImage: "trash") }
            }
        } label: {
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
                    Text("\(catLabel(r.category)) · \(r.postPolicy)").font(.system(size: 11.5)).foregroundColor(Moim.sub)
                }
                Spacer()
                Text("⋯").font(.system(size: 18, weight: .bold)).foregroundColor(Moim.sub)
            }
            .padding(.vertical, 8)
            .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
        }
    }
}

// 방 구성원 초대/제거 선택 시트 (관리자 콘솔 + 일반 방 설정 공용)
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
                .filter { ($0.approved ?? true) && !memberIds.contains($0.id) }
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
                    Text(mode == .invite ? "초대할 수 있는 멤버가 없습니다." : "구성원이 없습니다.")
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
            // 구성원 제거 confirm
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
