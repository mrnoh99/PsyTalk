package com.example.moimtalk.data

internal fun friendlySupabaseError(e: Exception, context: String): String {
    val msg = listOfNotNull(e.message, e.cause?.message)
        .joinToString(" | ")
        .ifBlank { e.toString() }

    return when {
        msg.contains("INTERNET permission", ignoreCase = true) ||
            msg.contains("missing INTERNET", ignoreCase = true) ->
            "$context 실패: 앱에 인터넷 권한이 없습니다.\n" +
                "AndroidManifest.xml 에 INTERNET 권한을 추가한 뒤 앱을 다시 설치하세요."

        msg.contains("42501") ||
            (msg.contains("permission denied", ignoreCase = true) &&
                msg.contains("table", ignoreCase = true)) ->
            "$context 실패: DB 접근 권한이 없습니다.\n" +
                "Supabase → SQL Editor에서 supabase/install.sql 을 실행하세요.\n" +
                "(회원가입 문제는 fix_signup.sql 먼저)\n" +
                "상세: $msg"

        msg.contains("relation", ignoreCase = true) &&
            msg.contains("does not exist", ignoreCase = true) ->
            "$context 실패: 테이블이 없습니다. Supabase에 profiles, rooms, messages 테이블을 만드세요.\n" +
                "상세: $msg"

        msg.contains("Invalid login", ignoreCase = true) ||
            msg.contains("Invalid credentials", ignoreCase = true) ||
            msg.contains("invalid_grant", ignoreCase = true) ->
            "$context 실패: 이메일 또는 비밀번호를 확인하세요."

        msg.contains("Email not confirmed", ignoreCase = true) ->
            "$context 실패: 이메일 인증이 필요합니다.\n" +
                "Supabase → Authentication → Users 에서 Confirm 하세요."

        msg.contains("PGRST116", ignoreCase = true) ||
            msg.contains("0 rows", ignoreCase = true) ||
            msg.contains("Cannot coerce", ignoreCase = true) ->
            "$context 실패: profiles 에 사용자 정보가 없습니다.\n" +
                "Supabase SQL Editor에서 supabase/fix_signup.sql 을 실행하세요."

        msg.contains("Database error creating new user", ignoreCase = true) ->
            "사용자 생성 실패: profiles 트리거/테이블 오류입니다.\n" +
                "Supabase SQL Editor에서 supabase/fix_signup.sql 을 실행한 뒤 다시 시도하세요."

        else -> "$context 실패: $msg"
    }
}
