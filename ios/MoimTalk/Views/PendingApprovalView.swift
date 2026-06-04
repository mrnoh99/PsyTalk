import SwiftUI

// 관리자 가입 승인 대기 화면
struct PendingApprovalView: View {
    @ObservedObject var vm: MoimViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("⏳").font(.system(size: 46))
            Spacer().frame(height: 16)
            Text("관리자 승인 대기 중").font(.system(size: 19, weight: .heavy)).foregroundColor(Moim.ink)
            Spacer().frame(height: 10)
            Text("가입이 접수되었습니다.\n관리자가 승인하면 이용할 수 있습니다.")
                .multilineTextAlignment(.center).font(.system(size: 14)).foregroundColor(Moim.sub)
            if let p = vm.myProfile {
                Spacer().frame(height: 8)
                Text("\(p.name) · \(p.memberType)").font(.system(size: 12)).foregroundColor(Moim.sub)
            }
            Spacer().frame(height: 24)
            Button { vm.loadRooms() } label: {
                Text("다시 확인").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 24).frame(height: 48)
                    .background(Moim.accent).clipShape(RoundedRectangle(cornerRadius: 13))
            }
            Spacer().frame(height: 6)
            Button("로그아웃") { vm.logout() }.font(.system(size: 13)).foregroundColor(Moim.sub)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
        .background(Moim.paper.ignoresSafeArea())
    }
}
