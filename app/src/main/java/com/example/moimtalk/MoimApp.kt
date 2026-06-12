package com.example.moimtalk

import android.app.Application
import com.example.moimtalk.ui.MoimTheme

class MoimApp : Application() {
    override fun onCreate() {
        super.onCreate()
        MoimTheme.init(this)   // 화면 테마(다크/라이트) 저장값 로드
        Push.init(this)        // OneSignal 푸시 초기화 (APP_ID 비면 무시)
    }
}
