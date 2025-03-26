:: [INITIALIZATION]

@echo off
call sidvis-set.bat
setlocal enabledelayedexpansion


:: Debug Settings

set quiet=3
set rec=1
set keep_svtemp=0

if !quiet! geq 1 (set "echo_q=") else (set "echo_q=echo on")
if !quiet! geq 2 (set "ffmpeg_q=ffmpeg -y -hide_banner -loglevel error") else (set "ffmpeg_q=ffmpeg -y")
if !quiet! geq 3 (set "sidplayfp_q=sidplayfp -q2") else (set "sidplayfp_q=sidplayfp -v")

!echo_q!


:: Checks & Messages

if exist "!ffmpeg_dir!\svtemp" (
	choice /c DX /n /m "Temporary work folder '!ffmpeg_dir!\svtemp' already exists. Press [D] to delete it or [X] to exit."
	if "!errorlevel!" == "1" (rd /s /q "!ffmpeg_dir!\svtemp")
	if "!errorlevel!" == "2" (exit /b)
)


:: [SIDPLAYFP RECORDING]

md "!ffmpeg_dir!\svtemp"

cd !sidplayfp_dir!


:: Get Record Time

for /f "tokens=1,2 delims=: " %%X in ("!record_mm_ss!") do (set /a "sec=(60*(1%%X-100))+(1%%Y-100)")

if "!add_hvsc_time!" == "0" (set "rec_time=!sec!")

if "!add_hvsc_time!" == "1" (
	set "hvsc_sid_path=!sid_file_path:%hvsc_dir%=!"
	for /f "delims=: eol=" %%N in ('findstr /inc:"!hvsc_sid_path:\=/!" !hvsc_dir!\DOCUMENTS\Songlengths.md5') do (set /a "index_target=%%N/2")
    set "index_count=1"
	echo off
	for /f "tokens=2 delims==" %%L in (!hvsc_dir!\DOCUMENTS\Songlengths.md5) do (
		if "!index_count!" == "!index_target!" (
			for /f "tokens=%track_number%" %%T in ("%%L") do (for /f "tokens=1-3 delims=:. " %%X in ("%%T") do (
				set /a "sl_sec=(60*%%X)+(1%%Y-100)"
				set "decimals=%%Z"
				goto :exit_index_count
			))
		) else (set /a "index_count+=1")
	)
)
:exit_index_count
!echo_q!
if "!decimals!" == "" (set "tenth=0") else (set "tenth=!decimals:~0,1!")
if !tenth! geq 5 (set /a "rec_time=sl_sec+1+sec") else (set /a "rec_time=sl_sec+sec")


:: Get Clock

if "!clock:~0,1!" == "a" (
	for /f "tokens=5 delims= " %%C in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "Song Speed"') do (
		if "%%C" == "NTSC" (set "rec_clock=-vnf") else (set "rec_clock=-vpf")
	)
) else (set "rec_clock=-v!clock:~0,1!f")


:: Get SID Model

if "!sid_model:~0,1!" == "d" (set "digiboost=--digiboost") else (set "digiboost=")

if "!sid_model:~0,1!" == "a" (
	for /f "tokens=7 delims= " %%M in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "SID Details"') do (if "%%M" == "MOS6581" (set "is6581=1"))
) else (if "!sid_model:~0,1!" == "6" (set "is6581=1"))

if "!is6581!" == "1" (set "rec_model=-mof --fcurve=!filter_curve_6581!") else (set "rec_model=-mnf --fcurve=0.5")


:: Combine Common Settings

set "coms=-f192000 -ols!track_number! -t!rec_time! --delay=!start_delay_cycles! !rec_clock! !digiboost! !rec_model! --frange=!filter_range_6581! -cw!combined_waves:~0,1!"


:: Record Master Audio

if "!rec!!MA_enable!" == "11" (!sidplayfp_q! !coms! -rr -!pan:~0,1! --wav"!ffmpeg_dir!\svtemp\MA.wav" "!sid_file_path!")


:: Get Total Channel Number

set "total_chn=3"
for /f "tokens=3" %%N in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "2nd SID"') do (if "%%N" == "2nd" (set "total_chn=6"))
for /f "tokens=3" %%N in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "3rd SID"') do (if "%%N" == "3rd" (set "total_chn=9"))


:: Record On-Screens

set "OS_coms=!coms! -ri -m -u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9"

if "!rec!!OS_enable!" == "11" (

	if "!D418_digi!" == "1" (
		!sidplayfp_q! !OS_coms! -nf --wav"!ffmpeg_dir!\svtemp\OS_CD.wav" "!sid_file_path!"
		set "OS_gs=-g1 -g2 -g3"
	) else (set "OS_gs=")

	for /l %%C in (0,1,9) do (if %%C leq !total_chn! (!sidplayfp_q! !OS_coms:-u%%C=! !OS_gs! --wav"!ffmpeg_dir!\svtemp\OS_C%%C.wav" "!sid_file_path!"))

)


:: Record External Triggers

if "!FIltered-RegularWaves_Channels!!FIltered-TriggerWaves_Channels!!NoFilter-RegularWaves_Channels!!NoFilter-TriggerWaves_Channels!" == "0000" (set "XT_enable=0")

if "!rec!!XT_enable!" == "11" (for %%R in (FIltered-RegularWaves,FIltered-TriggerWaves,NoFilter-RegularWaves,NoFilter-TriggerWaves) do (if not "!%%R_Channels!" == "0" (

	if "!%%R_Channels:~0,1!" == "a" (set "%%R_Channels=1,2,3,4,5,6,7,8,9")

	if "%%R" == "FIltered-RegularWaves" (set "shR=FI-RW")
	if "%%R" == "FIltered-TriggerWaves" (set "shR=FI-TW")
	if "%%R" == "NoFilter-RegularWaves" (set "shR=NF-RW")
	if "%%R" == "NoFilter-TriggerWaves" (set "shR=NF-TW")

	if "!shR!"              == "FI-RW"  (set "XT_dfs=") else (set "XT_dfs=-df1 -df2 -df3 -df4 -df5 -df6 -df7 -df8 -df9")
	if "!shR:~0,2!!is6581!" == "FI1"    (set "XT_nes=") else (set "XT_nes=-ne")
	if "!shR:~3,2!"         == "RW"     (set "XT_tws=") else (set "XT_tws=-tw")

	set "XT_coms=!OS_coms! -g1 -g2 -g3 !XT_nes! !XT_tws!"

	for %%C in (0,!%%R_Channels!) do (if %%C leq !total_chn! (
		if "!shR!" == "FI-TW" (
			if not "%%C" == "0" (
				!sidplayfp_q! !XT_coms!        !XT_dfs:-df%%C=! --wav"!ffmpeg_dir!\svtemp\XT-!shR!_C0-F%%C.wav" "!sid_file_path!"
				!sidplayfp_q! !XT_coms:-u%%C=! !XT_dfs:-df%%C=! --wav"!ffmpeg_dir!\svtemp\XT-!shR!_C%%C.wav"    "!sid_file_path!"
			)
		) else (!sidplayfp_q! !XT_coms:-u%%C=! !XT_dfs!         --wav"!ffmpeg_dir!\svtemp\XT-!shR!_C%%C.wav"    "!sid_file_path!")
	))

)))


:: [FFMPEG PROCESSING]

cd !ffmpeg_dir!


:: Master Audio - Remove Start Silence, High-Pass, Speed Adjust, Fade-In

if exist "svtemp\MA.wav" (

	if "!rec_clock!" == "-vnf" (set "ma_sync_rate=192008") else (set "ma_sync_rate=192045")

	!ffmpeg_q! -i "svtemp\MA.wav" ^
	-af "silenceremove=start_periods=1,highpass=f=2:p=1,asetrate=!ma_sync_rate!,aresample=192000:resampler=soxr,afade=t=in:ns=!fadein_samples!" ^
	"svtemp\MA_srm-hpf-spd-fdi.wav"

)


:: On-Screens & External Triggers - Remove Start Silence, Cancel DC, Make On-Screens Concat List, Get Time Reference

for %%R in (OS,XT-FI-RW,XT-FI-TW,XT-NF-RW,XT-NF-TW) do (

	if exist "svtemp\%%R_C0.wav" (!ffmpeg_q! -i "svtemp\%%R_C0.wav" -af "silenceremove=start_periods=1,aeval=-val(0):c=same" "svtemp\%%R_C0_srm-inv.wav")

	for /l %%C in (1,1,!total_chn!) do (if exist "svtemp\%%R_C%%C.wav" (

		if "%%R" == "XT-FI-TW" (

			!ffmpeg_q! -i "svtemp\%%R_C0-F%%C.wav" -i "svtemp\%%R_C%%C.wav" ^
			-filter_complex "[0:a]silenceremove=start_periods=1,aeval=-val(0):c=same[0_srm-inv];[1:a]silenceremove=start_periods=1,[0_srm-inv]amix=normalize=0[o]" ^
			-map "[o]" "svtemp\%%R_C%%C_srm-0dc.wav"

		) else (

			!ffmpeg_q! -i "svtemp\%%R_C0_srm-inv.wav" -i "svtemp\%%R_C%%C.wav" ^
			-filter_complex "[1:a]silenceremove=start_periods=1,[0:a]amix=normalize=0[o]" ^
			-map "[o]" "svtemp\%%R_C%%C_srm-0dc.wav"

			if "%%R" == "OS" (echo file 'OS_C%%C_srm-0dc.wav' >> "svtemp\OS_CC_srm-0dc.txt")

		)

		set "time_ref=svtemp\%%R_C%%C_srm-0dc.wav"

	))

)


:: D418 Digi - Remove Start Silence, Cancel DC, Get Normalization Reference

if exist "svtemp\OS_CD.wav" (
	for /f "tokens=6 delims=- " %%A in ('ffmpeg -i "svtemp\OS_CD.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
		!ffmpeg_q! -i "svtemp\OS_CD.wav" -af "silenceremove=start_periods=1,dcshift=%%A" "svtemp\OS_CD_srm-0dc.wav"
		!ffmpeg_q! -i "svtemp\OS_CD_srm-0dc.wav" -af "atrim=start_sample=!fadein_samples!" "svtemp\OS_CD_srm-0dc-nrf.wav"
	)
	echo file 'OS_CD_srm-0dc-nrf.wav' >> "svtemp\OS_CC_srm-0dc.txt"
)


:: Get Times in Samples

if "!OS_enable!!XT_enable!" == "00" (set "time_ref=svtemp\MA_srm-hpf-spd-fdi.wav")

for /f "tokens=2 delims=@" %%L in ('ffmpeg -i "!time_ref!" -af "volumedetect" -f null nul 2^>^&1 ^|find "n_samples"') do (for /f "tokens=3" %%S in ("%%L") do (
	if "!time_ref!" == "svtemp\MA_srm-hpf-spd-fdi.wav" (
		if "!pan:~0,1!" == "s" (set /a "samples_x1=%%S/2") else (set "samples_x1=%%S")
	) else (for /l %%C in (1,1,!total_chn!) do (set /a "samples_x%%C=%%S*%%C"))
))


:: Get Fade-Out

set /a "fadeout_samples=fadeout_seconds*192000"

set /a "fadeout_start_sample=samples_x1-fadeout_samples"
if !fadeout_start_sample! lss 0 (set fadeout_start_sample=0)

if !fadeout_seconds! geq 1 (set "fadeout=afade=t=out:ss=!fadeout_start_sample!:ns=!fadeout_samples!:curve=cub") else (set "fadeout=anull")


:: Get Output Filename Prefix

set ot=0!track_number!
for %%F in ("!sid_file_path!") do (set "prefix=!wav_dir!\%%~nF_T!ot:~-2!")


:: On-Screens - Un-Concat, Normalize, Fade-Out, Output

if exist "svtemp\OS_CC_srm-0dc.txt" (
	!ffmpeg_q! -f concat -safe 0 -i "svtemp\OS_CC_srm-0dc.txt" -c copy "svtemp\OS_CC_srm-0dc.wav"
	for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "svtemp\OS_CC_srm-0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (

		for /l %%C in (1,1,!total_chn!) do (

			set /a "samples_xprev=samples_x%%C-samples_x1"

			!ffmpeg_q! -i "svtemp\OS_CC_srm-0dc.wav" ^
			-af "atrim=start_sample=!samples_xprev!:end_sample=!samples_x%%C!,volume=%%VdB,asetpts=PTS-STARTPTS,!fadeout!" ^
			"!prefix!_OS_C%%C.wav"

		)

		if exist "svtemp\OS_CD_srm-0dc-nrf.wav" (!ffmpeg_q! -i "svtemp\OS_CD_srm-0dc.wav" -af "volume=%%VdB,!fadeout!" "!prefix!_OS_CD.wav")

	)
)


:: External Triggers - Normalize & Output

for %%R in (FI-RW,FI-TW,NF-RW,NF-TW) do (for /l %%C in (1,1,!total_chn!) do (if exist "svtemp\XT-%%R_C%%C_srm-0dc.wav" (
	for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "svtemp\XT-%%R_C%%C_srm-0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
		!ffmpeg_q! -i "svtemp\XT-%%R_C%%C_srm-0dc.wav" -af "volume=%%VdB" "!prefix!_XT-%%R_C%%C.wav"
	)
)))


:: Master Audio - Pad/Trim, Normalize, Fade-Out, Output

if exist "svtemp\MA_srm-hpf-spd-fdi.wav" (
	for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "svtemp\MA_srm-hpf-spd-fdi.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
		!ffmpeg_q! -i "svtemp\MA_srm-hpf-spd-fdi.wav" -af "apad=whole_len=!samples_x1!,atrim=end_sample=!samples_x1!,volume=%%VdB,!fadeout!" "!prefix!_MA.wav"
	)
)


:: Finish

echo Done.
echo Press any key to exit.
pause >nul

if "!keep_svtemp!" == "0" (rd /s /q "!ffmpeg_dir!\svtemp")

exit /b