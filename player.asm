.386
.model flat, stdcall
option casemap : none
.stack 4096

include	player.inc

.code
start:
	invoke GetModuleHandle, NULL
	mov	hInstance, eax
	invoke DialogBoxParam, hInstance,IDD_MAIN, 0, offset mainProc, 0
	invoke ExitProcess, 0

;######################################################
;the main dialog callback function
;param:
;	dialogHandle: the handle of the main dialog
;	message: the user message sent to the dialog
;	wParam: the addtional info of the message
;	lParam: the addtional info of the message
;######################################################
mainProc proc dialogHandle : dword, message : dword, wParam : dword, lParam : dword
	local wc : WNDCLASSEX
	mov eax,dialogHandle
	mov mainHandle,eax
	mov eax, message

	.if eax == WM_INITDIALOG
		mov   wc.style, CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS
		invoke RegisterClassEx, addr wc
		invoke dialogInit, dialogHandle

	.elseif eax == WM_COMMAND
		mov	eax, wParam
		.if	eax == IDC_PLAY
			.if currentTotalSongNumber != 0
				invoke musicPlayControl, dialogHandle, playButtonState, currentSongIndex
			.endif
		.elseif eax == IDC_LOCAL
			invoke DialogBoxParam, hInstance, IDD_LIST, 0, offset listProc, 0
		.elseif eax == IDC_PRE
			.if currentTotalSongNumber !=  0
				invoke preIndex, currentSongIndex
				mov currentSongIndex, eax
				mov playButtonState, _BEGIN
				invoke musicPlayControl, dialogHandle, playButtonState, currentSongIndex
			.endif
		.elseif eax == IDC_NEXT
			.if currentTotalSongNumber != 0
				invoke nextIndex, currentSongIndex
				mov currentSongIndex, eax
				mov playButtonState, _BEGIN
				invoke musicPlayControl, dialogHandle, playButtonState, currentSongIndex
			.endif
		.elseif eax == IDC_VOLBUTTON
			.if hasSound == 1
				mov hasSound, 0
			.else
				mov hasSound, 1
			.endif
			invoke changeVolume, dialogHandle
		.elseif eax == IDC_PLAYMODE
			invoke nextMode, playMode
			mov playMode, al
			invoke playModeControl, dialogHandle, playMode
		.elseif eax == IDC_LYRICBUTTON
			invoke changeLycState, dialogHandle
		.endif
	.elseif eax == WM_TIMER	
		.if playButtonState == _PLAY		
			invoke changeProgressBar, dialogHandle
			invoke displayLyric, dialogHandle
			invoke checkPlay, dialogHandle	; check if finished
		.endif
	.elseif eax == WM_HSCROLL
		invoke GetDlgCtrlID, lParam
		mov currentSlider, eax
		mov ax, WORD PTR wParam			
		; move progress bar
		.if currentSlider == IDC_PROGRESS
			; end move bar
			.if ax == SB_ENDSCROLL					
				mov isDraggingProgressBar, 0
				; song exist
				.if currentTotalSongNumber != 0				
					invoke changeTime, dialogHandle	
				.endif
			.elseif ax == SB_THUMBTRACK
				mov isDraggingProgressBar, 1 ; TODO: the time show need to change
				.if currentTotalSongNumber != 0				
					invoke displayTime, dialogHandle
				.endif
			.endif
		; move volume bar
		.elseif currentSlider == IDC_VOLUME
			.if currentTotalSongNumber != 0
				mov hasSound, 1
				invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_GETPOS, 0, 0
				mov currentVol, eax
				invoke changeVolume, dialogHandle
			.endif
		.endif
	.elseif	eax == WM_CLOSE
		invoke	EndDialog, dialogHandle, 0
	.endif
	xor eax, eax
	ret
mainProc endp

;######################################################
;the main dialog init function, prepare the relative variables
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
dialogInit proc dialogHandle : dword
	invoke playButtonControl, dialogHandle, _PAUSE
	mov playButtonState, _BEGIN
	mov currentSongIndex, 0
	mov playMode, _LIST
	invoke playModeControl, dialogHandle, playMode

	invoke wsprintf, addr mediaCommand, addr blankSongName
	invoke SendDlgItemMessage, dialogHandle, IDC_NAMESHOW, WM_SETTEXT, 0, addr mediaCommand

	invoke wsprintf, addr mediaCommand, addr timeShow, 0, 0, 0, 0
	invoke SendDlgItemMessage, dialogHandle, IDC_PROSHOW, WM_SETTEXT, 0, addr mediaCommand

	invoke SendDlgItemMessage, dialogHandle, IDC_PROGRESS, TBM_SETPOS, 1, 0

	mov hasSound, 1
	; set volume slider
	invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_SETRANGEMIN, 0, 0
	invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_SETRANGEMAX, 0, volumeSize
	mov edx, 0
	mov eax, volumeSize
	mov ebx, 2
	div ebx
	mov currentVol, eax
	invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_SETPOS, 1, eax
	;invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_SETPOS, 1, volumeSize
	invoke changeVolume, dialogHandle

	; set timer
	invoke SetTimer, dialogHandle, 1, 500, NULL
	ret
dialogInit endp

;######################################################
;the music play control function
;param:
;	dialogHandle: the handle of the main dialog
;	state: the state of the music (with currentSongIndex) before the button pushed
;	curSongIndex: the index of the music in the list
;######################################################
musicPlayControl proc dialogHandle : dword, state : byte, curSongIndex: dword
	.if state == _BEGIN
		invoke closeSong, dialogHandle
		invoke playButtonControl, dialogHandle, _PLAY
		invoke playSong, dialogHandle, curSongIndex;

		invoke mciSendString, addr playSongCommand, NULL, 0, NULL
		
		invoke mciSendString, addr getLengthCommand, addr songLength, 32, NULL	
		invoke StrToInt, addr songLength
		invoke SendDlgItemMessage, dialogHandle, IDC_PROGRESS, TBM_SETRANGEMAX, 0, eax
	
		invoke StrToInt, addr songLength
		mov edx, 0
		div timeScale
	
		mov edx, 0
		div timeScaleSec
		mov timeMinuteLength, eax
		mov timeSecondLength, edx

		invoke changeVolume, dialogHandle
		invoke displaySongName, dialogHandle, curSongIndex
	.elseif state == _PAUSE
		invoke playButtonControl, dialogHandle, _PLAY
		invoke mciSendString, addr resumeSongCommand, NULL, 0, NULL
	.else
		invoke playButtonControl, dialogHandle, _PAUSE
		invoke mciSendString, addr pauseSongCommand, NULL, 0, NULL
	.endif

	ret
musicPlayControl endp


;######################################################
;the play button icon control function
;param:
;	dialogHandle: the handle of the main dialog
;	state: the state of the music (with currentSongIndex) you wish after the button pushed
;######################################################
playButtonControl proc dialogHandle : dword, state : byte
	.if state == _PAUSE
		mov eax, IDI_PLAY
		mov playButtonState, _PAUSE
	.else
		mov eax, IDI_PAUSE
		mov playButtonState, _PLAY
	.endif

	invoke LoadImage, hInstance, eax, IMAGE_ICON, ICON_WIDTH, ICON_HEIGHT, LR_DEFAULTCOLOR
	invoke SendDlgItemMessage, dialogHandle, IDC_PLAY, BM_SETIMAGE, IMAGE_ICON, eax
	
	ret
playButtonControl endp

deleteSingleSong proc dialogHandle:dword,deleteSongIndex:dword
	invoke SendDlgItemMessage, dialogHandle, IDC_SONG_LIST, LB_DELETESTRING, deleteSongIndex, 0

	mov ebx, deleteSongIndex
	mov edi, OFFSET songList
	mov edx, SIZEOF songStructure
	imul edx, ebx
	add edi, edx					;get index of the song to be deleted

	dec currentTotalSongNumber

	mov ecx, deleteSongIndex
	.while ecx < currentTotalSongNumber
		pushad
		invoke lstrcpy,ADDR (songStructure PTR [edi]).songName,ADDR blankSongName
		invoke lstrcpy,ADDR (songStructure PTR [edi]).songPath,ADDR blankSongName
		mov esi,edi
		add esi,SIZEOF songStructure
		invoke lstrcpy,ADDR (songStructure PTR [edi]).songName,ADDR (songStructure PTR [esi]).songName
		invoke lstrcpy,ADDR (songStructure PTR [edi]).songPath,ADDR (songStructure PTR [esi]).songPath
		popad
		inc ecx
		add edi,SIZEOF songStructure
	.endw

	ret
deleteSingleSong endp

deleteSong proc dialogHandle:dword,deleteSongIndex:dword
	mov eax,deleteSongIndex
	.if eax != currentSongIndex
		invoke deleteSingleSong,dialogHandle,deleteSongIndex
		mov eax,deleteSongIndex
		.if eax < currentSongIndex
			dec currentSongIndex
		.endif
	.else
		invoke closeSong,mainHandle
		invoke deleteSingleSong,dialogHandle,deleteSongIndex
		.if currentTotalSongNumber == 0
			invoke dialogInit,mainHandle
		.else
			mov eax,deleteSongIndex
			.if eax == currentTotalSongNumber
				mov currentSongIndex,0
			.endif
			invoke musicPlayControl, mainHandle, _BEGIN, currentSongIndex   ;change the song
		.endif		
	.endif
	ret
deleteSong endp

;######################################################
;the list dialog callback function
;param:
;	dialogHandle: the handle of the music list dialog
;	message: the user message sent to the dialog
;	wParam: the addtional info of the message
;	lParam: the addtional info of the message
;######################################################
listProc proc dialogHandle : dword, message : dword, wParam : dword, lParam : dword
	local wc : WNDCLASSEX
	mov eax, message

	.if eax == WM_INITDIALOG
		mov   wc.style, CS_HREDRAW or CS_VREDRAW or CS_DBLCLKS
		invoke RegisterClassEx, addr wc
		invoke listDialogInit, dialogHandle
	.elseif eax == WM_COMMAND
		mov	eax, wParam
		.if	eax == IDC_IMPORT
			invoke importSongToList, dialogHandle
			mov eax, wParam
		.elseif eax == IDC_DELETE
			.if currentTotalSongNumber != 0 && hasFocuseSong == 1
				invoke deleteSong,dialogHandle,focusedSongIndex
				mov hasFocuseSong,0
				mov focusedSongIndex,500
			.endif
		.elseif eax == IDC_PLAY_FOCUSED
			.if currentTotalSongNumber != 0 && hasFocuseSong == 1
				mov eax,focusedSongIndex
				mov currentSongIndex,eax
				invoke musicPlayControl, mainHandle, _BEGIN, currentSongIndex   ;change the song
				invoke	EndDialog, dialogHandle, 0
				mov hasFocuseSong,0
				mov focusedSongIndex,500
			.endif
		.elseif ax == IDC_SONG_LIST
			shr eax,16
			.if ax == LBN_SELCHANGE	
				invoke SendDlgItemMessage, dialogHandle, IDC_SONG_LIST, LB_GETCURSEL, 0, 0	;get the index
				mov hasFocuseSong,1
				mov focusedSongIndex,eax
				.if eax == tempSongIndex
					mov currentSongIndex, eax
					invoke musicPlayControl, mainHandle, _BEGIN, eax   ;change the song
					invoke	EndDialog, dialogHandle, 0
					mov hasFocuseSong,0
					mov focusedSongIndex,500
				.else
					mov tempSongIndex,eax
				.endif
			.endif
		.endif
	.elseif eax == WM_TIMER	
		mov tempSongIndex,500
	.elseif	eax == WM_CLOSE
		invoke	EndDialog, dialogHandle, 0
		mov hasFocuseSong,0
		mov focusedSongIndex,500
	.endif
	xor eax, eax
	ret
listProc endp

;######################################################
;print the music list
;param:
;	dialogHandle: the handle of the music list dialog
;######################################################
listDialogInit proc dialogHandle: dword
	; set timer
	invoke SetTimer, dialogHandle, 1, 800, NULL

	mov ebx,0
	mov ecx,currentTotalSongNumber
	.WHILE ecx != 0
		mov edi, OFFSET songList
		mov edx, SIZEOF songStructure
		imul edx, ebx
		add edi, edx
		pushad
		invoke SendDlgItemMessage, dialogHandle, IDC_SONG_LIST, LB_ADDSTRING, 0, ADDR (songStructure PTR [edi]).songName
		popad
		add ebx,1
		sub ecx,1
	.ENDW
	ret
listDialogInit endp

;######################################################
;the Progress Bar control function, change the progess bar after the timer event
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
changeProgressBar proc dialogHandle: dword
	local temp: dword
	.if playButtonState == _PLAY		
		invoke mciSendString, addr getPositionCommand, addr songPosition, 32, NULL
		invoke StrToInt, addr songPosition	
		;add eax, 1000
		mov temp, eax
		.if isDraggingProgressBar == 0	
			invoke SendDlgItemMessage, dialogHandle, IDC_PROGRESS, TBM_SETPOS, 1, temp
		.endif
		invoke displayTime, dialogHandle
	.endif
	ret
changeProgressBar endp

;######################################################
;the time display control function, change the time text according to time
;param:
;	dialogHandle: the handle of the main dialog
;	currentPosition: the time of the music now
;######################################################
displayTime proc dialogHandle: dword
	invoke SendDlgItemMessage, dialogHandle, IDC_PROGRESS, TBM_GETPOS, 0, 0
	mov edx, 0
	div timeScale
	
	mov edx, 0
	div timeScaleSec
	mov timeMinutePosition, eax
	mov timeSecondPosition, edx
	invoke wsprintf, addr mediaCommand, addr timeShow, timeMinutePosition, timeSecondPosition, timeMinuteLength, timeSecondLength
	invoke SendDlgItemMessage, dialogHandle, IDC_PROSHOW, WM_SETTEXT, 0, addr mediaCommand
	ret
displayTime endp

;######################################################
;the time control function, change the time after the bar scolled
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
changeTime proc dialogHandle: dword
	invoke SendDlgItemMessage, dialogHandle, IDC_PROGRESS, TBM_GETPOS, 0, 0		
	invoke wsprintf, addr mediaCommand, addr setPositionCommand, eax
	invoke mciSendString, addr mediaCommand, NULL, 0, NULL

	.if playButtonState == _PLAY	
		invoke mciSendString, addr playSongCommand, NULL, 0, NULL
	.elseif playButtonState == _PAUSE
		invoke mciSendString, addr playSongCommand, NULL, 0, NULL
		invoke mciSendString, addr pauseSongCommand, NULL, 0, NULL
	.endif
	ret
changeTime endp


;######################################################
;the volume control function, change the volume by slider
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
changeVolume proc dialogHandle: dword
	.if hasSound == 1
		invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_SETPOS, 1, currentVol
		invoke wsprintf, addr mediaCommand, addr adjustVolumeCommand, currentVol
		.if currentVol == 0
			invoke changeVolumeIcon, dialogHandle, _MUTE
		.elseif currentVol <= 33
			invoke changeVolumeIcon, dialogHandle, _LOW
		.elseif currentVol > 66
			invoke changeVolumeIcon, dialogHandle, _LOUD
		.else
			invoke changeVolumeIcon, dialogHandle, _MID
		.endif
	.else
		invoke wsprintf, addr mediaCommand, addr adjustVolumeCommand, 0
		invoke changeVolumeIcon, dialogHandle, _MUTE
	.endif
	invoke mciSendString, addr mediaCommand, NULL, 0, NULL
	invoke displayVolume, dialogHandle
	
	ret
changeVolume endp


;######################################################
;the volume display function, show the volume by text
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
displayVolume proc dialogHandle: dword
	invoke SendDlgItemMessage, dialogHandle, IDC_VOLUME, TBM_GETPOS, 0, 0
	invoke wsprintf, addr mediaCommand, addr int2str, eax
	invoke SendDlgItemMessage, dialogHandle, IDC_VOLSHOW, WM_SETTEXT, 0, addr mediaCommand
	ret
displayVolume endp


;######################################################
;the volume icon function, change the vol icon by volume
;param:
;	dialogHandle: the handle of the main dialog
;	state: the status of volume
;######################################################
changeVolumeIcon proc dialogHandle: dword, state: byte
	.if state == _MUTE
		mov eax, IDI_MUTE
	.elseif state == _LOW
		mov eax, IDI_LOW
	.elseif state == _MID
		mov eax, IDI_MID
	.else
		mov eax, IDI_LOUD
	.endif

	invoke LoadImage, hInstance, eax, IMAGE_ICON, ICON_WIDTH, ICON_HEIGHT, LR_DEFAULTCOLOR
	invoke SendDlgItemMessage, dialogHandle, IDC_VOLBUTTON, BM_SETIMAGE, IMAGE_ICON, eax

	ret
changeVolumeIcon endp

;######################################################
;the play control function, open the music of the index given
;param:
;	dialogHandle: the handle of the main dialog
;	index: the index of the music of list
;######################################################
playSong proc dialogHandle: dword, index: dword
	; find the lyrics file
	invoke readLrcFile, dialogHandle, index

	; accept path to open the song
	mov edi, OFFSET songList
	mov ebx, SIZEOF songStructure
	imul ebx, index
	add edi, ebx					

	invoke wsprintf, addr mediaCommand, addr openSongCommand, addr (songStructure PTR [edi]).songPath
	invoke mciSendString, addr mediaCommand, NULL, 0, NULL

	ret
playSong endp

;######################################################
;the play control function, close the current music
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
closeSong proc uses eax dialogHandle: dword
	invoke mciSendString, ADDR closeSongCommand, NULL, 0, NULL
	ret
closeSong endp

;######################################################
;check the music over or not, call after the timer event
;param:
;	dialogHandle: the handle of the main dialog
;######################################################
checkPlay proc dialogHandle: dword
	local temp: dword

	.if playButtonState == _PLAY
		invoke StrToInt, addr songLength
		mov temp, eax
		invoke StrToInt, addr songPosition
		.if eax >= temp		; the song is over
		; TODO add different play mode
		; TODO need new index
			invoke nextIndexByMode, currentSongIndex
			mov currentSongIndex, eax
			mov playButtonState, _BEGIN
			invoke musicPlayControl, dialogHandle, playButtonState, currentSongIndex
		.endif
	.endif
	Ret
checkPlay endp

checkSongNameSuffix proc nameAddr:dword,nameLength:dword
	mov ecx,nameLength
	dec ecx
	mov esi,nameAddr
	add esi,ecx
	
	mov bl,[esi]
	.while ecx >= 0 && bl != '.'
		dec ecx
		dec esi
		mov bl,[esi]
	.endw

	.if ecx == -1
		mov eax,0
	.else 
		inc esi
		invoke lstrcpy,ADDR tempName, esi
		invoke lstrlen,ADDR tempName

		.if eax == 3
			.if tempName[0] == 'w' && tempName[1] == 'm' && tempName[2] == 'a'
				mov eax,1
			.elseif tempName[0] == 'c' && tempName[1] == 'd' && tempName[2] == 'a'
				mov eax,1
			.elseif tempName[0] == 'w' && tempName[1] == 'a' && tempName[2] == 'v'
				mov eax,1
			.elseif tempName[0] == 'm' && tempName[1] == 'p' && tempName[2] == '3'
				mov eax,1
			.elseif tempName[0] == 'm' && tempName[1] == '4' && tempName[2] == 'a'
				mov eax,1
			.else
				mov eax,0
			.endif
		.elseif eax == 4
			.if tempName[0] == 'f' && tempName[1] == 'l' && tempName[2] == 'a' && tempName[3] == 'c'
				mov eax,1
			.else
				mov eax,0
			.endif
		.else
			mov eax,0
		.endif
	.endif

	ret
checkSongNameSuffix endp

checkRepeatedSongName proc nameAddr:dword
	local isNameRepeated:dword
	local cnt:dword
	
	mov isNameRepeated,0
	mov ecx,0
	mov cnt,ecx																	;must use cnt to temporarily store ecx to avoid possible changes on it 
	mov edi, OFFSET songList
	.while ecx < currentTotalSongNumber && isNameRepeated == 0
		invoke lstrcpy,ADDR tempName2, ADDR (songStructure PTR [edi]).songName
		invoke lstrcmp,nameAddr,ADDR tempName2
		.if eax ==0
			mov isNameRepeated,1
		.endif
		add edi, SIZEOF songStructure
		inc cnt
		mov ecx,cnt
	.endw

	.if isNameRepeated == 0
		mov eax,0
	.else
		mov eax,1
	.endif
	ret
checkRepeatedSongName endp

checkSongName proc nameAddr:dword,nameLength:dword
	invoke checkSongNameSuffix,nameAddr,nameLength
	.if eax == 1
		invoke checkRepeatedSongName,nameAddr
		.if eax == 1
			mov eax,0
		.else
			mov eax,1
		.endif
	.else
		mov eax,0
	.endif
	ret
checkSongName endp


importSingleSong proc dialogHandle:dword,tempPathAddr:dword,lpstrAddr:dword,fileOffset:word
	mov esi,lpstrAddr
	mov ebx,0
	mov bx,fileOffset		;not the same size,should change to the same
	add esi,ebx							;now file name stored in the esi(beginning address)
	invoke lstrcpy,tempPathAddr, esi	;now file name stored in the tempPath

	invoke lstrlen,tempPathAddr
	invoke checkSongName,tempPathAddr,eax

	.if eax == 1
		;print the file name
		invoke SendDlgItemMessage, dialogHandle, IDC_SONG_LIST, LB_ADDSTRING, 0, tempPathAddr

		mov edi, OFFSET songList
		mov ebx, SIZEOF songStructure
		imul ebx, currentTotalSongNumber
		add edi, ebx					;the  beginning address of the new song
		invoke lstrcpy, ADDR (songStructure PTR [edi]).songName, tempPathAddr
		invoke lstrcpy, ADDR (songStructure PTR [edi]).songPath, lpstrAddr

		;total number ++
		add currentTotalSongNumber,1
	.endif

	ret
importSingleSong endp


;######################################################
;add a music to the list after the import button pushed
;param:
;	dialogHandle: the handle of the music list dialog
;######################################################
importSongToList proc dialogHandle: dword
	invoke	RtlZeroMemory,addr fileDialog,sizeof fileDialog
	mov	fileDialog.lStructSize,sizeof fileDialog
	push	dialogHandle
	pop	fileDialog.hwndOwner
	mov	fileDialog.lpstrFile,offset lpstrFileNames
	mov	fileDialog.nMaxFile,SIZEOF lpstrFileNames
	mov	fileDialog.Flags,OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
	invoke	GetOpenFileName,addr fileDialog

	.if eax
		;get the parent path and the true path of the selected file(in turn)
		invoke lstrcpyn, ADDR tempPath, ADDR lpstrFileNames, fileDialog.nFileOffset
		invoke importSingleSong, dialogHandle, ADDR tempPath, ADDR lpstrFileNames, fileDialog.nFileOffset
	.endif

	ret
importSongToList endp

; ######################################################
; increase the index
; param:
;	curIndex: the index to increase
; return:
;	newIndex: increased index
; ######################################################
nextIndex proc curIndex : dword
	inc curIndex
	mov ebx, curIndex
	.if ebx >= currentTotalSongNumber
		mov curIndex, 0
	.endif
	mov eax, curIndex
	ret
nextIndex endp

; ######################################################
; increase the index considering the playMode
; param:
;	curIndex: the index to increase considering the playMode
; return:
;	newIndex: increased index considering the playMode
; ######################################################
nextIndexByMode proc curIndex : dword
	.if playMode == _SINGLE
		mov eax, curIndex
		ret
	.elseif playMode == _RANDOM
		.if currentTotalSongNumber == 1
			mov eax, 0
			ret
		.endif
		invoke crt_rand
		mov edx, 0
		mov ebx, currentTotalSongNumber
		dec ebx
		div ebx
		.if edx >= curIndex
			inc edx
		.endif
		mov eax, edx
		ret
	.endif

	; now playMode == _LIST
	inc curIndex
	mov ebx, curIndex
	.if ebx >= currentTotalSongNumber
		mov curIndex, 0
	.endif
	mov eax, curIndex
	ret
nextIndexByMode endp

; ######################################################
; decrease the index
; param:
;	curIndex: the index to decrease
; return:
;	newIndex: decreased index
; ######################################################
preIndex proc curIndex : dword
	mov ebx, curIndex
	.if ebx == 0
		mov eax, currentTotalSongNumber
		dec eax
		ret
	.endif
	dec curIndex
	mov eax, curIndex
	ret
preIndex endp

; ######################################################
; display the name of the song in the text control
; param:
;	dialogHandle: the handle of the main dialog
;	curIndex: the index to decrease
; return:
;	newIndex: decreased index
; ######################################################
displaySongName proc dialogHandle : dword, curIndex : dword
	mov edi, OFFSET songList
	mov ebx, SIZEOF songStructure
	imul ebx, curIndex
	add edi, ebx
	invoke wsprintf, addr mediaCommand, addr(songStructure PTR[edi]).songName
	invoke SendDlgItemMessage, dialogHandle, IDC_NAMESHOW, WM_SETTEXT, 0, addr mediaCommand
	ret
displaySongName endp

; ######################################################
; the play mode and its icon control function
; param:
;	dialogHandle: the handle of the main dialog
;	mode: the play mode you wish after the function
; ######################################################
playModeControl proc dialogHandle : dword, mode : byte
	.if mode == _LIST
		mov eax, IDI_LIST
		mov playMode, _LIST
	.elseif mode == _SINGLE
		mov eax, IDI_SINGLE
		mov playMode, _SINGLE
	.else
		mov eax, IDI_RANDOM
		mov playMode, _RANDOM
	.endif

	invoke LoadImage, hInstance, eax, IMAGE_ICON, ICON_WIDTH, ICON_HEIGHT, LR_DEFAULTCOLOR
	invoke SendDlgItemMessage, dialogHandle, IDC_PLAYMODE, BM_SETIMAGE, IMAGE_ICON, eax
	ret
playModeControl endp

; ######################################################
; increase the mode
; param:
;	mode: current mode
; return:
;	newMode: increased mode
; ######################################################
nextMode proc mode : byte
	.if mode == _LIST
		mov eax, _SINGLE
	.elseif mode == _SINGLE
		mov eax, _RANDOM
	.elseif mode == _RANDOM
		mov eax, _LIST
	.endif

	ret
nextMode endp


; ######################################################
; read the lrc file from the path of songlist
; param:
;	dialogHandle: handle, index: index of the song
; ######################################################
readLrcFile proc dialogHandle:dword, index:dword
	local hFile: dword
	local currentTime: dword
	local dscale: dword
	local offs: dword
	local times: dword

	mov lyricLines, 0
	
	mov offs, 48 ;asc to int 0
	
	; get the path
	mov edi, OFFSET songList
	mov ebx, SIZEOF songStructure
	imul ebx, index
	add edi, ebx
	invoke lstrcpy, addr lrcFile, addr (songStructure PTR [edi]).songPath
	
	; find '.' and add 'lrc'
	invoke StrRStrI,addr lrcFile, NULL, addr point
	mov esi, eax
	invoke lstrcpy,esi, addr lrcSuffix

	invoke CreateFile,addr lrcFile, GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
	mov hFile, eax
	; failed to open
	.if hFile == INVALID_HANDLE_VALUE
		mov hasLyric, byte ptr 0
		invoke SendDlgItemMessage, dialogHandle, IDC_Lyric, WM_SETTEXT, 0, addr noLyricText
	; has lyrics
	.else
		mov hasLyric, byte ptr 1
		mov currentLyricIndex, 0
		invoke ReadFile, hFile, addr lrcBuffer, sizeof lrcBuffer, addr actualReadBytes, NULL
		
		; find next sentence
		mov times, 0
		invoke StrStrI,addr lrcBuffer, addr lyricNextSentence
		mov esi, eax

		;[00:00.84]´Ê£ºWILLIUS/RK

		L1:
		movzx ebx, byte ptr [esi+1]
		; jump to the num
		.if ebx>=48;'0'
			.if ebx<=57;'9'
				;lyric progress min:sec.centisec
				movzx eax, byte ptr [esi+1]
				sub eax, offs
				mov dscale, 10
				mul dscale
				
				movzx ebx, byte ptr [esi+2]
				sub ebx, offs
				add eax, ebx
				mov dscale, 60
				mul dscale
				
				push eax
				
				movzx eax, byte ptr [esi+4]
				sub eax, offs
				mov dscale, 10
				mul dscale
				
				movzx ebx, byte ptr [esi+5]
				sub ebx, offs
				add eax, ebx
				
				pop ebx
				
				add eax, ebx
				
				mov dscale, 100
				mul dscale
				
				push eax
				
				movzx eax, byte ptr [esi+7]
				sub eax, offs
				mov dscale, 10
				mul dscale
				
				movzx ebx, byte ptr [esi+8]
				sub ebx,offs
				add eax, ebx
				
				pop ebx
				add eax, ebx
				
				mov dscale, 10
				mul dscale
				
				mov currentTime, eax
				mov eax, times
				mov ebx, type dword
				mul ebx
				mov ebx, currentTime
				mov [lyricTimes + eax], ebx
				mov [lyricAddrs + eax], esi
				
				invoke StrStrI,addr [esi+1], addr lyricNextSentence
				.if eax != 0
					mov esi, eax
			
					inc times
					jmp L1
				.else
					mov eax, times
					mov maxLyricIndex, eax
					jmp _END
				.endif
			; if ebx > 9
			.else
				invoke StrStrI,addr [esi+1], addr lyricNextSentence
				mov esi, eax
				cmp eax, 0
				jne L1
				jmp _END
			.endif
		.else
			invoke StrStrI,addr [esi+1], addr lyricNextSentence
			mov esi, eax
			cmp eax, 0
			jne L1
			jmp _END
		.endif
	.endif
	_END:
	invoke CloseHandle, hFile
	
	ret
readLrcFile endp

; ######################################################
; show the lyrics 
; param:
;	dialogHandle: handle
; ######################################################
displayLyric proc dialogHandle: dword
	local tmpLoop:dword
	local currentTime:dword
	local lastTime:dword
	local curSongPos:dword
	.if playButtonState == _PLAY
		.if hasLyric == 1
			.if lyricVisible == 1
				invoke mciSendString, addr getPositionCommand, addr songPosition, 32, NULL
				invoke StrToInt, addr songPosition
				mov curSongPos, eax
				
				
				mov tmpLoop, 0
				mov lastTime, 0
				mov currentTime, 0
				mov edx, tmpLoop
				.while edx <= maxLyricIndex
					mov eax, tmpLoop
					mov ebx, type dword
					mul ebx
					
					mov ebx, lyricTimes[eax]
					mov currentTime, ebx
					.if ebx > curSongPos
						
						mov edi, lyricAddrs[eax]
						mov ebx, tmpLoop
						.if ebx == 0
							invoke SendDlgItemMessage, dialogHandle, IDC_Lyric, WM_SETTEXT, 0, addr lyricPreparation
						.else
							mov eax, tmpLoop
							mov ebx, type dword
							mul ebx
							
							sub eax, type dword
							mov esi, lyricAddrs[eax]
							mov edx, edi
							sub edx, esi
							sub edx, 10
							invoke lstrcpyn, addr longStr, addr [esi+10], edx
							invoke SendDlgItemMessage, dialogHandle, IDC_Lyric, WM_SETTEXT, 0, addr longStr
						.endif
						jmp dL_LEND
					.endif
					inc tmpLoop
					mov edx, tmpLoop
				.endw
			.endif
		.endif
	.endif
	dL_LEND:
	ret
displayLyric endp

; ######################################################
; change the lyric button state
; param:
;	dialogHandle: handle
; ######################################################
changeLycState proc dialogHandle: dword
	.if lyricVisible == 1
		mov lyricVisible, 0
		invoke SendDlgItemMessage, dialogHandle, IDC_Lyric, WM_SETTEXT, 0, addr lyricEmpty
	.else
		mov lyricVisible, 1
	.endif
	ret
changeLycState endp

end start