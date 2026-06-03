import SwiftUI

// 병실 잔여 현황 데이터 (수동 갱신 — 추후 DB 연동 가능). Android 와 동일 내용.
private struct BedRow: Identifiable {
    let id = UUID()
    let type: String
    let seats: Int
    let note: String?
}
private struct BedSection: Identifiable {
    let id = UUID()
    let gender: String
    let emoji: String
    let rows: [BedRow]
}

private let wardSections: [BedSection] = [
    BedSection(gender: "남자", emoji: "👨", rows: [
        BedRow(type: "다인실", seats: 0, note: "1자리 EICU 전과예정"),
        BedRow(type: "3인실 (APICU)", seats: 0, note: nil)
    ]),
    BedSection(gender: "여자", emoji: "👩", rows: [
        BedRow(type: "다인실", seats: 0, note: "여자 1자리 퇴원예정"),
        BedRow(type: "3인실 (APICU)", seats: 1, note: nil),
        BedRow(type: "2인실 (APICU)", seats: 0, note: nil)
    ])
]

// 병실 잔여 현황 페이지 (Android WardStatusScreen 과 동일)
struct WardStatusView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("병실 잔여 현황").font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.paper)
            Divider().background(Moim.line)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text("🛏").font(.system(size: 22))
                        Text("병실 잔여 현황").font(.system(size: 18, weight: .heavy)).foregroundColor(Moim.ink)
                    }
                    Text("잔여 병상 현황 (수동 갱신)").font(.system(size: 12)).foregroundColor(Moim.sub)
                        .padding(.top, 4).padding(.bottom, 14)

                    ForEach(wardSections) { sectionCard($0) }
                }
                .padding(16)
            }
        }
        .background(Moim.paper.ignoresSafeArea())
    }

    private func sectionCard(_ sec: BedSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(sec.emoji) \(sec.gender)").font(.system(size: 15, weight: .heavy)).foregroundColor(Moim.ink)
            ForEach(Array(sec.rows.enumerated()), id: \.offset) { idx, r in
                if idx > 0 { Divider().background(Moim.line.opacity(0.5)) }
                bedRow(r)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Moim.white).clipShape(RoundedRectangle(cornerRadius: 15))
        .padding(.bottom, 13)
    }

    private func bedRow(_ r: BedRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.type).font(.system(size: 14, weight: .semibold)).foregroundColor(Moim.ink)
                if let note = r.note { Text(note).font(.system(size: 11.5)).foregroundColor(Moim.sub) }
            }
            Spacer()
            Text("\(r.seats)자리")
                .font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(r.seats > 0 ? catColor("work") : Moim.admin)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
