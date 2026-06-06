package com.example.moimtalk

import android.app.Application
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.ui.MoimTheme

// OneSignal 초기화용 Application (AndroidManifest 의 android:name 에 등록)
class MoimApp : Application() {
    override fun onCreate() {
        super.onCreate()
        MoimTheme.init(this)   // 화면 테마(다크/라이트) 저장값 로드
        Push.configure(this)
        MoimRepository.currentUserId()?.let { Push.login(it) }
    }
}
