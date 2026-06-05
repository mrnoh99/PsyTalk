package com.example.moimtalk

import android.app.Application
import com.example.moimtalk.data.MoimRepository

// OneSignal 초기화용 Application (AndroidManifest 의 android:name 에 등록)
class MoimApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Push.configure(this)
        MoimRepository.currentUserId()?.let { Push.login(it) }
    }
}
