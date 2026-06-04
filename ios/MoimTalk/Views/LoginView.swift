import SwiftUI

struct LoginView: View {
    @ObservedObject var vm: MoimViewModel
    @State private var email = ""
    @State private var pw = ""

    var body: some View {
        VStack(alignment: .leading) {
            // 앱 내 로고 (Android 로그인 화면과 동일) — Assets 에 "aumc_psy_logo" 추가
            Image("aumc_psy_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            Spacer().frame(height: 20)
            Text("아주 정신").font(.system(size: 34, weight: .heavy)).foregroundColor(Moim.ink)
            Text("정신건강의학과").font(.system(size: 15)).foregroundColor(Moim.sub)
            Spacer().frame(height: 32)

            TextField("이메일", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)
            Spacer().frame(height: 12)
            SecureField("비밀번호", text: $pw)
                .textFieldStyle(.roundedBorder)

            if let err = vm.error {
                Spacer().frame(height: 10)
                Text(err).foregroundColor(Moim.admin).font(.system(size: 13))
            }

            Spacer().frame(height: 22)
            Button {
                vm.login(email: email.trimmingCharacters(in: .whitespaces), password: pw)
            } label: {
                Text(vm.loading ? "로그인 중..." : "로그인")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Moim.accent).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(vm.loading)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Moim.paper.ignoresSafeArea())
    }
}
