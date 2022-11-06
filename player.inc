; include requirements
include windows.inc
include user32.inc
include kernel32.inc
include gdi32.inc
include winmm.inc
include shlwapi.inc
include Comdlg32.inc
include msvcrt.inc
include shell32.inc

includelib	Comdlg32.lib
includelib winmm.lib
includelib shlwapi.lib
includelib	user32.lib
includelib	kernel32.lib
includelib gdi32.lib
includelib msvcrt.lib
includelib shell32.lib

; function declare
printf   proto C :ptr sbyte, :VARARG
mainProc proto dialogHandle:dword,message:dword, wParam:dword,lParam:dword
listProc proto dialogHandle:dword,message:dword, wParam:dword,lParam:dword
dialogInit proto dialogHandle : dword
musicPlayControl proto dialogHandle : dword, state : byte, curSongIndex: dword
playButtonControl proto dialogHandle : dword, state : byte
changeProgressBar proto dialogHandle: dword
displayTime proto dialogHandle: dword
changeTime proto dialogHandle: dword
importSongToList proto dialogHandle: dword
playSong proto dialogHandle: dword, index: dword
listDialogInit proto dialogHandle:dword
changeSong proto dialogHandle: dword, newSongIndex: dword
closeSong proto dialogHandle: dword
checkPlay proto dialogHandle: dword
nextIndex proto curIndex : dword
nextIndexByMode proto curIndex : dword
preIndex proto curIndex : dword
changeVolume proto dialogHandle: dword
displayVolume proto dialogHandle: dword
changeVolumeIcon proto dialogHandle: dword, state: byte
displaySongName proto dialogHandle : dword, curIndex : dword
playModeControl proto dialogHandle : dword, mode : byte
nextMode proto mode : byte
importSingleSong proto lpstrAddr:dword,fileOffset:dword
checkSongNameSuffix proto nameAddr:dword,nameLength:dword
checkSongName proto nameAddr:dword,nameLength:dword
checkRepeatedSongName proto nameAddr:dword
deleteSong proto dialogHandle:dword,deleteSongIndex:dword
deleteSingleSong proto dialogHandle:dword,deleteSongIndex:dword
chooseBatchPath proto dialogHandle:dword
batchImportSongs proto dialogHandle:dword,folderPathAddr:dword
readLrcFile proto dialogHandle:dword, index:dword
displayLyric proto dialogHandle:dword
changeLycState proto dialogHandle:dword
firstPlay proto dialogHandle:dword
displayJustImportedSong proto dialogHandle:dword,songNameAddr:dword 

;the struct of the song
songStructure STRUCT
	songName BYTE 1000 DUP(0)
	songPath BYTE 1000 DUP(0)
songStructure ends

; the struct of lyrics
Lyric STRUCT
	sentence byte 100 dup(0)
	time dword 0
Lyric ends

.const
; sequence id for the ui
IDD_MAIN EQU 101
IDD_LIST EQU 123
IDC_PLAY EQU 1004
IDC_LOCAL EQU 1005
IDC_SONG_LIST EQU 1007
IDC_PROGRESS EQU 1008
IDC_PROSHOW EQU 1111
IDC_PLAY_FOCUSED EQU 1009
IDC_IMPORT EQU 1010
IDC_DELETE EQU 1011
IDC_LIST1 EQU 1007
IDC_PRE EQU 1010
IDC_NEXT EQU 1011
IDC_VOLBUTTON EQU 1013
IDC_VOLUME EQU 1020
IDC_VOLSHOW EQU 1021
IDC_NAMESHOW EQU 1014
IDC_PLAYMODE EQU 1015
IDC_PATH_TIP EQU 1015
IDC_PATH_EDITOR EQU 1016
IDC_BATCH_IMPORT EQU 1012
IDC_PATH EQU 1017
IDC_Lyric EQU 1016
IDC_LYRICBUTTON EQU 1017

IDI_PLAY EQU 119
IDI_PAUSE EQU 122
IDI_MUTE EQU 131
IDI_LOW EQU 127 
IDI_MID EQU 130
IDI_LOUD EQU 126
IDI_LIST EQU 132
IDI_RANDOM EQU 133
IDI_SINGLE EQU 134
IDI_LYRIC EQU 135

; state of the play button
_PAUSE EQU 0
_PLAY EQU 1
_BEGIN EQU 2

; type of volume icon
_MUTE EQU 0
_LOW EQU 1
_MID EQU 2
_LOUD EQU 3

; state of play mode
_LIST EQU 0
_SINGLE EQU 1
_RANDOM EQU 2

; const parm of the icon
ICON_HEIGHT EQU 32
ICON_WIDTH EQU 32

.data
; states of the button
playButtonState byte 0

; state of the play mode
playMode byte 0

;song list
songList songStructure 300 dup(<"0", "0">)

;total number of current songs 
currentTotalSongNumber dword 0

;current song index
currentSongIndex dword 0

;temporarily store the focused song index used to double click to play
tempSongIndex dword 500
focusedSongIndex dword 500

;used to init the memory temporarily storing the song name 
blankSongName BYTE 1000 DUP(0)

;judge there is a song focused or not
hasFocuseSong dword 0

;temporarily store the filename
tempName BYTE 1000 dup(0)
tempName2 BYTE 1000 dup(0)

;open the file dialog
fileDialog OPENFILENAME<>
lpstrFileNames BYTE 8000 DUP(0)
tempPath BYTE 1000 DUP(0)

;open the folder dialog
folderDialog BROWSEINFO<>
lpstrFolderNames BYTE 8000 DUP(0)
importFolderPath BYTE 8000 DUP(0)

;used to traverse all files under the selected folder
findFileData WIN32_FIND_DATA<>
catString BYTE "\",0
folderSuffix BYTE "\*",0
firstPath BYTE "D:\zfh\AssemblyProject\hw1\\*",0			;testMsg

;used to get current path(which .exe file in)
szFileName byte 8000 dup(0)
scName byte "initMusic",0

; mci command
getPositionCommand byte "status currentSong position", 0	
setPositionCommand byte "seek currentSong to %d", 0			
playSongCommand byte "play currentSong", 0					
pauseSongCommand byte "pause currentSong",0					
resumeSongCommand byte "resume currentSong",0				
getLengthCommand byte "status currentSong length", 0		
openSongCommand byte 'open "%s" alias currentSong type mpegvideo',0
closeSongCommand byte "close currentSong",0  
adjustVolumeCommand byte "setaudio currentSong volume to %d",0

; value
isDraggingProgressBar dword 0		
currentSlider dword ?				
timeScale dword 1000				
timeScaleSec dword 60				
timeMinutePosition dword 0			
timeSecondPosition dword 0			
timeMinuteLength dword 0			
timeSecondLength dword 0			
timeShow byte "%02d:%02d/%02d:%02d", 0		
songPosition byte 32 dup(0)			
songLength byte 32 dup(0)	
int2str byte '%d',0
volumeSize dword 100
hasSound byte 1
currentVol dword ?

; lyrics
lyricArray Lyric 500 dup(<>)
lyricLines dword 0
	
lyricAddrs dword 1000 dup(0)
lyricTimes dword 1000 dup(0)
currentLyricIndex dword 0
maxLyricIndex dword 0
	
hasLyric byte 0
lyricVisible dword 1
lyricEmpty byte 0

lyricNextSentence byte "[", 0
noLyricText byte "壙涙梧簡",0
longStr byte 1000 dup(0)
lrcSuffix byte ".lrc", 0
point byte ".", 0
lrcBuffer byte 100000 dup(0)
lrcFile byte 1000 dup(0)
actualReadBytes dword 0
lyricPreparation byte "，，，，，，",0

;handle of main dialog
mainHandle dword 0
listHandle dword 0

;whether the list dialog is firstly inited
listFirstInit dword 0

;test message
ansMsg BYTE "%d"
changeRowMsg BYTE 0ah, 0dh, 0
strMsg BYTE "%s"

.data?
; the handle of the exec file itself
hInstance HINSTANCE ?
mediaCommand byte ?		;mciSendString
hIn HINSTANCE ?