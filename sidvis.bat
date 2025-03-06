@echo off
call sidvis-set.bat
setlocal enabledelayedexpansion


:: SET QUIET LEVEL

if !quiet! geq 1 (set "echo_q=") else (set "echo_q=echo on")
if !quiet! geq 2 (set "ffmpeg_q=ffmpeg -hide_banner -loglevel error") else (set "ffmpeg_q=ffmpeg")
if !quiet! geq 3 (set "sidplayfp_q=sidplayfp -q2") else (set "sidplayfp_q=sidplayfp -v")

!echo_q!


cd !sidplayfp_dir!


:: GET RECORD TIME

for /f "tokens=1,2 delims=: " %%X in ("!record_mm_ss!") do (set /a "sec=(60*(1%%X-100))+(1%%Y-100)")

if "!add_hvsc_time!" == "1" (
	set "hvsc_sid_path=!sid_file_path:%hvsc_dir%=!"
	for /f "delims=: eol=" %%N in ('findstr /inc:"!hvsc_sid_path:\=/!" !hvsc_dir!\DOCUMENTS\Songlengths.md5') do (set /a "index_target=%%N/2")
    set "index_count=1"
	echo off
	for /f "tokens=2 delims==" %%L in (!hvsc_dir!\DOCUMENTS\Songlengths.md5) do (
		if "!index_count!" == "!index_target!" (
			for /f "tokens=%track_number%" %%T in ("%%L") do (
				for /f "tokens=1-3 delims=:. " %%X in ("%%T") do (
					set /a "sl_sec=(60*%%X)+(1%%Y-100)"
					set "decimals=%%Z"
					goto :exit_index_count
				)
			)
		) else (set /a "index_count+=1")
	)
)
:exit_index_count
!echo_q!
if "!decimals!" == "" (set "tenth=0") else (set "tenth=!decimals:~0,1!")
if !tenth! geq 5 (set /a "rec_time=sl_sec+1+sec") else (set /a "rec_time=sl_sec+sec")

if "!add_hvsc_time!" == "0" (set "rec_time=!sec!")


:: GET CLOCK

if "!clock:~0,1!" == "a" (
	for /f "tokens=5 delims= " %%C in ('sidplayfp -v -t0 --none "!sid_file_path!" 2^>^&1 ^|find /i "Song Speed"') do (
		if "%%C" == "NTSC" (set "rec_clock=-vnf") else (set "rec_clock=-vpf")
	)
) else (set "rec_clock=-v!clock:~0,1!f")


:: GET SID MODEL

if "!sid_model:~0,1!" == "a" (
	for /f "tokens=7 delims= " %%M in ('sidplayfp -v -t0 --none "!sid_file_path!" 2^>^&1 ^|find /i "SID Details"') do (
		if "%%M" == "MOS6581" (set "rec_model=-mof -cwa") else (set "rec_model=-mnf -cww")
	)
) else (if "!sid_model:~0,1!" == "6" (set "rec_model=-mof -cwa") else (set "rec_model=-mnf -cww"))

if "!sid_model:~0,1!" == "d" (set "digiboost=--digiboost") else (set "digiboost=")


:: RECORDING SETUP

if "!rec_model!" == "mof" (set "rec_filter_curve=!filter_curve_6581!") else (set "rec_filter_curve=0.5")

set "common_set=-ols!track_number! -t!rec_time! --delay=!start_delay_cycles! !rec_clock! !rec_model! !digiboost! --fcurve=!rec_filter_curve! --frange=!filter_range_6581! -f192000"

set "mute_set=-u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9"

set "chn=3"
for /f "tokens=3" %%N in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "2nd SID"') do (if "%%N" == "2nd" (set "chn=6"))
for /f "tokens=3" %%N in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "3rd SID"') do (if "%%N" == "3rd" (set "chn=9"))


:: RECORD MASTER AUDIO

if "!ma_record!" == "1" (!sidplayfp_q! !common_set! -rr -!ma_pan:~0,1! --wav"!ffmpeg_dir!\sv_ma.wav" "!sid_file_path!")


:: RECORD SPLIT CHANNELS

if "!os_record!" == "1" (set "no_os=0") else (set "no_os=1")

for /l %%X in (!no_os!,1,!xt_record!) do (

	set "nv=-g1 -g2 -g3"
	set "tw="
	set "nf="

	if "%%X" == "0" (
	
		set "rn=0"
		
		if "!os_d418_digi!" == "1" (!sidplayfp_q! !mute_set! !common_set! -ri -m --wav"!ffmpeg_dir!\sv_dd.wav" "!sid_file_path!") else (set "nv=")
		
	) else (
	
		set "rn=4"

		if "!xt_triggerwaves!" == "1" (
			set /a "rn+=2"
			set "tw=-tw"
		)
	
		if "!xt_no_filter!" == "1" (
			set /a "rn+=1"
			set "nf=-nf"
		)

	)
	
	for /l %%C in (0,1,!chn!) do (!sidplayfp_q! !mute_set:-u%%C=! !nv! !tw! !nf! !common_set! -ri -m --wav"!ffmpeg_dir!\sv_%%C_!rn!.wav" "!sid_file_path!")

)


cd !ffmpeg_dir!


:: MASTER AUDIO - REMOVE START SILENCE, HIGH-PASS, RESAMPLE, FADE IN

if exist "sv_ma.wav" (
	
	if "!rec_clock!" == "vnf" (set "ma_sync_rate=192008") else (set "ma_sync_rate=192045")
	
	!ffmpeg_q! -i "sv_ma.wav" ^
	-filter_complex "[0:a]silenceremove=start_periods=1,highpass=f=2:p=1,asetrate=!ma_sync_rate!,aresample=192000:resampler=soxr,afade=t=in:ns=!fadein_samples![ma_srm_hpf_res_fdi]" ^
	-map "[ma_srm_hpf_res_fdi]" "sv_ma_srm_hpf_res_fdi.wav"
	
)


:: SPLIT CHANNELS - REMOVE START SILENCE, CANCEL DC, ADD TO CONCAT LIST

for /l %%C in (1,1,!chn!) do (
	for /l %%R in (0,1,7) do (
		if exist "sv_%%C_%%R.wav" (
			
			!ffmpeg_q! -i "sv_0_%%R.wav" -i "sv_%%C_%%R.wav" ^
			-filter_complex "[0:a]silenceremove=start_periods=1,aeval=-val(0):c=same[0_%%R_srm_inv];[1:a]silenceremove=start_periods=1,[0_%%R_srm_inv]amix=normalize=0[%%C_%%R_srm_0dc]" ^
			-map "[%%C_%%R_srm_0dc]" "sv_%%C_%%R_srm_0dc.wav"
	
			echo file 'sv_%%C_%%R_srm_0dc.wav' >> sv_cct_%%R_srm_0dc.txt
			
		)
	)
)


:: D418 DIGI - REMOVE START SILENCE, CANCEL DC, GET NORMALIZATION REF

if exist "sv_dd.wav"  (

	for /f "tokens=6 delims=- " %%A in ('ffmpeg -i "sv_dd.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
		!ffmpeg_q! -y -i "sv_dd.wav" -filter_complex "[0:a]silenceremove=start_periods=1,dcshift=%%A[dd_srm_0dc]" -map "[dd_srm_0dc]" "sv_dd_srm_0dc.wav"
	)
	
	!ffmpeg_q! -i "sv_dd_srm_0dc.wav" -filter_complex "[0:a]atrim=start_sample=!fadein_samples![dd_srm_0dc_nrf]" -map "[dd_srm_0dc_nrf]" "sv_dd_srm_0dc_nrf.wav"
	echo file 'sv_dd_srm_0dc_nrf.wav' >> sv_cct_0_srm_0dc.txt
		
)


:: GET TIMES IN SAMPLES

if not "!os_record!!xt_record!" == "00" (set "time_ref=sv_1_!rn!_srm_0dc.wav") else (set "time_ref=sv_ma_srm_hpf_res_fdi.wav")

for /f "tokens=2 delims=@" %%L in ('ffmpeg -i "!time_ref!" -af "volumedetect" -f null nul 2^>^&1 ^|find "n_samples"') do (
	for /f "tokens=3" %%S in ("%%L") do (
	
		if "!time_ref!" == "sv_ma_srm_hpf_res_fdi.wav" (
			if "!ma_pan:~0,1!" == "s" (set /a "samples_x1=%%S/2") else (set "samples_x1=%%S")
		) else (
			for /l %%C in (1,1,!chn!) do (set /a "samples_x%%C=%%S*%%C")
		)

	)
)


:: SPLIT CHANNELS - CONCAT, NORMALIZE, UNCONCAT, FADEOUT, OUTPUT

set /a "fadeout_samples=fadeout_seconds*192000"
set /a "fadeout_start_sample=samples_x1-fadeout_samples"
if !fadeout_start_sample! lss 0 (set fadeout_start_sample=0)
if !fadeout_seconds! geq 1 (set "fadeout=afade=t=out:ss=!fadeout_start_sample!:ns=!fadeout_samples!:curve=cub") else (set "fadeout=anull")

set ot=0!track_number!
for %%F in ("!sid_file_path!") do (set "prefix=!wav_dir!\%%~nF_T!ot:~-2!")

for /l %%R in (0,1,7) do (
	if exist "sv_cct_%%R_srm_0dc.txt" (
	
		if "%%R" == "0" (set "suffix=OS")
		if "%%R" == "4" (set "suffix=XT")
		if "%%R" == "5" (set "suffix=XT_NF")
		if "%%R" == "6" (set "suffix=XT_TW")
		if "%%R" == "7" (set "suffix=XT_TW_NF")
		
		!ffmpeg_q! -f concat -safe 0 -i "sv_cct_%%R_srm_0dc.txt" -c copy "sv_cct_%%R_srm_0dc.wav"
		for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_cct_%%R_srm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
			
			for /l %%C in (1,1,!chn!) do (
			
				set /a "samples_xprev=samples_x%%C-samples_x1"
		
				!ffmpeg_q! -i "sv_cct_%%R_srm_0dc.wav" ^
				-filter_complex "[0:a]atrim=start_sample=!samples_xprev!:end_sample=!samples_x%%C!,volume=%%VdB,asetpts=PTS-STARTPTS,!fadeout![%%C_%%R_srm_0dc_nrm_fdo]" ^
				-map "[%%C_%%R_srm_0dc_nrm_fdo]" "!prefix!_!suffix!_0%%C.wav"
		
			)
				
			if "!os_record!!os_d418_digi!%%R" == "110" (
				!ffmpeg_q! -i "sv_dd_srm_0dc.wav" -filter_complex "[0:a]volume=%%VdB,!fadeout![dd_srm_0dc_nrm_fdo]" -map "[dd_srm_0dc_nrm_fdo]" "!prefix!_OS_DD.wav"
			)

		)
	)
)


:: MASTER AUDIO - MATCH TIME, NORMALIZE, FADEOUT, OUTPUT

if exist "sv_ma_srm_hpf_res_fdi.wav" (
	for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_ma_srm_hpf_res_fdi.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	
		!ffmpeg_q! -i "sv_ma_srm_hpf_res_fdi.wav" ^
		-filter_complex "[0:a]apad=whole_len=!samples_x1!,atrim=end_sample=!samples_x1!,volume=%%VdB,!fadeout![ma_srm_hpf_res_fdi_mat_nrm_fdo]" ^
		-map "[ma_srm_hpf_res_fdi_mat_nrm_fdo]" "!prefix!_MA.wav"
		
	)
)


:: FINISH

echo Done.
pause

if "!del_ffmpeg_files!" == "1" del "sv_*"