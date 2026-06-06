import SwiftUI

enum AdminConsoleTab: String, CaseIterable {
    case approval = "가입 승인"
    case members = "회원 관리"
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
    @State private var deactivateTarget: Profile?
    @State private var reactivateTarget: Profile?

    // 전체관리자=2탭 / 관리자=가입 승인만
    private var allowedTabs: [AdminConsoleTab] {
        vm.isSuperAdmin ? AdminConsoleTab.allCases : [.approval]
    }

    // 회원 관리 명단: 승인됨 + 미탈퇴 (전체관리자 제외). 이름순일 때 관리자(admin)를 맨 위로.
    private var members: [Profile] {
        vm.profilesById.values
            .filter { $0.role != "superadmin" && $0.withdrawn != true && ($0.approved == true) }
            .sorted { a, b in
                let aa = a.role == "admin" ? 0 : 1
                let bb = b.role == "admin" ? 0 : 1
                return aa != bb ? aa < bb : byName(a, b)
            }
    }

    // 직종별 정렬 그룹 (MTYPE_ORDER 우선 + 기타 직군)
    private var memberSections: [(type: String, members: [Profile])] {
        var groups: [String: [Profile]] = [:]
        for p in members { groups[p.memberType.isEmpty ? "기타" : p.memberType, default: []].append(p) }
        let order = MTYPE_ORDER.filter { groups[$0] != nil } + groups.keys.filter { !MTYPE_ORDER.contains($0) }.sorted()
        return order.map { ($0, (groups[$0] ?? []).sorted(by: byName)) }
    }

    // 비활성(탈퇴) 회원 — 복구 대상
    private var withdrawnMembers: [Profile] {
        vm.profilesById.values
            .filter { $0.role != "superadmin" && $0.withdrawn == true }
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
        .confirmationDialog(
            "‘\(deactivateTarget?.name ?? "")’ 님의 계정을 비활성화할까요?\n로그인·활동이 막히고 모든 방에서 제외됩니다.",
            isPresented: Binding(get: { deactivateTarget != nil }, set: { if !$0 { deactivateTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("계정 비활성화", role: .destructive) {
                if let p = deactivateTarget { vm.adminDeactivate(p.id) }
                deactivateTarget = nil
            }
            Button("취소", role: .cancel) { deactivateTarget = nil }
        }
        .confirmationDialog(
            "‘\(reactivateTarget?.name ?? "")’ 님의 계정을 복구할까요?\n로그인·활동이 다시 가능해지고 승인 상태가 됩니다.\n(이전 메시지·자료가 그대로 연결됩니다.)",
            isPresented: Binding(get: { reactivateTarget != nil }, set: { if !$0 { reactivateTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("복구") {
                if let p = reactivateTarget { vm.reactivate(p.id) }
                reactivateTarget = nil
            }
            Button("취소", role: .cancel) { reactivateTarget = nil }
        }
    }

    @ViewBuilder
    private var membersContent: some View {
        VStack(alignment: .leading, spacing: 13) {
            card(title: "👥 회원 관리 · \(members.count)명 · 관리자 지위 지정 / 계정 비활성화") {
                // 이름순 / 직종별 정렬 토글
                HStack(spacing: 7) {
                    memSortButton("이름순", "name")
                    memSortButton("직종별", "type")
                    Spacer()
                }
                .padding(.bottom, 10)
                if members.isEmpty {
                    Text("승인된 회원이 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub)
                } else if vm.memAdminSort == "type" {
                    ForEach(memberSections, id: \.type) { sec in
                        Text("\(sec.type) · \(sec.members.count)명")
                            .font(.system(size: 10.5, weight: .bold)).foregroundColor(Moim.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6).padding(.bottom, 2)
                        ForEach(sec.members) { p in memberRow(p) }
                    }
                } else {
                    ForEach(members) { p in memberRow(p) }
                }
            }
            if !withdrawnMembers.isEmpty {
                card(title: "🚫 비활성 회원 · \(withdrawnMembers.count)명 · 복구하면 이전 대화에 다시 연결됩니다") {
                    ForEach(withdrawnMembers) { p in withdrawnRow(p) }
                }
            }
        }
    }

    private func withdrawnRow(_ p: Profile) -> some View {
        HStack(spacing: 10) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Moim.sub).clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(p.name).font(.system(size: 13.5, weight: .bold)).foregroundColor(Moim.ink)
                Text("\(p.memberType) · 비활성").font(.system(size: 11.5)).foregroundColor(Moim.sub)
                MemberContactLines(profile: p)
            }
            Spacer()
            Button { reactivateTarget = p } label: {
                Text("복구").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(catColor("work")).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .overlay(Divider().background(Moim.line.opacity(0.5)), alignment: .bottom)
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

    private func memSortButton(_ title: String, _ key: String) -> some View {
        let on = vm.memAdminSort == key
        return Button { vm.memAdminSort = key } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(on ? .white : Moim.accent)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(on ? Moim.accent : Moim.bg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func memberRow(_ p: Profile) -> some View {
        let role: (Color, String) = p.role == "superadmin" ? (Moim.admin, "전체관리자")
            : p.role == "admin" ? (Color(hex: 0xB5651D), "관리자") : (Moim.line, "회원")
        let pending = p.approved == false
        return HStack(spacing: 10) {
            PersonAvatarView(profile: p, size: 36, corner: 11, font: 13)
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
                MemberContactLines(profile: p)
                if let intro = p.intro, !intro.isEmpty {
                    Text(intro).font(.system(size: 11)).foregroundColor(Moim.sub).lineLimit(1)
                }
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
}

// 방 구성원 초대/제거 선택 시트 (모임방 설정용)
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
                            Text(p.name + (p.id == room.createdBy ? " (개설자)" : "")).font(.system(size: 14, weight: .semibold)).foregroundColor(Moim.ink)
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
