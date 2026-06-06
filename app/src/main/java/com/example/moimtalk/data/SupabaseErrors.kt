package com.example.moimtalk.data

internal fun isDuplicateKeyError(e: Exception): Boolean {
    val msg = listOfNotNull(e.message, e.cause?.message).joinToString(" ")
    return msg.contains("23505") || msg.contains("duplicate key", ignoreCase = true)
}

internal fun isJwtExpiredError(e: Exception): Boolean {
    val msg = listOfNotNull(e.message, e.cause?.message).joinToString(" ")
    return msg.contains("JWT expired", ignoreCase = true) ||
        msg.contains("Invalid JWT", ignoreCase = true) ||
        msg.contains("invalid claim", ignoreCase = true)
}

internal fun friendlySupabaseError(e: Exception, context: String): String {
    val msg = listOfNotNull(e.message, e.cause?.message)
        .joinToString(" | ")
        .ifBlank { e.toString() }

    return when {
        msg.contains("INTERNET permission", ignoreCase = true) ||
            msg.contains("missing INTERNET", ignoreCase = true) ||
            (msg.contains("Permission denied", ignoreCase = true) &&
                msg.contains("INTERNET", ignoreCase = true)) ->
            "$context 실패: 네트워크 연결을 확인하세요.\n" +
                "Wi‑Fi/데이터가 켜져 있는지 확인한 뒤 다시 시도하세요.\n" +
                "상세: $msg"

        msg.contains("42501") ||
            msg.contains("new row violates row-level security", ignoreCase = true) ||
            (msg.contains("permission denied", ignoreCase = true) &&
                msg.contains("table", ignoreCase = true)) ->
            if (context.contains("구성원")) {
                "$context 실패: 방 생성자 또는 관리자만 초대할 수 있습니다.\n" +
                    "Supabase SQL Editor에서 supabase/room_manage.sql 을 실행했는지 확인하세요.\n" +
                    "상세: $msg"
            } else {
                "$context 실패: DB 접근 권한이 없습니다.\n" +
                    "Supabase → SQL Editor에서 supabase/install.sql 을 실행하세요.\n" +
                    "(회원가입 문제는 fix_signup.sql 먼저)\n" +
                    "상세: $msg"
            }

        msg.contains("relation", ignoreCase = true) &&
            msg.contains("does not exist", ignoreCase = true) ->
            "$context 실패: 테이블이 없습니다. Supabase에 profiles, rooms, messages 테이블을 만드세요.\n" +
                "상세: $msg"

        msg.contains("42P17") ||
            msg.contains("infinite recursion", ignoreCase = true) ->
            "$context 실패: room_members 보안 정책 오류입니다.\n" +
                "Supabase SQL Editor에서 supabase/room_manage.sql 을 다시 실행하세요.\n" +
                "상세: $msg"

        msg.contains("23505") ||
            msg.contains("duplicate key", ignoreCase = true) ||
            msg.contains("rooms_custom_name_unique", ignoreCase = true) ->
            "$context 실패: 같은 이름의 모임방이 이미 있습니다. 다른 이름을 사용하세요."

        msg.contains("Invalid login", ignoreCase = true) ||
            msg.contains("Invalid credentials", ignoreCase = true) ||
            msg.contains("invalid_grant", ignoreCase = true) ->
            "$context 실패: 이메일 또는 비밀번호를 확인하세요."

        msg.contains("Email not confirmed", ignoreCase = true) ->
            "$context 실패: 아직 가입이 확인되지 않았습니다.\n" +
                "전체관리자의 가입 확인 후 로그인할 수 있습니다."

        msg.contains("JWT expired", ignoreCase = true) ||
            msg.contains("Invalid JWT", ignoreCase = true) ||
            msg.contains("invalid claim", ignoreCase = true) ->
            "$context 실패: 로그인이 만료되었습니다. 다시 로그인해 주세요."

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
