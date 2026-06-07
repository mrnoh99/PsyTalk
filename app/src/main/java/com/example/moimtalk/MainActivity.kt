package com.example.moimtalk

import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.material3.AlertDialog
import com.example.moimtalk.ui.MoimTheme
import com.example.moimtalk.ui.theme.PsyTalkTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.example.moimtalk.data.CalendarEvent
import com.example.moimtalk.data.LastMsg
import com.example.moimtalk.data.Message
import com.example.moimtalk.data.MoimRealtimeSync
import com.example.moimtalk.data.MoimRepository
import com.example.moimtalk.data.Profile
import com.example.moimtalk.data.Reaction
import com.example.moimtalk.data.Room
import com.example.moimtalk.data.RoomFile
import com.example.moimtalk.data.friendlySupabaseError
import com.example.moimtalk.ui.CreateRoomScreen
import com.example.moimtalk.ui.LoginScreen
import com.example.moimtalk.ui.RoomListScreen
import com.example.moimtalk.ui.RoomScreen
import com.example.moimtalk.ui.SettingsScreen
import com.example.moimtalk.ui.AdminConsoleScreen
import com.example.moimtalk.ui.isAdminRole
import com.example.moimtalk.ui.PendingApprovalScreen
import com.example.moimtalk.ui.WardStatusScreen
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

// =====================================================================
//  ViewModel
// =====================================================================
class MoimViewModel : ViewModel() {

    var loggedIn by mutableStateOf(MoimRepository.currentUserId() != null)
    var myProfile by mutableStateOf<Profile?>(null)
    var rooms by mutableStateOf<List<Room>>(emptyList())
    var messages by mutableStateOf<List<Message>>(emptyList())
    var reactions by mutableStateOf<List<Reaction>>(emptyList())   // 활성 방 이모지 리액션
    var replyTarget by mutableStateOf<Message?>(null)              // 답장 대상(작성 중)
    var events by mutableStateOf<List<CalendarEvent>>(emptyList())
    var files by mutableStateOf<List<RoomFile>>(emptyList())
    var profilesById by mutableStateOf<Map<String, Profile>>(emptyMap())
    // 채팅 첨부 path → 서명 URL 캐시 (방 구성원만 발급됨)
    var attachmentUrls by mutableStateOf<Map<String, String>>(emptyMap())
    // 읽음 표시: #1 방별 안읽은 수, #2 메시지별 안읽은 사람 수
    var unreadByRoom by mutableStateOf<Map<String, Int>>(emptyMap())
    var unreadByMsg by mutableStateOf<Map<String, Int>>(emptyMap())
    // 방별 마지막 메시지 (방 목록 미리보기)
    var lastMsgByRoom by mutableStateOf<Map<String, LastMsg>>(emptyMap())
    // 내가 가입한 방 id (홈 목록에서 superadmin/admin 도 가입 방만 표시; 관리자 콘솔은 전체 rooms)
    var myRoomIds by mutableStateOf<Set<String>>(emptySet())
    // 개인 고정 방 순서 (room id, 최대 5)
    var roomPins by mutableStateOf<List<String>>(emptyList())
    var error by mutableStateOf<String?>(null)
    var notice by mutableStateOf<String?>(null)
    var loading by mutableStateOf(false)
    // 모임방 설정(회원 관리)에서 보여줄 현재 방 회원 id 목록
    var roomMemberIds by mutableStateOf<List<String>>(emptyList())
    var roomMembersLoaded by mutableStateOf(false)
    var roomMemberCounts by mutableStateOf<Map<String, Int>>(emptyMap())

    // 설정 화면(내 정보 / 방 순서 / 회원 검색) 상태
    var memberSearchQuery by mutableStateOf("")
    var memberSearchByType by mutableStateOf(false)   // false=이름순, true=직종별

    private var activeRoom: String? = null
    var memberListRoomId: String? by mutableStateOf(null)
    private var roomPollJob: Job? = null
    private var messagePollJob: Job? = null

    /** Realtime + 방 목록 Flow 구독 (로그인 후·포그라운드 복귀 시 호출) */
    fun ensureRealtime() {
        if (!loggedIn) return
        MoimRealtimeSync.start(
            scope = viewModelScope,
            onRoomsList = { list -> rooms = list },
            onRoomsRefetch = { refetchRoomsQuiet() },
            onRoomMembersChanged = { onRoomMembersChangedOnly() },
            onProfilesChanged = { reloadProfiles() },
            onWardChanged = { loadWardStatus(); refreshWardDutiesQuiet() },
            onActiveRoomChanged = { rid -> refreshActiveRoom(rid) },
        )
    }

    /** room_members 변경 등 RLS 재조회용 (오류 팝업 없음) */
    private suspend fun refetchRoomsQuiet() {
        try {
            rooms = MoimRepository.rooms()
            // 모임방·DM 은 myRoomIds 로 홈 목록을 거름. superadmin/admin 은 rooms() 가
            // 모든 방을 돌려주므로 myRoomIds 가 stale 하면 본인 참여 방이 사라진다(웹은 함께 갱신).
            myRoomIds = try { MoimRepository.myRoomIds().toSet() } catch (_: Exception) { myRoomIds }
            loadRoomMemberCounts()
            unreadByRoom = MoimRepository.unreadCounts()
            lastMsgByRoom = MoimRepository.roomLastMessages()
        } catch (_: Exception) {
        }
    }

    /** Realtime 보조 — 12초마다 방 목록 재조회 (웹·다른 기기 변경 누락 방지) */
    fun startRoomListPolling() {
        roomPollJob?.cancel()
        roomPollJob = viewModelScope.launch {
            while (isActive && loggedIn) {
                delay(12_000)
                refetchRoomsQuiet()
            }
        }
    }

    fun stopRoomListPolling() {
        roomPollJob?.cancel()
        roomPollJob = null
    }

    /** Realtime 보조 — 열린 방 메시지·일정·자료 3초 폴링 (WS 누락 방지) */
    private fun startMessagePolling() {
        messagePollJob?.cancel()
        messagePollJob = viewModelScope.launch {
            activeRoom?.let { refreshActiveRoom(it) }
            while (isActive) {
                delay(3_000)
                activeRoom?.let { refreshActiveRoom(it) }
            }
        }
    }

    private fun stopMessagePolling() {
        messagePollJob?.cancel()
        messagePollJob = null
    }

    /** 앱이 다시 보일 때(웹 등 다른 클라이언트 변경 반영) */
    fun refreshOnForeground() {
        if (!loggedIn) return
        viewModelScope.launch {
            try {
                MoimRepository.ensureAuthReady()
                MoimRepository.ensureFreshSession()
                if (MoimRepository.currentUserId() == null) return@launch
                refetchRoomsQuiet()
                reloadProfiles()
                activeRoom?.let { refreshActiveRoom(it) }
            } catch (_: Exception) {
                // 사진·파일 선택기 복귀 등 일시적 네트워크/세션 지연 — 조용히 무시
            }
        }
        ensureRealtime()
    }

    /** 가입 신청·승인 상태 등 profiles 변경 시 (관리자 가입 승인 목록 갱신) */
    fun reloadProfiles() {
        viewModelScope.launch {
            try {
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
                MoimRepository.currentUserId()?.let { uid ->
                    profilesById[uid]?.let { myProfile = it }
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun refreshActiveRoom(roomId: String) {
        if (activeRoom != roomId) return
        viewModelScope.launch {
            try {
                messages = MoimRepository.messages(roomId)
                resolveAttachments()
                reactions = MoimRepository.roomReactions(roomId)
            } catch (_: Exception) {
            }
            loadRoomData(roomId)
            markActiveRead()
        }
    }

    fun signUp(email: String, pw: String, name: String, memberType: String, phone: String, intro: String) {
        viewModelScope.launch {
            loading = true; error = null; notice = null
            try {
                MoimRepository.signUp(email, pw, name, memberType, phone, intro)
                if (MoimRepository.currentUserId() != null) {
                    myProfile = MoimRepository.myProfile()
                    rooms = MoimRepository.rooms()
                    profilesById = runCatching { MoimRepository.allProfiles().associateBy { it.id } }.getOrDefault(emptyMap())
                    loggedIn = true
                    ensureRealtime()
                    startRoomListPolling()
                } else {
                    notice = "가입이 접수되었습니다. 전체관리자 승인 후 로그인하여 이용할 수 있습니다."
                }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "회원가입")
            }
            loading = false
        }
    }

    fun login(idInput: String, pw: String) {
        viewModelScope.launch {
            loading = true
            error = null
            try {
                // 이메일 또는 핸드폰번호 로그인: @ 없으면 핸드폰번호로 보고 이메일을 조회
                val email = if (idInput.contains("@")) idInput
                    else MoimRepository.emailForPhone(idInput)
                        ?: throw Exception("등록되지 않은 핸드폰번호입니다. 이메일로 로그인하거나 번호를 확인하세요.")
                MoimRepository.signIn(email, pw)
                try {
                    myProfile = MoimRepository.myProfile()
                } catch (e: Exception) {
                    throw Exception("프로필 조회: ${e.message}", e)
                }
                try {
                    rooms = MoimRepository.rooms()
                } catch (e: Exception) {
                    throw Exception("방 목록 조회: ${e.message}", e)
                }
                loggedIn = true
                ensureRealtime()
                startRoomListPolling()
            } catch (e: Exception) {
                loggedIn = false
                try {
                    MoimRepository.signOut()
                } catch (_: Exception) {
                }
                error = friendlySupabaseError(e, "로그인")
            }
            loading = false
        }
    }

    fun logout() {
        stopRoomListPolling()
        MoimRealtimeSync.stop(viewModelScope)
        viewModelScope.launch {
            try {
                MoimRepository.signOut()
            } catch (_: Exception) {
            }
            loggedIn = false
            rooms = emptyList()
            myProfile = null
        }
    }

    fun loadRooms() {
        viewModelScope.launch {
            try {
                MoimRepository.ensureAuthReady()
                if (MoimRepository.currentUserId() == null) return@launch
                myProfile = MoimRepository.myProfile()
                rooms = MoimRepository.rooms()
                myRoomIds = try { MoimRepository.myRoomIds().toSet() } catch (_: Exception) { myRoomIds }
                loadRoomMemberCounts()
                loadUnreadCounts()
                loadLastMessages()
                loadRoomPins()
                try {
                    profilesById = MoimRepository.allProfiles().associateBy { it.id }
                } catch (_: Exception) {
                    // 이름 표시는 선택적 — 실패해도 진행
                }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "데이터 불러오기")
            }
        }
    }

    fun openRoom(room: Room) {
        activeRoom = room.id
        MoimRealtimeSync.setActiveRoom(viewModelScope, room.id)
        startMessagePolling()
        replyTarget = null
        reactions = emptyList()
        viewModelScope.launch {
            messages = emptyList()
            events = emptyList()
            files = emptyList()
            try {
                messages = MoimRepository.messages(room.id)
                reactions = MoimRepository.roomReactions(room.id)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "메시지 불러오기")
            }
            loadRoomData(room.id)
            markActiveRead()
        }
    }

    private fun loadRoomData(roomId: String) {
        viewModelScope.launch {
            try {
                events = MoimRepository.events(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 불러오기")
            }
            try {
                files = MoimRepository.files(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "자료 불러오기")
            }
        }
    }

    fun closeRoom() {
        stopMessagePolling()
        activeRoom = null
        MoimRealtimeSync.setActiveRoom(viewModelScope, null)
        messages = emptyList()
        reactions = emptyList()
        replyTarget = null
        events = emptyList()
        files = emptyList()
    }

    // ── 캘린더 ──
    fun createEvent(
        title: String,
        startAt: String,
        place: String?,
        link: String?,
        scope: String?,
        description: String?,
        presenter: String?,
        keywords: List<String>,
        attachments: List<Pair<String, ByteArray>>,
        repeatRule: String = "none",
        repeatCount: Int = 1,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.createEvent(
                    rid, title, startAt, place, link, scope, description, presenter, keywords, attachments,
                    repeatRule, repeatCount,
                )
                events = MoimRepository.events(rid)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 등록")
            }
        }
    }

    fun deleteEvent(eventId: String) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.deleteEvent(eventId)
                events = MoimRepository.events(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 삭제")
            }
        }
    }

    fun updateEvent(
        eventId: String,
        title: String,
        startAt: String,
        place: String?,
        link: String?,
        scope: String?,
        description: String?,
        presenter: String?,
        keywords: List<String>,
        keptUrls: List<String>,
        keptNames: List<String>,
        newAttachments: List<Pair<String, ByteArray>>,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.updateEvent(
                    eventId, rid, title, startAt, place, link, scope, description, presenter, keywords,
                    keptUrls, keptNames, newAttachments,
                )
                events = MoimRepository.events(rid)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "일정 수정")
            }
        }
    }

    // ── 자료실 ──
    fun uploadFile(
        fileName: String,
        bytes: ByteArray,
        description: String?,
        keywords: List<String>,
        onDone: () -> Unit,
    ) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.uploadRoomFile(rid, fileName, bytes, description, keywords)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "자료 업로드")
            }
        }
    }

    fun deleteFile(fileId: String, fileUrl: String?, onDone: () -> Unit) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.deleteRoomFile(fileId, fileUrl)
                files = MoimRepository.files(rid)
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "자료 삭제")
            }
        }
    }

    fun canManageFile(uploadedBy: String): Boolean {
        val role = myProfile?.role
        return role == "superadmin" || role == "admin" || uploadedBy == MoimRepository.currentUserId()
    }

    // ── 잔여 병실 현황 (메모) ──
    var wardStatus by mutableStateOf("")
    var wardStatusUpdatedAt by mutableStateOf<String?>(null)

    // ── 당직표 ──
    var wardDuties by mutableStateOf<Map<String, com.example.moimtalk.data.WardDuty>>(emptyMap())
    var wardDutyMonth by mutableStateOf<java.time.YearMonth?>(null)
    var wardTodayDuty by mutableStateOf<com.example.moimtalk.data.WardDuty?>(null)

    fun loadWardStatus() {
        viewModelScope.launch {
            try {
                val w = MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "잔여 병실 현황 불러오기")
            }
        }
    }

    fun loadWardDuties(ym: java.time.YearMonth) {
        wardDutyMonth = ym
        viewModelScope.launch {
            try {
                val from = ym.atDay(1).toString()
                val to = ym.atEndOfMonth().toString()
                wardDuties = MoimRepository.wardDuties(from, to).associateBy { it.dutyDate }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "당직표 불러오기")
            }
        }
    }

    fun refreshWardDutiesQuiet() {
        wardDutyMonth?.let { loadWardDuties(it) }
        loadWardTodayDuty()
    }

    fun loadWardTodayDuty() {
        viewModelScope.launch {
            try {
                val key = java.time.LocalDate.now(java.time.ZoneId.of("Asia/Seoul")).toString()
                wardTodayDuty = MoimRepository.wardDuties(key, key).firstOrNull()
            } catch (_: Exception) { }
        }
    }

    fun saveWardDuty(
        dutyDate: String,
        profDay: String,
        residentDay: String,
        residentNight: String,
        residentOutpatient1: String,
        residentOutpatient2: String,
        onDone: () -> Unit,
    ) {
        viewModelScope.launch {
            try {
                MoimRepository.upsertWardDuty(
                    dutyDate, profDay, residentDay, residentNight, residentOutpatient1, residentOutpatient2,
                )
                wardDutyMonth?.let { loadWardDuties(it) }
                loadWardTodayDuty()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "당직표 저장")
            }
        }
    }

    fun saveWardStatus(content: String, onDone: () -> Unit) {
        viewModelScope.launch {
            try {
                MoimRepository.updateWardStatus(content)
                val w = MoimRepository.wardStatus()
                wardStatus = w.content
                wardStatusUpdatedAt = w.updatedAt
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "잔여 병실 현황 저장")
            }
        }
    }

    /** 가입 승인 (관리자·전체관리자 — RPC) */
    fun approveUser(userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.approveUser(userId)
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "가입 승인")
            }
        }
    }

    /** 역할 지정 (전체관리자만 — RLS). role: user | admin */
    fun setRole(userId: String, role: String) {
        viewModelScope.launch {
            try {
                MoimRepository.updateRole(userId, role)
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "역할 변경")
            }
        }
    }

    /** 회원 계정 비활성화 (전체관리자 — RPC). 글·자료 보존 */
    fun adminDeactivate(userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.adminWithdraw(userId)
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "계정 비활성화")
            }
        }
    }

    /** 비활성 계정 복구(재활성화) (전체관리자 — RPC) */
    fun reactivateUser(userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.reactivate(userId)
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "계정 복구")
            }
        }
    }

    fun createRoom(
        name: String,
        memberIds: List<String>,
        color: String? = null,
        iconBytes: ByteArray? = null,
        iconName: String? = null,
        onDone: () -> Unit,
    ) {
        val trimmed = name.trim()
        // 같은 이름의 모임방 금지 (보이는 방 기준 즉시 검사 + DB 유니크 인덱스가 최종 강제)
        if (rooms.any { it.category == "custom" && it.name.equals(trimmed, ignoreCase = false) }) {
            error = "같은 이름의 모임방이 이미 있습니다. 다른 이름을 사용하세요."
            return
        }
        viewModelScope.launch {
            try {
                MoimRepository.createRoom(trimmed, memberIds, color, iconBytes, iconName)
                rooms = MoimRepository.rooms()
                myRoomIds = try { MoimRepository.myRoomIds().toSet() } catch (_: Exception) { myRoomIds }
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 만들기")
            }
        }
    }

    /** 모임방 삭제 (생성자/관리자). 성공 시 방 목록 갱신 후 onDone. */
    fun deleteRoom(room: Room, onDone: () -> Unit = {}) {
        viewModelScope.launch {
            try {
                MoimRepository.deleteRoom(room.id)
                rooms = MoimRepository.rooms()
                myRoomIds = try { MoimRepository.myRoomIds().toSet() } catch (_: Exception) { myRoomIds }
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "모임방 삭제")
            }
        }
    }

    /** 방 나가기 (본인이 만들지 않은 모임방). 성공 시 방 목록으로 복귀 */
    fun leaveRoom(room: Room, onDone: () -> Unit = {}) {
        viewModelScope.launch {
            try {
                MoimRepository.leaveRoom(room.id)
                activeRoom = null
                rooms = MoimRepository.rooms()
                myRoomIds = try { MoimRepository.myRoomIds().toSet() } catch (_: Exception) { myRoomIds }
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 나가기")
            }
        }
    }

    /** 회원 탈퇴 (본인 데이터 정리 후 계정 삭제, 전체관리자 불가). 성공 시 로그아웃 */
    fun deleteAccount(onDone: () -> Unit = {}) {
        viewModelScope.launch {
            try {
                MoimRepository.deleteAccount()
                logout()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "회원 탈퇴")
            }
        }
    }

    // ── 내 정보 변경 / 회원 검색(1:1 DM) ──

    /** 내 정보 저장: 새 사진이 있으면 먼저 업로드 후 intro/member_type/avatar_url/color 갱신 */
    fun saveMyInfo(
        intro: String,
        memberType: String,
        color: String?,
        avatarBytes: ByteArray?,
        avatarName: String?,
        clearAvatar: Boolean,
        deviceType: String? = null,
        deviceEmail: String? = null,
        onDone: () -> Unit = {},
    ) {
        viewModelScope.launch {
            try {
                var avatarUrl: String? = if (clearAvatar) null else myProfile?.avatarUrl
                if (avatarBytes != null) {
                    avatarUrl = MoimRepository.uploadProfileAvatar(avatarName ?: "avatar.png", avatarBytes)
                }
                val trimmed = intro.trim().takeIf { it.isNotBlank() }
                MoimRepository.updateMyProfile(trimmed, memberType.ifBlank { null }, avatarUrl, color,
                    deviceType?.ifBlank { null }, deviceEmail?.trim()?.ifBlank { null })
                profilesById = MoimRepository.allProfiles().associateBy { it.id }
                MoimRepository.currentUserId()?.let { uid -> profilesById[uid]?.let { myProfile = it } }
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "내 정보 저장")
            }
        }
    }

    /** 비밀번호 변경 (전체관리자 계정은 변경 불가 — 클라이언트 1차 방어 + DB 트리거 최종 강제) */
    fun changeMyPassword(newPassword: String, onResult: (Boolean, String) -> Unit) {
        if (MoimRepository.currentUserEmail()?.equals("jsnoh@ajou.ac.kr", ignoreCase = true) == true) {
            onResult(false, "전체관리자 계정의 비밀번호는 변경할 수 없습니다.")
            return
        }
        viewModelScope.launch {
            try {
                MoimRepository.changePassword(newPassword)
                onResult(true, "비밀번호가 변경되었습니다.")
            } catch (e: Exception) {
                onResult(false, friendlySupabaseError(e, "비밀번호 변경"))
            }
        }
    }

    /** 1:1 DM 열기: 상대 user id → 방 id → 방 목록 갱신 후 해당 방을 콜백으로 전달해 화면 전환 */
    fun startDirect(otherId: String, onOpen: (Room) -> Unit) {
        viewModelScope.launch {
            try {
                val rid = MoimRepository.openDirect(otherId)
                rooms = MoimRepository.rooms()
                myRoomIds = try { MoimRepository.myRoomIds().toSet() } catch (_: Exception) { myRoomIds }
                rooms.firstOrNull { it.id == rid }?.let { onOpen(it) }
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "대화 열기")
            }
        }
    }

    /** 회원 검색 목록: 본인·전체관리자 제외 + 승인·미탈퇴, 이름 부분일치(대소문자 무시) */
    fun searchableMembers(): List<Profile> {
        val q = memberSearchQuery.trim().lowercase()
        // 회원 검색에는 전체관리자도 포함(일반 회원이 전체관리자에게 메시지 가능). 본인·미승인·탈퇴만 제외.
        return profilesById.values.filter {
            it.id != MoimRepository.currentUserId() &&
                it.approved && !it.withdrawn &&
                (q.isEmpty() || it.name.lowercase().contains(q))
        }
    }

    /** room_members 변경 시 회원 목록·인원만 갱신 (방 목록은 Realtime 에서 loadRooms 로 처리) */
    private fun onRoomMembersChangedOnly() {
        memberListRoomId?.let { loadRoomMembers(it) }
        loadRoomMemberCounts()
    }

    fun loadRoomMemberCounts() {
        viewModelScope.launch {
            roomMemberCounts = try {
                MoimRepository.roomMemberCounts()
            } catch (_: Exception) {
                emptyMap()
            }
        }
    }

    /** 현재 방의 회원 목록을 불러와 roomMemberIds 에 저장 */
    fun loadRoomMembers(roomId: String) {
        memberListRoomId = roomId
        roomMembersLoaded = false
        viewModelScope.launch {
            try {
                roomMemberIds = MoimRepository.roomMemberIds(roomId)
            } catch (e: Exception) {
                roomMemberIds = emptyList()
                error = friendlySupabaseError(e, "회원 목록")
            }
            roomMembersLoaded = true
        }
    }

    /** 회원 내보내기 (생성자/관리자). 성공 시 회원 목록 갱신. */
    fun removeRoomMember(roomId: String, userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.removeRoomMember(roomId, userId)
                roomMemberIds = MoimRepository.roomMemberIds(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "회원 내보내기")
            }
        }
    }

    /** 구성원 초대 (방에 회원 추가). 성공 시 회원 목록 갱신. */
    fun inviteRoomMember(roomId: String, userId: String) {
        viewModelScope.launch {
            try {
                MoimRepository.addRoomMembers(roomId, listOf(userId))
                roomMemberIds = MoimRepository.roomMemberIds(roomId)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "구성원 초대")
            }
        }
    }

    fun renameRoom(room: Room, newName: String, onDone: () -> Unit = {}) {
        val trimmed = newName.trim()
        if (trimmed.isEmpty() || trimmed == room.name) { onDone(); return }
        viewModelScope.launch {
            try {
                MoimRepository.updateRoomName(room.id, trimmed)
                rooms = MoimRepository.rooms()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 이름 변경")
            }
        }
    }

    /** 방 정보 변경: 이름·방표식 색상·사진 */
    fun updateRoomAppearance(
        room: Room,
        newName: String,
        color: String?,
        iconBytes: ByteArray?,
        iconName: String?,
        clearIcon: Boolean,
        onDone: () -> Unit = {},
    ) {
        val trimmed = newName.trim().ifEmpty { room.name }
        viewModelScope.launch {
            try {
                MoimRepository.updateRoomAppearance(room.id, trimmed, color, iconBytes, iconName, clearIcon)
                rooms = MoimRepository.rooms()
                onDone()
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "방 정보 변경")
            }
        }
    }

    fun nameOf(userId: String): String = profilesById[userId]?.name ?: "?"

    // 본인 제외 + 승인된 회원만 (대기 중인 가입자는 방에 추가 불가)
    fun otherProfiles(): List<Profile> =
        profilesById.values
            .filter { it.id != MoimRepository.currentUserId() && it.approved != false }
            .sortedBy { it.name }

    fun canEditEvent(e: CalendarEvent): Boolean {
        val role = myProfile?.role
        if (role == "superadmin" || role == "admin") return true
        return e.ownerId == MoimRepository.currentUserId()
    }

    fun send(text: String) {
        val rid = activeRoom
        if (rid == null) return
        val replyId = replyTarget?.id
        replyTarget = null
        viewModelScope.launch {
            try {
                MoimRepository.sendMessage(rid, text, replyId)
                messages = MoimRepository.messages(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "전송")
            }
        }
    }

    /** 답장 대상 설정/해제 (작성 중 입력창 위에 미리보기) */
    fun setReply(m: Message?) { replyTarget = m }

    /** 이모지 리액션 토글 (내 같은 이모지 있으면 취소) */
    fun toggleReaction(messageId: String, emoji: String) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.toggleReaction(messageId, emoji)
                reactions = MoimRepository.roomReactions(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "리액션")
            }
        }
    }

    /** 방별 안읽은 수 갱신 (방 목록) */
    fun loadUnreadCounts() {
        viewModelScope.launch {
            try { unreadByRoom = MoimRepository.unreadCounts() } catch (_: Exception) {}
        }
    }

    /** 방별 마지막 메시지 갱신 (방 목록) */
    fun loadLastMessages() {
        viewModelScope.launch {
            try { lastMsgByRoom = MoimRepository.roomLastMessages() } catch (_: Exception) {}
        }
    }

    /** 개인 고정 방 순서 불러오기 */
    fun loadRoomPins() {
        viewModelScope.launch {
            try { roomPins = MoimRepository.roomPins() } catch (_: Exception) {}
        }
    }

    /** 고정 방 순서 저장 (최대 5) */
    fun saveRoomPins(ids: List<String>) {
        viewModelScope.launch {
            try { MoimRepository.setRoomPins(ids); roomPins = ids.take(5) }
            catch (e: Exception) { error = friendlySupabaseError(e, "방 순서 저장") }
        }
    }

    /** 현재 방을 읽음 처리 + 안읽은 수 갱신 */
    fun markActiveRead() {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.markRead(rid)
                unreadByMsg = MoimRepository.messageUnreadCounts(rid)
                unreadByRoom = MoimRepository.unreadCounts()
            } catch (_: Exception) {}
        }
    }

    /** 본인이 쓴 메시지(텍스트/사진/파일) 삭제 */
    fun deleteMessage(id: String) {
        val rid = activeRoom ?: return
        viewModelScope.launch {
            try {
                MoimRepository.deleteMessage(id)
                messages = MoimRepository.messages(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "메시지 삭제")
            }
        }
    }

    /** 카톡식 첨부 전송 (type = image | file) */
    fun sendAttachment(fileName: String, bytes: ByteArray, type: String, caption: String? = null) {
        val rid = activeRoom
        if (rid == null) return
        viewModelScope.launch {
            try {
                MoimRepository.sendAttachment(rid, fileName, bytes, type, caption)
                messages = MoimRepository.messages(rid)
            } catch (e: Exception) {
                error = friendlySupabaseError(e, "첨부 전송")
            }
        }
    }

    fun isMine(m: Message): Boolean {
        return m.senderId == MoimRepository.currentUserId()
    }

    /** 채팅 첨부(path) → 서명 URL 해석. messages 변경 시 호출(LaunchedEffect). */
    fun resolveAttachments() {
        val paths = messages.mapNotNull { it.attachmentUrl }
            .filter { it.isNotBlank() && !attachmentUrls.containsKey(it) }
            .distinct()
        if (paths.isEmpty()) return
        viewModelScope.launch {
            val map = attachmentUrls.toMutableMap()
            for (p in paths) MoimRepository.chatSignedUrl(p)?.let { map[p] = it }
            attachmentUrls = map
        }
    }
}

// =====================================================================
//  Activity
// =====================================================================
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 폰은 세로 고정, 태블릿(sw600dp)은 회전 허용
        if (resources.getBoolean(R.bool.portrait_only)) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }
        setContent {
            PsyTalkTheme(darkTheme = MoimTheme.dark) {
                App()
            }
        }
    }
}

/** 목록 위 슬라이드 오버레이 — 진입 오른쪽→왼쪽, 복귀 오른쪽으로 */
@Composable
private fun SlideListOverlay(visible: Boolean, content: @Composable () -> Unit) {
    AnimatedVisibility(
        visible = visible,
        modifier = Modifier.fillMaxSize(),
        enter = slideInHorizontally(tween(260)) { it },
        exit = slideOutHorizontally(tween(260)) { it },
    ) { content() }
}

@Composable
fun App(vm: MoimViewModel = viewModel()) {
    var openedRoom by remember { mutableStateOf<Room?>(null) }
    var showWard by remember { mutableStateOf(false) }
    var showCreateRoom by remember { mutableStateOf(false) }
    var showApprovals by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    // 복귀 애니 중에도 RoomScreen 유지(AnimatedVisibility exit)
    var overlayRoom by remember { mutableStateOf<Room?>(null) }
    LaunchedEffect(openedRoom?.id) {
        if (openedRoom != null) overlayRoom = openedRoom
    }

    val lifecycleOwner = LocalLifecycleOwner.current

    LaunchedEffect(vm.loggedIn) {
        if (vm.loggedIn) {
            vm.loadRooms()
            vm.ensureRealtime()
            vm.startRoomListPolling()
        } else {
            vm.stopRoomListPolling()
        }
    }

    // cold start: 저장된 세션을 불러온 뒤 자동 로그인
    LaunchedEffect(Unit) {
        MoimRepository.ensureAuthReady()
        if (!vm.loggedIn && MoimRepository.currentUserId() != null) {
            vm.loggedIn = true
        }
    }

    DisposableEffect(lifecycleOwner, vm.loggedIn) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME && vm.loggedIn) {
                vm.refreshOnForeground()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // 다른 기기·웹에서 방 삭제 시 열린 방 자동 닫기
    LaunchedEffect(vm.rooms, openedRoom?.id) {
        val id = openedRoom?.id ?: return@LaunchedEffect
        if (vm.rooms.none { it.id == id }) {
            vm.closeRoom()
            openedRoom = null
        }
    }

    when {
        !vm.loggedIn -> LoginScreen(vm)
        // 기본값 불승인: approved 가 true 가 아니면(false·미설정) 승인 대기
        vm.myProfile != null && vm.myProfile?.approved != true -> PendingApprovalScreen(vm)
        else -> Box(Modifier.fillMaxSize()) {
            // 방 진입 시에도 목록을 composition 에 유지 → 뒤로가기 시 스크롤 위치 보존
            RoomListScreen(
                vm = vm,
                onOpen = { room ->
                    openedRoom = room
                    vm.openRoom(room)
                },
                onWard = { showWard = true },
                onCreateRoom = { showCreateRoom = true },
                onApprovals = { showApprovals = true },
                onSettings = { showSettings = true }
            )
            SlideListOverlay(showSettings) {
                SettingsScreen(
                    vm = vm,
                    onBack = { showSettings = false },
                    onOpenRoom = { room ->
                        showSettings = false
                        openedRoom = room
                        overlayRoom = room
                        vm.openRoom(room)
                    }
                )
            }
            SlideListOverlay(showApprovals && vm.myProfile?.let { isAdminRole(it.role) } == true) {
                AdminConsoleScreen(vm = vm, onBack = { showApprovals = false })
            }
            SlideListOverlay(showCreateRoom) {
                CreateRoomScreen(vm = vm, onBack = { showCreateRoom = false })
            }
            SlideListOverlay(openedRoom != null) {
                overlayRoom?.let { room ->
                    RoomScreen(
                        vm = vm,
                        room = room,
                        onBack = {
                            vm.closeRoom()
                            openedRoom = null
                        }
                    )
                }
            }
            SlideListOverlay(showWard) {
                WardStatusScreen(vm = vm, onBack = { showWard = false })
            }
        }
    }

    // 전역 오류 표시 (등록/수정/업로드 실패 원인이 보이도록)
    vm.error?.let { msg ->
        AlertDialog(
            onDismissRequest = { vm.error = null },
            confirmButton = { TextButton(onClick = { vm.error = null }) { Text("확인") } },
            title = { Text("오류") },
            text = { Text(msg) }
        )
    }
}
