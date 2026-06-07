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
    @Binding var tab: String
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            seg("잔여병실", id: "beds")
            seg("당직표", id: "duty")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Moim.paper)
    }

    private func seg(_ label: String, id: String) -> some View {
        Button {
            tab = id
            onChange()
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tab == id ? Moim.ink : Moim.sub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tab == id ? Moim.yellow : Moim.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(tab == id ? Moim.yellow : Moim.line, lineWidth: 1))
        }
    }
}

private struct WardDutyPane: View {
    @ObservedObject var vm: MoimViewModel
    @State private var monthAnchor = CalDate.today()
    @State private var editDate: Date?
    @State private var editProf = ""
    @State private var editResident = ""
    @State private var editHoliday = false

    private let holidayTint = Color(hex: 0xFFE0B2)
    private let holidayBorder = Color(hex: 0xFFFF9800)
    private let holidayInk = Color(hex: 0xFFE65100)

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

            Text("날짜를 길게 눌러 당직을 입력·수정합니다.")
                .font(.system(size: 11.5)).foregroundColor(Moim.sub)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(daysInMonth, id: \.self) { day in
                        dutyRow(day)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .background(Moim.bg)
        }
        .onAppear { vm.loadWardDuties(month: monthAnchor) }
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
        let holiday = isWardDutyHoliday(day, isHolidayFlag: duty?.isHoliday == true)
        let isToday = CalDate.sameDay(day, CalDate.today())
        let dow = ["일", "월", "화", "수", "목", "금", "토"][CalDate.cal.component(.weekday, from: day) - 1]
        let label = "\(CalDate.cal.component(.month, from: day))/\(CalDate.cal.component(.day, from: day)) (\(dow))"
        let bg: Color = holiday ? holidayTint : (isToday ? Moim.yellow.opacity(0.45) : Moim.white)
        let border: Color = holiday ? holidayBorder : (isToday ? Moim.accent : Moim.line)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 14, weight: .bold)).foregroundColor(holiday ? holidayInk : Moim.ink)
                Spacer()
                if holiday {
                    Text("휴일").font(.system(size: 10, weight: .bold)).foregroundColor(holidayInk)
                }
            }
            Text("교수 낮당직: \(duty?.profDay.nilIfEmpty ?? "—")")
                .font(.system(size: 13)).foregroundColor(Moim.ink).lineLimit(2)
            Text("전공의 밤당직: \(duty?.residentNight.nilIfEmpty ?? "—")")
                .font(.system(size: 13)).foregroundColor(Moim.sub).lineLimit(2)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
        .onLongPressGesture(minimumDuration: 0.45) {
            guard canEditWard(vm.myProfile) else { return }
            editProf = duty?.profDay ?? ""
            editResident = duty?.residentNight ?? ""
            editHoliday = duty?.isHoliday == true || isWardDutyHoliday(day, isHolidayFlag: false)
            editDate = day
        }
    }

    private func dutyEditSheet(_ day: Date) -> some View {
        let dow = ["일", "월", "화", "수", "목", "금", "토"][CalDate.cal.component(.weekday, from: day) - 1]
        let title = "\(CalDate.cal.component(.month, from: day))/\(CalDate.cal.component(.day, from: day)) (\(dow)) 당직"
        return NavigationView {
            Form {
                Section {
                    TextField("교수 낮당직", text: $editProf)
                    TextField("전공의 밤당직", text: $editResident)
                    Toggle("휴일 (강조 표시)", isOn: $editHoliday)
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
                        vm.saveWardDuty(dutyDate: key, profDay: editProf.trimmingCharacters(in: .whitespaces),
                                        residentNight: editResident.trimmingCharacters(in: .whitespaces),
                                        isHoliday: editHoliday) { editDate = nil }
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
