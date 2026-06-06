import SwiftUI
import PhotosUI

// =====================================================================
//  설정 화면 — 내 정보 변경 / 방 순서 / 회원 검색(1:1 DM)
//  web index.html 의 renderMyInfo / renderOrderTab / renderMemberSearch 를 미러링
// =====================================================================
struct SettingsView: View {
    @ObservedObject var vm: MoimViewModel
    let pinRooms: [Room]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("설정", selection: $vm.settingsTab) {
                    Text("내 정보").tag("myInfo")
                    Text("방 순서").tag("order")
                    Text("회원 검색").tag("search")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Moim.paper)

                Group {
                    switch vm.settingsTab {
                    case "order":  PinOrderTab(vm: vm, rooms: pinRooms)
                    case "search": MemberSearchTab(vm: vm) { dismiss() }
                    default:       MyInfoTab(vm: vm) { dismiss() }
                    }
                }
            }
            .background(Moim.paper.ignoresSafeArea())
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}

// ── 내 정보 변경 (이름·이메일·전화번호 읽기전용 / 직군·자기소개·아바타 변경 + 회원 탈퇴) ──
struct MyInfoTab: View {
    @ObservedObject var vm: MoimViewModel
    let onDismiss: () -> Void

    @State private var intro = ""
    @State private var memberType = ""
    @State private var color = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var pendingAdjustImage: UIImage?
    @State private var showAvatarAdjust = false
    @State private var avatarData: Data?
    @State private var avatarCleared = false
    @State private var newPw = ""
    @State private var newPw2 = ""
    @State private var pwMsg = ""
    @State private var pwMsgIsError = true
    @State private var showDelete = false

    @ObservedObject private var theme = ThemeManager.shared
    private var me: Profile? { vm.myProfile }
    private var isSuper: Bool { me?.role == "superadmin" }

    // 미리보기용 가상 프로필 (선택한 색상·사진 반영)
    private var previewColor: Color {
        Color(hexString: color) ?? personColor(me)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 화면 테마 (🌙 다크 / ☀️ 라이트)
                Toggle(isOn: Binding(get: { theme.dark }, set: { theme.setDark($0) })) {
                    Text(theme.dark ? "🌙 다크 모드" : "☀️ 라이트 모드").font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink)
                }
                .tint(Moim.accent)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))

                // 아바타 + 색상 팔레트 + 사진 선택/제거
                VStack(spacing: 9) {
                    Group {
                        if let d = avatarData, let ui = UIImage(data: d) {
                            Image(uiImage: ui).resizable().scaledToFill()
                        } else if !avatarCleared, let u = me?.avatarUrl, !u.isEmpty, let url = URL(string: u) {
                            AsyncImage(url: url) { i in i.resizable().scaledToFill() } placeholder: { previewColor }
                        } else {
                            previewColor.overlay(
                                Text(initials(me?.name)).font(.system(size: 24, weight: .bold)).foregroundColor(.white))
                        }
                    }
                    .frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 26))

                    HStack(spacing: 8) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("사진 선택").font(.system(size: 13, weight: .bold)).foregroundColor(Moim.accent)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Moim.bg).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        if avatarData != nil || (!avatarCleared && (me?.avatarUrl?.isEmpty == false)) {
                            Button("사진 제거") { avatarData = nil; photoItem = nil; avatarCleared = true }
                                .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.admin)
                        }
                    }
                    // 색상 팔레트
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ROOM_COLORS, id: \.self) { hex in
                                let sel = hex.lowercased() == color.lowercased()
                                Circle().fill(Color(hexString: hex) ?? Moim.sub)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Moim.ink, lineWidth: sel ? 3 : 0))
                                    .onTapGesture { color = hex }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                field("이름 (변경 불가)", me?.name ?? "")
                field("이메일 (변경 불가)", MoimRepository.currentUserEmail() ?? "")
                field("전화번호 (변경 불가)", me?.phone ?? "")

                Text("직군").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
                Picker("직군", selection: $memberType) {
                    ForEach(MTYPE_ORDER, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))

                Text("자기소개").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
                TextEditor(text: $intro)
                    .frame(minHeight: 72).font(.system(size: 14))
                    .padding(6).background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))

                Button {
                    vm.saveMyInfo(intro: intro, memberType: memberType, color: color, avatarData: avatarData,
                                  avatarExt: "jpg", clearAvatar: avatarCleared) {
                        avatarData = nil; avatarCleared = false
                    }
                } label: {
                    Text("내 정보 저장")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Moim.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Divider().background(Moim.line).padding(.vertical, 6)

                // 비밀번호 변경 (전체관리자는 변경 불가)
                Text("비밀번호 변경").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
                if isSuper {
                    Text("전체관리자 계정의 비밀번호는 변경할 수 없습니다.")
                        .font(.system(size: 12.5)).foregroundColor(Moim.sub)
                } else {
                    SecureField("새 비밀번호 (6자 이상)", text: $newPw).textFieldStyle(.roundedBorder)
                    SecureField("새 비밀번호 확인", text: $newPw2).textFieldStyle(.roundedBorder)
                    if !pwMsg.isEmpty {
                        Text(pwMsg).font(.system(size: 12.5)).foregroundColor(pwMsgIsError ? Moim.admin : catColor("work"))
                    }
                    Button("비밀번호 변경") { changePassword() }
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Moim.accent)
                }

                Divider().background(Moim.line).padding(.vertical, 6)

                HStack {
                    Spacer()
                    Button("회원 탈퇴") { showDelete = true }
                        .font(.system(size: 14, weight: .bold)).foregroundColor(Moim.admin)
                    Spacer()
                }
            }
            .padding(16)
        }
        .onAppear {
            intro = me?.intro ?? ""
            memberType = me?.memberType ?? MTYPE_ORDER.first ?? "의국"
            color = me?.color ?? ""
            if color.isEmpty, let m = me { color = typeHex(m.memberType) }
        }
        .onChange(of: photoItem) { _ in
            Task {
                guard let item = photoItem else { return }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    pendingAdjustImage = ui
                    showAvatarAdjust = true
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showAvatarAdjust) {
            if let img = pendingAdjustImage {
                AvatarAdjustView(
                    sourceImage: img,
                    onDismiss: {
                        showAvatarAdjust = false
                        pendingAdjustImage = nil
                    },
                    onConfirm: { data in
                        avatarData = data
                        avatarCleared = false
                        showAvatarAdjust = false
                        pendingAdjustImage = nil
                    }
                )
            }
        }
        .alert("회원 탈퇴", isPresented: $showDelete) {
            Button("취소", role: .cancel) {}
            Button("탈퇴", role: .destructive) { onDismiss(); vm.deleteAccount() }
        } message: {
            Text("정말 탈퇴할까요?\n계정이 비활성화되어 다시 로그인할 수 없으며 모든 방에서 나가집니다.")
        }
    }

    private func changePassword() {
        pwMsg = ""
        if newPw.count < 6 { pwMsgIsError = true; pwMsg = "비밀번호는 6자 이상이어야 합니다."; return }
        if newPw != newPw2 { pwMsgIsError = true; pwMsg = "비밀번호가 일치하지 않습니다."; return }
        vm.changeMyPassword(newPw) { result in
            switch result {
            case .success(let m): pwMsgIsError = false; pwMsg = m; newPw = ""; newPw2 = ""
            case .failure(let m): pwMsgIsError = true; pwMsg = m
            }
        }
    }

    @ViewBuilder
    private func field(_ label: String, _ value: String) -> some View {
        Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
        Text(value).font(.system(size: 14)).foregroundColor(Moim.ink).opacity(0.65)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 10)
            .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))
    }
}

// ── 회원 검색 (전체 명단 · 이름/직종 정렬 · 검색 · 메시지=1:1 DM) ──
struct MemberSearchTab: View {
    @ObservedObject var vm: MoimViewModel
    let onStartDirect: () -> Void

    // 회원 검색에는 전체관리자도 포함(일반 회원이 전체관리자에게 메시지 가능). 본인·미승인·탈퇴만 제외.
    private var baseList: [Profile] {
        vm.profilesById.values.filter {
            $0.id != MoimRepository.currentUserId()
                && $0.approved == true
                && $0.withdrawn != true
        }
    }
    private var filtered: [Profile] {
        let q = vm.memberSearchQ.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return baseList }
        return baseList.filter { $0.name.lowercased().contains(q) }
    }
    // 직종별 그룹 순서 (MTYPE_ORDER 우선 + 기타 직군)
    private var groupedSections: [(type: String, members: [Profile])] {
        var groups: [String: [Profile]] = [:]
        for p in filtered { groups[p.memberType.isEmpty ? "기타" : p.memberType, default: []].append(p) }
        let order = MTYPE_ORDER.filter { groups[$0] != nil } + groups.keys.filter { !MTYPE_ORDER.contains($0) }.sorted()
        return order.map { ($0, (groups[$0] ?? []).sorted(by: byName)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TextField("🔍 이름으로 검색", text: $vm.memberSearchQ)
                    .textFieldStyle(.roundedBorder)
                    .padding(.bottom, 10)
                HStack(spacing: 7) {
                    sortButton("이름순", "name")
                    sortButton("직종별", "type")
                }
                .padding(.bottom, 12)

                if filtered.isEmpty {
                    Text(vm.memberSearchQ.trimmingCharacters(in: .whitespaces).isEmpty ? "표시할 회원이 없습니다." : "검색 결과가 없습니다.")
                        .font(.system(size: 13)).foregroundColor(Moim.sub).padding(.vertical, 10)
                } else if vm.memberSearchSort == "type" {
                    ForEach(groupedSections, id: \.type) { sec in
                        Text("\(sec.type) · \(sec.members.count)명")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                            .padding(.top, 8).padding(.bottom, 4)
                        ForEach(sec.members) { memberRow($0) }
                    }
                } else {
                    ForEach(filtered.sorted(by: byName)) { memberRow($0) }
                }
            }
            .padding(16)
        }
    }

    private func sortButton(_ title: String, _ key: String) -> some View {
        let on = vm.memberSearchSort == key
        return Button { vm.memberSearchSort = key } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(on ? .white : Moim.accent)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(on ? Moim.accent : Moim.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Moim.line, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func memberRow(_ p: Profile) -> some View {
        HStack(spacing: 11) {
            PersonAvatarView(profile: p)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink)
                Text(p.memberType).font(.system(size: 11.5)).foregroundColor(Moim.sub)
                MemberContactLines(profile: p)
                if let intro = p.intro, !intro.isEmpty {
                    Text(intro).font(.system(size: 11.5)).foregroundColor(Moim.sub).lineLimit(1)
                }
            }
            Spacer()
            Button {
                vm.startDirect(otherId: p.id)
                onStartDirect()
            } label: {
                Text("메시지").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Moim.accent).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }
}

// 직군 → 색상의 hex 문자열 (내 정보 색상 기본값 계산용)
private func typeHex(_ memberType: String) -> String {
    switch memberType {
    case "교실": return "#b5651d"
    case "의국": return "#4a6fa5"
    case "심리실": return "#6d597a"
    case "연구실": return "#3d8361"
    case "PA": return "#0d8a8a"
    case "간호사": return "#c0452f"
    case "SW": return "#9a6a00"
    case "보조원": return "#777777"
    case "생명사랑": return "#1f9b8e"
    case "비서": return "#a0526d"
    case "의국동문": return "#5b7c99"
    case "심리실 동문": return "#8a7aa0"
    default: return "#8a817a"
    }
}
