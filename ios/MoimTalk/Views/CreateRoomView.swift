import SwiftUI
import UIKit

// 모임방 만들기 (카톡처럼 누구나) — 이름 + 방표식(색상·사진) + 참여 회원 선택
struct CreateRoomView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void

    @State private var name = ""
    @State private var search = ""
    @State private var byType = false
    @State private var selected: Set<String> = []
    @State private var color = ROOM_COLORS[1]
    @State private var iconData: Data?
    @State private var iconAdjustImage: UIImage?
    @FocusState private var searchFocused: Bool

    @ViewBuilder private func sortBtn(_ title: String, _ type: Bool) -> some View {
        let on = byType == type
        Button { byType = type; searchFocused = false } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(moimToggleText(selected: on, lightOn: .white, lightOff: Moim.accent))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(moimToggleBg(selected: on, lightOn: Moim.accent, lightOff: Moim.bg))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func memberRow(_ p: Profile) -> some View {
        let on = selected.contains(p.id)
        HStack(spacing: 10) {
            Text(String(p.name.prefix(3)))
                .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Moim.ink)
                MemberTypeIntroLines(profile: p)
            }
            Spacer()
            Text(on ? "✓" : "○").foregroundColor(moimToggleText(selected: on, lightOn: Moim.accent, lightOff: Moim.line)).fontWeight(.bold)
        }
        .padding(10)
        .background(moimToggleBg(selected: on, lightOn: Moim.hl))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(ThemeManager.shared.dark && on ? moimToggleBorder(selected: true) : Color.clear, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .padding(.bottom, 7)
        .contentShape(Rectangle())
        .onTapGesture {
            searchFocused = false   // 회원 탭 = 다른 곳 터치 → 키보드 내림
            if on { selected.remove(p.id) } else { selected.insert(p.id) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("새 모임방").font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.paper)
            Divider().background(Moim.line)

            VStack(alignment: .leading, spacing: 0) {
                TextField("방 이름 (예: 우울증 연구모임)", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .padding(.bottom, 14)

                RoomAppearanceEditor(
                    name: name, color: $color,
                    previewData: $iconData,
                    adjustSourceImage: $iconAdjustImage,
                    existingIconUrl: nil,
                    onClear: { iconData = nil }
                )
                .padding(.bottom, 14)

                Text("참여 회원 선택").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
                    .padding(.bottom, 8)

                TextField("🔍 이름·직군으로 검색", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                    .onSubmit { searchFocused = false }
                    .padding(.bottom, 8)

                HStack(spacing: 7) {
                    sortBtn("가나다순", false)
                    sortBtn("직군별", true)
                    Spacer()
                }
                .padding(.bottom, 8)

                ScrollView {
                    let q = search.trimmingCharacters(in: .whitespaces)
                    let people = q.isEmpty ? vm.otherProfiles
                        : vm.otherProfiles.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.memberType.localizedCaseInsensitiveContains(q) }
                    if people.isEmpty {
                        Text("표시할 회원가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub).padding(8)
                    } else if byType {
                        let groups = Dictionary(grouping: people) { $0.memberType.isEmpty ? "기타" : $0.memberType }
                        let order = MTYPE_ORDER.filter { groups[$0] != nil } + groups.keys.filter { !MTYPE_ORDER.contains($0) }.sorted()
                        ForEach(order, id: \.self) { t in
                            HStack {
                                Text("\(t) · \(groups[t]?.count ?? 0)명")
                                    .font(.system(size: 11, weight: .bold)).foregroundColor(typeColor(t))
                                Spacer()
                            }
                            .padding(.top, 6).padding(.bottom, 2)
                            ForEach(groups[t] ?? []) { p in memberRow(p) }
                        }
                    } else {
                        ForEach(people) { p in memberRow(p) }
                    }
                }
                // 검색 입력 중 목록 탭/드래그하면 키보드 내림 (@FocusState 로 확실히 해제)
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded { searchFocused = false })

                Button {
                    let nm = name.trimmingCharacters(in: .whitespaces)
                    vm.createRoom(name: nm.isEmpty ? "새 모임방" : nm, memberIds: Array(selected), color: color, iconData: iconData, iconName: "icon.jpg") { onBack() }
                } label: {
                    Text("방 만들기 (\(selected.count + 1)명)")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Moim.accent).clipShape(RoundedRectangle(cornerRadius: 13))
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
        .background(Moim.paper.ignoresSafeArea())
        // 빈 곳/목록 등 다른 곳을 탭하면 키보드 내림 (텍스트필드 탭은 그대로 포커스됨)
        .onTapGesture { searchFocused = false }
        .fullScreenCover(isPresented: Binding(
            get: { iconAdjustImage != nil },
            set: { if !$0 { iconAdjustImage = nil } }
        )) {
            if let img = iconAdjustImage {
                AvatarAdjustView(
                    sourceImage: img,
                    onDismiss: { iconAdjustImage = nil },
                    onConfirm: { data in
                        iconData = data
                        iconAdjustImage = nil
                    }
                )
            }
        }
    }
}
