import SwiftUI

struct CalendarView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let canPost: Bool

    @State private var mode: String
    @State private var monthAnchor: Date = CalDate.today()
    // 선택한 날짜 — 기본은 오늘. 날짜를 누르면 그날로 포커스가 옮겨가고 일정 추가·아래 목록이 이 날짜를 따른다.
    @State private var selected: Date = CalDate.today()
    @State private var editing: CalendarEvent?
    @State private var showEventDetail = false
    @State private var overlayEvent: CalendarEvent?
    @State private var creating = false

    private func openEventDetail(_ event: CalendarEvent) {
        overlayEvent = event
        withAnimation(MoimOverlayAnim.anim) { showEventDetail = true }
    }

    private func closeEventDetail() {
        withAnimation(MoimOverlayAnim.anim) { showEventDetail = false }
    }

    private var compactEvents: Bool { opensWeekCalendar(room) }

    init(vm: MoimViewModel, room: Room, canPost: Bool) {
        self.vm = vm; self.room = room; self.canPost = canPost
        _mode = State(initialValue: opensWeekCalendar(room) ? "week" : "month")
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 7) {
                        modeButton("금일", "day"); modeButton("주간", "week"); modeButton("월간", "month")
                    }
                    .padding(.bottom, 13)

                    if canPost {
                        Button { creating = true } label: {
                            Text("＋ 일정 추가").font(.system(size: 14, weight: .bold))
                                .foregroundColor(theme.dark ? Moim.ink : .white)
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(theme.dark ? Moim.white : Moim.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.dark ? Moim.line : Color.clear, lineWidth: 1))
                        }
                        .padding(.bottom, 14)
                    }

                    switch mode {
                    case "month": monthView
                    case "week": weekView
                    default: dayView
                    }
                }
                .padding(13)
            }
            .background(Moim.paper)

            if showEventDetail, let ev = overlayEvent {
                EventDetailView(event: ev, vm: vm,
                                onBack: { closeEventDetail() },
                                onEdit: { closeEventDetail(); editing = $0 })
                    .transition(MoimOverlayAnim.transition)
                    .zIndex(1)
                    .onDisappear {
                        if !showEventDetail { overlayEvent = nil }
                    }
            }
        }
        .sheet(isPresented: $creating) {
            EventEditView(title: "일정 추가", initial: nil, allowAttachment: true, allowRepeat: opensWeekCalendar(room), defaultDate: selected) { form in
                vm.createEvent(title: form.title, startAt: form.startAt, place: form.place, link: form.link,
                               scope: form.scope, description: form.description, presenter: form.presenter, keywords: form.keywords,
                               attachments: form.newAttachments, repeatRule: form.repeatRule, repeatCount: form.repeatCount) { creating = false }
            }
        }
        .sheet(item: $editing) { ev in
            EventEditView(title: "일정 수정", initial: ev, allowAttachment: true,
                          onDelete: canDeleteEvent(vm.myProfile, ev) ? { vm.deleteEvent(ev.id) } : nil) { form in
                vm.updateEvent(eventId: ev.id, title: form.title, startAt: form.startAt, place: form.place,
                               link: form.link, scope: form.scope, description: form.description,
                               presenter: form.presenter, keywords: form.keywords,
                               keptUrls: form.keptUrls, keptNames: form.keptNames, newAttachments: form.newAttachments) { editing = nil }
            }
        }
    }

    private func modeButton(_ label: String, _ value: String) -> some View {
        let on = mode == value
        return Text(label).font(.system(size: 12.5, weight: .bold))
            .foregroundColor(moimToggleText(selected: on, lightOn: Moim.ink))
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(moimToggleBg(selected: on, lightOn: Moim.yellow))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.dark ? moimToggleBorder(selected: on) : Color.clear, lineWidth: 1))
            .onTapGesture { mode = value }
    }

    // ── 월간 ──
    private var monthView: some View {
        let comps = CalDate.cal.dateComponents([.year, .month], from: monthAnchor)
        let monthEvents = vm.events.filter {
            guard let d = CalDate.eventDay($0.startAt) else { return false }
            let c = CalDate.cal.dateComponents([.year, .month], from: d)
            return c.year == comps.year && c.month == comps.month
        }.sorted { $0.startAt < $1.startAt }
        let eventDays = Set(monthEvents.compactMap { CalDate.eventDay($0.startAt).map { CalDate.cal.component(.day, from: $0) } })

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("‹").font(.system(size: 20)).foregroundColor(Moim.sub).padding(.horizontal, 8)
                    .onTapGesture { monthAnchor = CalDate.cal.date(byAdding: .month, value: -1, to: monthAnchor)! }
                Spacer()
                Text("\(comps.year ?? 0)년 \(comps.month ?? 0)월").font(.system(size: 16, weight: .heavy))
                Spacer()
                Text("›").font(.system(size: 20)).foregroundColor(Moim.sub).padding(.horizontal, 8)
                    .onTapGesture { monthAnchor = CalDate.cal.date(byAdding: .month, value: 1, to: monthAnchor)! }
            }
            .padding(.bottom, 12)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: cols, spacing: 2) {
                ForEach(["일","월","화","수","목","금","토"], id: \.self) { d in
                    Text(d).font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                }
                ForEach(Array(monthCells(comps).enumerated()), id: \.offset) { _, day in
                    monthCell(day: day, isEvent: day > 0 && eventDays.contains(day), comps: comps)
                }
            }
            .padding(.bottom, 16)

            let dayEvents = vm.events.filter { CalDate.eventDay($0.startAt).map { CalDate.sameDay($0, selected) } == true }
                .sorted { $0.startAt < $1.startAt }
            Text(CalDate.sameDay(selected, CalDate.today()) ? "오늘 · \(CalDate.dayLabel(selected))" : "\(CalDate.dayLabel(selected)) 일정")
                .font(.system(size: 11, weight: .heavy)).foregroundColor(Moim.sub).padding(.bottom, 10)
            if dayEvents.isEmpty { noEvents } else {
                ForEach(dayEvents) { EventCard(event: $0, vm: vm, compact: compactEvents, onView: { openEventDetail($0) }, onEdit: { editing = $0 }) }
            }
        }
    }

    private func monthCells(_ comps: DateComponents) -> [Int] {
        var c = comps; c.day = 1
        let first = CalDate.cal.date(from: c)!
        let weekday = CalDate.cal.component(.weekday, from: first) // 일=1
        let lead = weekday - 1
        let len = CalDate.cal.range(of: .day, in: .month, for: first)!.count
        var cells = Array(repeating: 0, count: lead)
        cells.append(contentsOf: Array(1...len))
        while cells.count % 7 != 0 { cells.append(0) }
        return cells
    }

    private func monthCell(day: Int, isEvent: Bool, comps: DateComponents) -> some View {
        var cellDate: Date?
        if day > 0 {
            var c = comps; c.day = day
            cellDate = CalDate.cal.date(from: c)
        }
        let isToday = cellDate.map { CalDate.sameDay($0, CalDate.today()) } ?? false
        let isSelected = cellDate.map { CalDate.sameDay($0, selected) } ?? false
        return VStack(spacing: 2) {
            if day > 0 {
                Text("\(day)").font(.system(size: 13, weight: (isToday || isSelected) ? .heavy : .regular)).foregroundColor(Moim.ink)
                if isEvent { Circle().fill(Moim.admin).frame(width: 5, height: 5) }
            }
        }
        .frame(maxWidth: .infinity).frame(height: 38)
        .background(theme.dark ? (isSelected ? Moim.white : Color.clear) : (isToday ? Moim.yellow : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(theme.dark ? moimToggleBorder(selected: isSelected) : Moim.accent, lineWidth: isSelected ? (theme.dark ? 1 : 2) : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture { if let d = cellDate { selected = CalDate.startOfDay(d) } }
    }

    // ── 주간 (list) ──
    private var weekView: some View {
        // 선택한 날짜가 속한 주를 보여준다 (월~일)
        let monday = CalDate.mondayOf(selected)
        let sunday = CalDate.cal.date(byAdding: .day, value: 6, to: monday)!
        let dow = ["월","화","수","목","금","토","일"]
        return VStack(alignment: .leading, spacing: 0) {
            calNavBar(
                center: "\(CalDate.dayLabel(monday)) ~ \(CalDate.dayLabel(sunday))",
                isCurrent: CalDate.sameDay(monday, CalDate.mondayOf(CalDate.today())),
                returnLabel: "이번주로",
                onPrev: { selected = CalDate.cal.date(byAdding: .day, value: -7, to: selected)! },
                onNext: { selected = CalDate.cal.date(byAdding: .day, value: 7, to: selected)! }
            )
            ForEach(0..<7, id: \.self) { offset in
                let date = CalDate.cal.date(byAdding: .day, value: offset, to: monday)!
                let isToday = CalDate.sameDay(date, CalDate.today())
                let isSelected = CalDate.sameDay(date, selected)
                let dayEvents = vm.events.filter { CalDate.eventDay($0.startAt).map { CalDate.sameDay($0, date) } == true }
                    .sorted { $0.startAt < $1.startAt }
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Text(dow[offset]).font(.system(size: 15, weight: .heavy)).foregroundColor(isToday ? Moim.admin : Moim.ink)
                        Text(CalDate.dayLabel(date)).font(.system(size: 10.5)).foregroundColor(Moim.sub)
                    }
                    .frame(width: 40)
                    VStack(alignment: .leading, spacing: 0) {
                        if dayEvents.isEmpty {
                            Text("— 일정 없음").font(.system(size: 12)).foregroundColor(Color(hex: 0xC4BCB2)).padding(.vertical, 7)
                        } else {
                            ForEach(dayEvents) { EventCard(event: $0, vm: vm, compact: compactEvents, onView: { openEventDetail($0) }, onEdit: { editing = $0 }) }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 9).padding(.horizontal, 6)
                .background(theme.dark ? (isSelected ? Moim.white : Color.clear) : (isToday ? Moim.hl : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(theme.dark ? moimToggleBorder(selected: isSelected) : Moim.accent, lineWidth: isSelected ? (theme.dark ? 1 : 2) : 0)
                )
                .contentShape(Rectangle())
                .onTapGesture { selected = CalDate.startOfDay(date) }
                Divider().background(Moim.line.opacity(0.5))
            }
        }
    }

    // ── 금일 ──
    private var dayView: some View {
        let dayEvents = vm.events.filter { CalDate.eventDay($0.startAt).map { CalDate.sameDay($0, selected) } == true }
            .sorted { $0.startAt < $1.startAt }
        return VStack(alignment: .leading, spacing: 0) {
            calNavBar(
                center: CalDate.dayLabel(selected),
                isCurrent: CalDate.sameDay(selected, CalDate.today()),
                returnLabel: "오늘로",
                onPrev: { selected = CalDate.cal.date(byAdding: .day, value: -1, to: selected)! },
                onNext: { selected = CalDate.cal.date(byAdding: .day, value: 1, to: selected)! }
            )
            if dayEvents.isEmpty { noEvents } else {
                ForEach(dayEvents) { EventCard(event: $0, vm: vm, compact: compactEvents, onView: { openEventDetail($0) }, onEdit: { editing = $0 }) }
            }
        }
    }

    private var noEvents: some View {
        Text("등록된 일정이 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub).padding(.vertical, 4)
    }

    // 금일/주간 < 가운데 > 이동 + (오늘/이번주가 아니면) 복귀 버튼
    private func calNavBar(center: String, isCurrent: Bool, returnLabel: String,
                           onPrev: @escaping () -> Void, onNext: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onPrev) { Text("‹").font(.system(size: 22)).foregroundColor(Moim.sub) }
                Spacer()
                Text(center).font(.system(size: 14, weight: .bold)).foregroundColor(Moim.ink)
                Spacer()
                Button(action: onNext) { Text("›").font(.system(size: 22)).foregroundColor(Moim.sub) }
            }
            if !isCurrent {
                Button { selected = CalDate.startOfDay(CalDate.today()) } label: {
                    Text(returnLabel).font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.dark ? Moim.ink : .white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(theme.dark ? Moim.white : Moim.accent)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme.dark ? Moim.line : Color.clear, lineWidth: 1))
                }
                .padding(.top, 6)
            }
        }
        .padding(.bottom, 10)
    }
}

struct EventCard: View {
    let event: CalendarEvent
    @ObservedObject var vm: MoimViewModel
    var compact: Bool = false
    let onView: (CalendarEvent) -> Void
    let onEdit: (CalendarEvent) -> Void

    var body: some View {
        if compact {
            HStack(alignment: .top, spacing: 11) {
                RoundedRectangle(cornerRadius: 4).fill(catColor("notice")).frame(width: 4, height: 56)
                Text(eventPreviewText(event, ownerName: vm.name(of: event.ownerId)))
                    .font(.system(size: 12.5))
                    .foregroundColor(Moim.ink)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12).background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 9)
            .contentShape(Rectangle())
            .onTapGesture { onView(event) }
        } else {
            EventCardBody(event: event, vm: vm, showEdit: true, onEdit: onEdit)
        }
    }
}

private func eventPreviewText(_ event: CalendarEvent, ownerName: String) -> String {
    var lines: [String] = [event.title, "📅 \(CalDate.timeLabel(event.startAt))"]
    if let p = event.place, !p.isEmpty { lines[1] += " · 📍 \(p)" }
    lines.append("👤 발표자 \((event.presenter?.isEmpty == false) ? event.presenter! : ownerName)")
    if let s = event.scope, !s.isEmpty { lines.append("참석 \(s)") }
    if let d = event.description, !d.isEmpty { lines.append(d) }
    let atts = event.attachmentList
    if !atts.isEmpty {
        let extra = atts.count > 1 ? " 외 \(atts.count - 1)건" : ""
        lines.append("📎 \(atts[0].name)\(extra)")
    }
    return lines.joined(separator: "\n")
}

struct EventCardBody: View {
    let event: CalendarEvent
    @ObservedObject var vm: MoimViewModel
    var showEdit: Bool
    let onEdit: (CalendarEvent) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 4).fill(catColor("notice")).frame(width: 4, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
                Text("📅 \(CalDate.timeLabel(event.startAt))").font(.system(size: 12.5)).foregroundColor(Moim.ink).padding(.top, 2)
                if let p = event.place, !p.isEmpty { Text("📍 \(p)").font(.system(size: 12.5)).foregroundColor(Moim.sub) }
                Text("👤 발표자 \((event.presenter?.isEmpty == false) ? event.presenter! : vm.name(of: event.ownerId))")
                    .font(.system(size: 12.5)).foregroundColor(Moim.sub)
                if let s = event.scope, !s.isEmpty { Text("참석 \(s)").font(.system(size: 11.5)).foregroundColor(Moim.sub) }
                if let d = event.description, !d.isEmpty { Text(d).font(.system(size: 11.5)).foregroundColor(Moim.sub) }
                ForEach(Array(event.attachmentList.enumerated()), id: \.offset) { _, att in
                    if let u = URL(string: att.url) {
                        Link(destination: u) {
                            Text("📎 \(att.name)").font(.system(size: 11.5, weight: .bold)).foregroundColor(catColor("work"))
                                .lineLimit(1)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(hex: 0xE7F0EB)).clipShape(Capsule())
                        }
                        .padding(.top, 6)
                    }
                }
                HStack(spacing: 8) {
                    if let l = event.link, !l.isEmpty, let u = URL(string: l) {
                        Link(destination: u) {
                            Text("🔗 링크").font(.system(size: 11.5, weight: .bold)).foregroundColor(catColor("group"))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(hex: 0xEEF2F8)).clipShape(Capsule())
                        }
                    }
                    if showEdit && vm.canEditEvent(event) {
                        Text("✏️ 수정").font(.system(size: 11.5, weight: .bold)).foregroundColor(Moim.sub)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Moim.bg).clipShape(Capsule())
                            .onTapGesture { onEdit(event) }
                    }
                }
                .padding(.top, 6)
            }
            Spacer()
        }
        .padding(12).background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 9)
    }
}

struct EventDetailDocument: View {
    let event: CalendarEvent
    @ObservedObject var vm: MoimViewModel

    var body: some View {
        let atts = event.attachmentList
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(catColor("notice")).frame(height: 3)
            Text(event.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Moim.ink)
                .lineSpacing(4)
                .padding(.top, 16)
            Divider().background(Moim.line).padding(.vertical, 14)
            EventDocRow(label: "일시", value: CalDate.detailTimeLabel(event.startAt))
            if let p = event.place, !p.isEmpty { EventDocRow(label: "장소", value: p) }
            EventDocRow(label: "발표자", value: (event.presenter?.isEmpty == false) ? event.presenter! : vm.name(of: event.ownerId))
            if let s = event.scope, !s.isEmpty { EventDocRow(label: "참석", value: s) }
            if let d = event.description, !d.isEmpty {
                Divider().background(Moim.line).padding(.vertical, 14)
                Text("설명").font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                Text(d).font(.system(size: 14)).foregroundColor(Moim.ink).lineSpacing(6).padding(.top, 8)
            }
            if !atts.isEmpty || (event.link?.isEmpty == false) {
                Divider().background(Moim.line).padding(.vertical, 14)
            }
            if !atts.isEmpty {
                Text("첨부").font(.system(size: 11, weight: .bold)).foregroundColor(Moim.sub)
                ForEach(Array(atts.enumerated()), id: \.offset) { _, att in
                    if let u = URL(string: att.url) {
                        Link(destination: u) {
                            HStack(spacing: 8) {
                                Text("📎").font(.system(size: 16))
                                Text(att.name).font(.system(size: 13, weight: .semibold)).foregroundColor(Moim.ink).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Moim.paper)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Moim.line, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.top, 8)
                    }
                }
            }
            if let l = event.link, !l.isEmpty, let u = URL(string: l) {
                Link(destination: u) {
                    Text("🔗 링크 열기").font(.system(size: 13, weight: .bold)).foregroundColor(catColor("group"))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(hex: 0xEEF2F8)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.top, atts.isEmpty ? 0 : 4)
            }
        }
        .padding(20)
        .background(Moim.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Moim.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .padding(.bottom, 16)
    }
}

private struct EventDocRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub).frame(width: 52, alignment: .leading)
            Text(value).font(.system(size: 13.5)).foregroundColor(Moim.ink).lineSpacing(3).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
    }
}

struct EventDetailView: View {
    let event: CalendarEvent
    @ObservedObject var vm: MoimViewModel
    let onBack: () -> Void
    let onEdit: (CalendarEvent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("일정 상세").font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Moim.paper)
            Divider().background(Moim.line)

            ScrollView {
                EventDetailDocument(event: event, vm: vm)
                    .padding(.horizontal, 16).padding(.top, 12)
            }
            .background(Moim.bg)

            if vm.canEditEvent(event) {
                Divider().background(Moim.line)
                Button { onEdit(event) } label: {
                    Text("✏️ 수정").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Moim.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
    }
}
