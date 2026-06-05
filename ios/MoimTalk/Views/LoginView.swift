import SwiftUI

struct LoginView: View {
    @ObservedObject var vm: MoimViewModel
    @State private var email = ""
    @State private var pw = ""
    @State private var signup = false
    @State private var name = ""
    @State private var memberType = "의국"
    private let memberTypes = ["교실", "의국", "심리실", "연구실", "PA", "간호사", "SW", "보조원", "비서", "의국동문", "심리실 동문", "기타"]

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

            if signup {
                Spacer().frame(height: 12)
                TextField("이름", text: $name).textFieldStyle(.roundedBorder)
                Spacer().frame(height: 12)
                Text("직군").font(.system(size: 12, weight: .bold)).foregroundColor(Moim.sub)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(memberTypes, id: \.self) { t in
                            let on = memberType == t
                            Text(t).font(.system(size: 12, weight: .bold))
                                .foregroundColor(on ? .white : Moim.ink)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(on ? typeColor(t) : Moim.white)
                                .clipShape(Capsule())
                                .onTapGesture { memberType = t }
                        }
                    }
                }
            }

            if let err = vm.error {
                Spacer().frame(height: 10)
                Text(err).foregroundColor(Moim.admin).font(.system(size: 13))
            }
            if let n = vm.notice {
                Spacer().frame(height: 10)
                Text(n).foregroundColor(catColor("work")).font(.system(size: 13))
            }

            Spacer().frame(height: 22)
            Button {
                if signup {
                    vm.signUp(email: email.trimmingCharacters(in: .whitespaces), password: pw,
                              name: name.trimmingCharacters(in: .whitespaces), memberType: memberType)
                } else {
                    vm.login(email: email.trimmingCharacters(in: .whitespaces), password: pw)
                }
            } label: {
                Text(vm.loading ? "처리 중..." : (signup ? "회원가입" : "로그인"))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Moim.accent).foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(vm.loading)

            Spacer().frame(height: 14)
            Button {
                signup.toggle(); vm.error = nil; vm.notice = nil
            } label: {
                Text(signup ? "이미 계정이 있나요?  로그인" : "계정이 없나요?  회원가입")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Moim.accent)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Moim.paper.ignoresSafeArea())
    }
}
