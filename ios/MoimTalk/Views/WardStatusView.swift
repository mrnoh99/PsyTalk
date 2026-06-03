import SwiftUI

// 현재 병실현황 페이지 (Android WardStatusScreen 과 동일)
struct WardStatusView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)) }
                Text("현재 병실현황").font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.paper)
            Divider().background(Moim.line)

            VStack {
                Text("🛏").font(.system(size: 44))
                Spacer().frame(height: 14)
                Text("현재 병실현황").font(.system(size: 18, weight: .heavy)).foregroundColor(Moim.ink)
                Spacer().frame(height: 8)
                Text("병동 입원·병상 현황을 여기에 표시합니다.\n표시할 항목(병상/환자 목록·담당의 등)을 정해 주시면 채워 넣겠습니다.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13.5)).foregroundColor(Moim.sub)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .background(Moim.paper.ignoresSafeArea())
    }
}
