import SwiftUI

// 병실현황 — 잔여병실 메모 + 당직표
struct WardStatusView: View {
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void

    @State private var tab = "beds"
    @State private var editing = false
    @State private var draft = ""

    private var publishLabel: String? {
        guard let iso = vm.wardStatusUpdatedAt else { return nil }
        return CalDate.detailTimeLabel(iso)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("병실현황").font(.system(size: 18, weight: .bold))
                Spacer()
                if tab == "beds" && !editing && canEditWard(vm.myProfile) {
                    Button("편집") { draft = vm.wardStatus; editing = true }.font(.system(size: 15, weight: .bold))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.paper)
            Divider().background(Moim.line)

            WardSegmentBar(tab: $tab) { editing = false }

            if tab == "duty" {
                WardDutyPane(vm: vm)
            } else if editing {
                VStack(spacing: 12) {
                    TextEditor(text: $draft)
                        .font(.system(size: 15))
                        .padding(8)
                        .background(Moim.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Moim.line))
                    HStack(spacing: 10) {
                        Button { editing = false } label: {
                            Text("취소").frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Moim.line).foregroundColor(Moim.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button { vm.saveWardStatus(draft) { editing = false } } label: {
                            Text("게시").frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Moim.accent).foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
            } else {
                ScrollView {
                    WardStatusDocument(content: vm.wardStatus, publishLabel: publishLabel)
                        .padding(16)
                }
                .background(Moim.bg)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
        .onAppear { vm.loadWardStatus() }
    }
}

private struct WardSegmentBar: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Binding var tab: String
    var onChange: () -> Void

    var body: some View {
        Group {
            if theme.dark {
                HStack(spacing: 8) {
                    segPill(label: "잔여병실", id: "beds")
                    segPill(label: "당직표", id: "duty")
                }
            } else {
                HStack(spacing: 0) {
                    coloredSeg(label: "잔여병실", id: "beds", color: Moim.orange)
                    Rectangle().fill(Color.white.opacity(0.28)).frame(width: 1)
                    coloredSeg(label: "당직표", id: "duty", color: Color(hex: 0x4A6FA5))
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func segPill(label: String, id: String) -> some View {
        let on = tab == id
        return Button {
            tab = id
            onChange()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(moimDarkSegText(selected: on))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(moimDarkSegBg())
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(moimDarkSegBorder(), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// 변경 전 웹 triseg 형식 — 잔여병실(주황)·당직표(파랑) 색상 바
    private func coloredSeg(label: String, id: String, color: Color) -> some View {
        let on = tab == id
        return Button {
            tab = id
            onChange()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(on ? 1 : 0.45))
        }
        .buttonStyle(.plain)
    }
}

private struct WardDutyPane: View {
    @ObservedObject var vm: MoimViewModel
    @State private var monthAnchor = CalDate.today()
    @State private var editDate: Date?
    @State private var editProf = ""
    @State private var editResDay = ""
    @State private var editResNight = ""
    @State private var editOut1 = ""
    @State private var editOut2 = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { shiftMonth(-1) } label: { Text("‹").font(.system(size: 20)).foregroundColor(Moim.sub) }
                Spacer()
                Text(monthTitle).font(.system(size: 16, weight: .heavy)).foregroundColor(Moim.ink)
                Spacer()
                Button { shiftMonth(1) } label: { Text("›").font(.system(size: 20)).foregroundColor(Moim.sub) }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)

            ScrollViewReader { proxy in
                VStack(spacing: 6) {
                    todayDutyQuickButton(proxy: proxy)
                        .padding(.horizontal, 16)
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(daysInMonth, id: \.self) { day in
                                dutyRow(day).id(dateKey(day))
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    .background(Moim.bg)
                }
            }
        }
        .onAppear {
            vm.loadWardDuties(month: monthAnchor)
            vm.loadWardTodayDuty()
        }
        .onChange(of: monthAnchor) { vm.loadWardDuties(month: $0) }
        .sheet(item: Binding(
            get: { editDate.map { EditDayWrapper(date: $0) } },
            set: { editDate = $0?.date }
        )) { wrap in
            dutyEditSheet(wrap.date)
        }
    }

    private var monthTitle: String {
        let y = CalDate.cal.component(.year, from: monthAnchor)
        let m = CalDate.cal.component(.month, from: monthAnchor)
        return "\(y)년 \(m)월"
    }

    private var daysInMonth: [Date] {
        let cal = CalDate.cal
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start) else { return [] }
        return (0..<range.count).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func todayDutyQuickButton(proxy: ScrollViewProxy) -> some View {
        let today = CalDate.today()
        let duty = vm.wardTodayDuty
        let dow = ["일", "월", "화", "수", "목", "금", "토"][CalDate.cal.component(.weekday, from: today) - 1]
        let m = CalDate.cal.component(.month, from: today)
        let d = CalDate.cal.component(.day, from: today)
        let off = isWardDutyOffDay(today)
        let preview = dutyTodayPreview(duty, offDay: off)
        let colors = wardDutyTodayCardColors()
        return Button {
            scrollToToday(proxy)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("오늘 당직").font(.system(size: 16, weight: .heavy)).foregroundColor(moimSurfaceAccentText())
                    Spacer()
                    Text("\(m)/\(d) (\(dow))").font(.system(size: 12)).foregroundColor(Moim.sub)
                }
                Text(preview)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Moim.ink)
                    .lineLimit(4)
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.0)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.1, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func scrollToToday(_ proxy: ScrollViewProxy) {
        let today = CalDate.today()
        let cal = CalDate.cal
        if !cal.isDate(monthAnchor, equalTo: today, toGranularity: .month) {
            monthAnchor = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
        }
        vm.loadWardTodayDuty()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                proxy.scrollTo(dateKey(today), anchor: .center)
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = CalDate.cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    private func dateKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = CalDate.kst
        return f.string(from: d)
    }

    private func dutyRow(_ day: Date) -> some View {
        let key = dateKey(day)
        let duty = vm.wardDuties[key]
        let tone = wardDutyTone(day)
        let isToday = CalDate.sameDay(day, CalDate.today())
        let dow = ["일", "월", "화", "수", "목", "금", "토"][CalDate.cal.component(.weekday, from: day) - 1]
        let label = "\(CalDate.cal.component(.month, from: day))/\(CalDate.cal.component(.day, from: day)) (\(dow))"
        let colors = wardDutyRowColors(tone, isToday: isToday)
        let toneLabel = tone == .publicHoliday ? "공휴일" : (tone == .weekend ? "주말" : nil)
        let off = isWardDutyOffDay(day)
        let hasDuty = duty.map {
            !$0.profDay.isEmpty || !$0.residentDay.isEmpty || !$0.residentNight.isEmpty
                || !$0.residentOutpatient1.isEmpty || !$0.residentOutpatient2.isEmpty
        } ?? false
        let canEdit = canEditWardDuty(vm.myProfile)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Text(label).font(.system(size: 14, weight: .bold))
                        .foregroundColor(tone == .weekday ? Moim.ink : wardDutyOffDayInk())
                    if isToday {
                        Text("오늘").font(.system(size: 11, weight: .bold)).foregroundColor(moimSurfaceAccentText())
                    }
                }
                Spacer()
                if let tl = toneLabel {
                    Text(tl).font(.system(size: 10, weight: .bold)).foregroundColor(wardDutyToneBadge())
                }
                if canEdit {
                    Button(hasDuty ? "수정" : "입력") {
                        editProf = duty?.profDay ?? ""
                        editResDay = duty?.residentDay ?? ""
                        editResNight = duty?.residentNight ?? ""
                        editOut1 = duty?.residentOutpatient1 ?? ""
                        editOut2 = duty?.residentOutpatient2 ?? ""
                        editDate = day
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(moimSurfaceAccentText())
                }
            }
            Text(dutyProfDisplay(duty?.profDay)).font(.system(size: 18, weight: .bold)).foregroundColor(Moim.ink)
            if off {
                Text("당직").font(.system(size: 10)).foregroundColor(Moim.sub)
                Text(dutyResidentDisplay(duty?.residentNight)).font(.system(size: 17, weight: .bold)).foregroundColor(Moim.ink)
            } else {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("낮").font(.system(size: 10)).foregroundColor(Moim.sub)
                        Text(dutyResidentDisplay(duty?.residentDay)).font(.system(size: 16, weight: .bold)).foregroundColor(Moim.ink)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("당직").font(.system(size: 10)).foregroundColor(Moim.sub)
                        Text(dutyResidentDisplay(duty?.residentNight)).font(.system(size: 16, weight: .bold)).foregroundColor(Moim.ink)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("외래").font(.system(size: 10)).foregroundColor(Moim.sub)
                        Text(dutyOutpatientDisplay(duty)).font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink).lineLimit(2)
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.0)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colors.1, lineWidth: 1))
    }

    private func dutyEditSheet(_ day: Date) -> some View {
        let dow = ["일", "월", "화", "수", "목", "금", "토"][CalDate.cal.component(.weekday, from: day) - 1]
        let tone = wardDutyTone(day)
        let toneLbl = tone == .publicHoliday ? "공휴일" : (tone == .weekend ? "주말" : "")
        let title = "\(CalDate.cal.component(.month, from: day))/\(CalDate.cal.component(.day, from: day)) (\(dow)) 당직\(toneLbl.isEmpty ? "" : " · \(toneLbl)")"
        let off = isWardDutyOffDay(day)
        let faculty = dutyMembersByType(vm.profilesById, memberType: "교실")
        let residents = dutyMembersByType(vm.profilesById, memberType: "의국")
        let facultyNames = [""] + faculty.map(\.name)
        let residentNames = [""] + residents.map(\.name)
        return NavigationView {
            Form {
                Section("교원 당직 (교실 · 1인)") {
                    Picker("교원", selection: $editProf) {
                        ForEach(facultyNames, id: \.self) { n in
                            Text(n.isEmpty ? "— (없음)" : n).tag(n)
                        }
                    }
                }
                Section("전공의 (의국)") {
                    if off {
                        Picker("당직 (1인)", selection: $editResNight) {
                            ForEach(residentNames, id: \.self) { n in
                                Text(n.isEmpty ? "— (없음)" : n).tag(n)
                            }
                        }
                    } else {
                        Picker("낮당직 (1인)", selection: $editResDay) {
                            ForEach(residentNames, id: \.self) { n in
                                Text(n.isEmpty ? "— (없음)" : n).tag(n)
                            }
                        }
                        Picker("당직 (1인)", selection: $editResNight) {
                            ForEach(residentNames, id: \.self) { n in
                                Text(n.isEmpty ? "— (없음)" : n).tag(n)
                            }
                        }
                        Picker("외래 1", selection: $editOut1) {
                            ForEach(residentNames, id: \.self) { n in
                                Text(n.isEmpty ? "— (없음)" : n).tag(n)
                            }
                        }
                        Picker("외래 2", selection: $editOut2) {
                            ForEach(residentNames, id: \.self) { n in
                                Text(n.isEmpty ? "— (없음)" : n).tag(n)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { editDate = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let key = dateKey(day)
                        let dayDuty = off ? "" : editResDay
                        let o1 = off ? "" : editOut1
                        let o2 = off ? "" : editOut2
                        vm.saveWardDuty(dutyDate: key, profDay: editProf, residentDay: dayDuty, residentNight: editResNight,
                                        residentOutpatient1: o1, residentOutpatient2: o2) { editDate = nil }
                    }
                }
            }
        }
    }

}

private struct EditDayWrapper: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private struct WardStatusDocument: View {
    let content: String
    let publishLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xEA7317)).frame(height: 3)
            if let label = publishLabel {
                Text("게시").font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                    .padding(.top, 16)
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Moim.ink)
                    .lineSpacing(4)
                    .padding(.top, 4)
                Divider().background(Moim.line).padding(.vertical, 14)
            } else {
                Spacer().frame(height: 16)
            }
            if content.isEmpty {
                VStack(spacing: 8) {
                    Text("🛏").font(.system(size: 36))
                    Text("작성된 내용이 없습니다").font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
                    Text("우측 상단 ‘편집’을 눌러\n잔여 병실 현황을 작성하세요.")
                        .font(.system(size: 13)).foregroundColor(Moim.sub)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Text(content)
                    .font(.system(size: 15))
                    .foregroundColor(Moim.ink)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Moim.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Moim.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
