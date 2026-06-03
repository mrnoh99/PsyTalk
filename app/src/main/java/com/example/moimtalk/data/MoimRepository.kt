package com.example.moimtalk.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order

object MoimRepository {

    fun currentUserId(): String? =
        supabase.auth.currentSessionOrNull()?.user?.id

    suspend fun signIn(email: String, password: String) {
        supabase.auth.signInWith(Email) {
            this.email = email
            this.password = password
        }
    }

    suspend fun signOut() {
        supabase.auth.signOut()
    }

    suspend fun myProfile(): Profile {
        val uid = currentUserId() ?: error("Not logged in")
        return supabase.from("profiles").select {
            filter { eq("id", uid) }
        }.decodeList<Profile>()
            .firstOrNull()
            ?: error("프로필이 없습니다")
    }

    suspend fun rooms(): List<Room> =
        supabase.from("rooms").select {
            order("sort_order", Order.ASCENDING)
        }.decodeList()

    suspend fun messages(roomId: String): List<Message> =
        supabase.from("messages").select {
            filter { eq("room_id", roomId) }
            order("created_at", Order.ASCENDING)
        }.decodeList()

    suspend fun sendMessage(roomId: String, text: String) {
        val uid = currentUserId() ?: error("Not logged in")
        supabase.from("messages").insert(
            MessageInsert(roomId = roomId, senderId = uid, content = text)
        )
    }
}
