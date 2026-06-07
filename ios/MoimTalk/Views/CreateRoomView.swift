import SwiftUI

// 모임방 만들기 (카톡처럼 누구나) — 이름 + 방표식(색상·사진) + 참여 회원 선택
struct CreateRoomView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void

    @State private var name = ""
    @State private var selected: Set<String> = []
    @State private var color = ROOM_COLORS[1]
    @State private var iconData: Data?

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
                    previewData: $iconData, existingIconUrl: nil,
                    onClear: { iconData = nil }
                )
                .padding(.bottom, 14)

                Text("참여 회원 선택").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
                    .padding(.bottom, 8)

                ScrollView {
                    let people = vm.otherProfiles
                    if people.isEmpty {
                        Text("표시할 회원가 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub).padding(8)
                    } else {
                        ForEach(people) { p in
                            let on = selected.contains(p.id)
                            HStack(spacing: 10) {
                                Text(String(p.name.prefix(3)))
                                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(p.name).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Moim.ink)
                                Spacer()
                                Text(p.memberType).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(typeColor(p.memberType)).clipShape(RoundedRectangle(cornerRadius: 5))
                                Text(on ? "✓" : "○").foregroundColor(moimToggleText(selected: on, lightOn: Moim.accent, lightOff: Moim.line)).fontWeight(.bold)
                            }
                            .padding(10)
                            .background(moimToggleBg(selected: on, lightOn: Moim.hl))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(ThemeManager.shared.dark && on ? Moim.line : Color.clear, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .padding(.bottom, 7)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if on { selected.remove(p.id) } else { selected.insert(p.id) }
                            }
                        }
                    }
                }

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
    }
}
