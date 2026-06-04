import SwiftUI

struct CalendarView: View {
    @ObservedObject var vm: MoimViewModel
    let room: Room
    let canPost: Bool

    @State private var mode: String
    @State private var monthAnchor: Date = CalDate.today()
    @State private var editing: CalendarEvent?
    @State private var creating = false

    init(vm: MoimViewModel, room: Room, canPost: Bool) {
        self.vm = vm; self.room = room; self.canPost = canPost
        _mode = State(initialValue: room.defaultView == "week" ? "week" : "month")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    modeButton("금일", "day"); modeButton("주간", "week"); modeButton("월간", "month")
                }
                .padding(.bottom, 13)

                if canPost {
                    Button { creating = true } label: {
                        Text("＋ 일정 추가").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(Moim.accent).clipShape(RoundedRectangle(cornerRadius: 12))
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
        .sheet(isPresented: $creating) {
            EventEditView(title: "일정 추가", initial: nil, allowAttachment: true) { form in
                vm.createEvent(title: form.title, startAt: form.startAt, place: form.place, link: form.link,
                               scope: form.scope, description: form.description, keywords: form.keywords,
                               attachmentName: form.attachmentName, attachmentData: form.attachmentData,
                               attachmentDesc: form.attachmentDesc) { creating = false }
            }
        }
        .sheet(item: $editing) { ev in
            EventEditView(title: "일정 수정", initial: ev, allowAttachment: true) { form in
                vm.updateEvent(eventId: ev.id, title: form.title, startAt: form.startAt, place: form.place,
                               link: form.link, scope: form.scope, description: form.description,
                               keywords: form.keywords,
                               attachmentName: form.attachmentName, attachmentData: form.attachmentData,
                               attachmentDesc: form.attachmentDesc) { editing = nil }
            }
        }
    }

    private func modeButton(_ label: String, _ value: String) -> some View {
        let on = mode == value
        return Text(label).font(.system(size: 12.5, weight: .bold))
            .foregroundColor(on ? Moim.ink : Moim.sub)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(on ? Moim.yellow : Moim.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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

            Text("이번 달 일정").font(.system(size: 11, weight: .heavy)).foregroundColor(Moim.sub).padding(.bottom, 10)
            if monthEvents.isEmpty { noEvents } else {
                ForEach(monthEvents) { EventCard(event: $0, vm: vm, onEdit: { editing = $0 }) }
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
        var isToday = false
        if day > 0 {
            var c = comps; c.day = day
            if let d = CalDate.cal.date(from: c) { isToday = CalDate.sameDay(d, CalDate.today()) }
        }
        return VStack(spacing: 2) {
            if day > 0 {
                Text("\(day)").font(.system(size: 13, weight: isToday ? .heavy : .regular)).foregroundColor(Moim.ink)
                if isEvent { Circle().fill(Moim.admin).frame(width: 5, height: 5) }
            }
        }
        .frame(maxWidth: .infinity).frame(height: 38)
        .background(isToday ? Moim.yellow : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // ── 주간 (list) ──
    private var weekView: some View {
        let monday = CalDate.mondayOf(CalDate.today())
        let dow = ["월","화","수","목","금","토","일"]
        return VStack(alignment: .leading, spacing: 0) {
            Text("이번 주 · \(CalDate.dayLabel(monday))(월) ~ \(CalDate.dayLabel(CalDate.cal.date(byAdding: .day, value: 6, to: monday)!))(일)")
                .font(.system(size: 11, weight: .heavy)).foregroundColor(Moim.sub).padding(.bottom, 10)
            ForEach(0..<7, id: \.self) { offset in
                let date = CalDate.cal.date(byAdding: .day, value: offset, to: monday)!
                let isToday = CalDate.sameDay(date, CalDate.today())
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
                            ForEach(dayEvents) { EventCard(event: $0, vm: vm, onEdit: { editing = $0 }) }
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 9).padding(.horizontal, 6)
                .background(isToday ? Color(hex: 0xFFF8E0) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                Divider().background(Moim.line.opacity(0.5))
            }
        }
    }

    // ── 금일 ──
    private var dayView: some View {
        let dayEvents = vm.events.filter { CalDate.eventDay($0.startAt).map { CalDate.sameDay($0, CalDate.today()) } == true }
            .sorted { $0.startAt < $1.startAt }
        return VStack(alignment: .leading, spacing: 0) {
            Text("금일 · \(CalDate.dayLabel(CalDate.today()))").font(.system(size: 11, weight: .heavy)).foregroundColor(Moim.sub).padding(.bottom, 10)
            if dayEvents.isEmpty { noEvents } else {
                ForEach(dayEvents) { EventCard(event: $0, vm: vm, onEdit: { editing = $0 }) }
            }
        }
    }

    private var noEvents: some View {
        Text("등록된 일정이 없습니다.").font(.system(size: 13)).foregroundColor(Moim.sub).padding(.vertical, 4)
    }
}

struct EventCard: View {
    let event: CalendarEvent
    @ObservedObject var vm: MoimViewModel
    let onEdit: (CalendarEvent) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 4).fill(catColor("notice")).frame(width: 4, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 15, weight: .bold)).foregroundColor(Moim.ink)
                Text("📅 \(CalDate.timeLabel(event.startAt))").font(.system(size: 12.5)).foregroundColor(Moim.ink).padding(.top, 2)
                if let p = event.place, !p.isEmpty { Text("📍 \(p)").font(.system(size: 12.5)).foregroundColor(Moim.sub) }
                Text("👤 발표자 \(vm.name(of: event.ownerId))").font(.system(size: 12.5)).foregroundColor(Moim.sub)
                if let s = event.scope, !s.isEmpty { Text("참석 \(s)").font(.system(size: 11.5)).foregroundColor(Moim.sub) }
                if let d = event.description, !d.isEmpty { Text(d).font(.system(size: 11.5)).foregroundColor(Moim.sub) }
                if !event.kw.isEmpty {
                    Text(event.kw.map { "#\($0)" }.joined(separator: " "))
                        .font(.system(size: 11.5, weight: .semibold)).foregroundColor(catColor("research")).padding(.top, 2)
                }
                HStack(spacing: 8) {
                    if let l = event.link, !l.isEmpty, let u = URL(string: l) {
                        Link(destination: u) {
                            Text("🔗 링크").font(.system(size: 11.5, weight: .bold)).foregroundColor(catColor("group"))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(hex: 0xEEF2F8)).clipShape(Capsule())
                        }
                    }
                    if let url = event.attachmentUrl, !url.isEmpty, let u = URL(string: url) {
                        Link(destination: u) {
                            Text("📎 첨부파일").font(.system(size: 11.5, weight: .bold)).foregroundColor(catColor("work"))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color(hex: 0xE7F0EB)).clipShape(Capsule())
                        }
                    }
                    if vm.canEditEvent(event) {
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
