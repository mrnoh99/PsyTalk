import SwiftUI

// 관리자 콘솔 (자리표시자) — Android AdminPlaceholderScreen 과 동일
struct AdminPlaceholderView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Text("‹").font(.system(size: 25)).foregroundColor(.white) }
                Text("관리자 콘솔").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Moim.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text("멤버 풀 · 방 관리 · 작성자 지정").font(.system(size: 16, weight: .bold))
                Text("HTML 프로토타입의 관리자 화면은 웹에서 구현되어 있습니다.\n앱에서는 Supabase 연동 후 단계적으로 추가할 예정입니다.")
                    .font(.system(size: 14)).foregroundColor(Moim.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            Spacer()
        }
        .background(Moim.paper.ignoresSafeArea())
    }
}
