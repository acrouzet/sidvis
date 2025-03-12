@echo off
call sidvis-set.bat
setlocal enabledelayedexpansion

:: DEBUG SETTINGS

set quiet=3
set del_ffmpeg_files=1


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
	for /f "tokens=5 delims= " %%C in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "Song Speed"') do (
		if "%%C" == "NTSC" (set "rec_clock=-vnf") else (set "rec_clock=-vpf")
	)
) else (
	set "rec_clock=-v!clock:~0,1!f"
)


:: GET SID MODEL

if "!sid_model:~0,1!" == "d" (set "digiboost=--digiboost") else (set "digiboost=")

if "!sid_model:~0,1!" == "a" (
	for /f "tokens=7 delims= " %%M in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "SID Details"') do (if "%%M" == "MOS6581" (set "is6581=1"))
) else (
	if "!sid_model:~0,1!" == "6" (set "is6581=1"))

if "!is6581!" == "1" (set "rec_model=-mof --fcurve=!filter_curve_6581!") else (set "rec_model=-mnf --fcurve=0.5")


:: COMBINE COMMON SETTINGS

set "com_set=-ols!track_number! -t!rec_time! --delay=!start_delay_cycles! !rec_clock! !digiboost! !rec_model! --frange=!filter_range_6581! -cw!combined_waves:~0,1! -f192000"


:: RECORD MASTER AUDIO

if "!ma_enable!" == "1" (!sidplayfp_q! !com_set! -rr -!pan:~0,1! --wav"!ffmpeg_dir!\sv_ma.wav" "!sid_file_path!")


:: GET TOTAL CHANNEL NUMBER

if "!os_enable!!regularwaves_filtered_channels!!regularwaves_nofilter_channels!!triggerwaves_filtered_channels!!triggerwaves_nofilter_channels!" == "00000" (
	set "ma_only=1"
) else (
	set "total_chn=3"
	for /f "tokens=3" %%N in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "2nd SID"') do (if "%%N" == "2nd" (set "total_chn=6"))
	for /f "tokens=3" %%N in ('sidplayfp -v -t1 --none "!sid_file_path!" 2^>^&1 ^|find /i "3rd SID"') do (if "%%N" == "3rd" (set "total_chn=9"))
)


:: RECORD SPLIT CHANNELS

if not "!ma_only!" == "1" (

	set "mute_set=-u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9"

	for /l %%R in (0,1,4) do (

		set "tw_nf="
		set "nv=-g1 -g2 -g3"

		if "%%R" == "0" (set "chn_list=!regularwaves_filtered_channels!")

		if "%%R" == "1" (
			set "chn_list=!regularwaves_nofilter_channels!"
			set "tw_nf=-nf"
		)

		if "%%R" == "2" (
			set "chn_list=!triggerwaves_filtered_channels!"
			set "tw_nf=-tw"
		)

		if "%%R" == "3" (
			set "chn_list=!triggerwaves_nofilter_channels!"
			set "tw_nf=-tw -nf"
		)

		if "%%R" == "4" (
			if "!os_enable!" == "1" (
				set "chn_list=a"
				if "!d418_digi!" == "1" (!sidplayfp_q! !mute_set! !com_set! -ri -m --wav"!ffmpeg_dir!\sv_dd.wav" "!sid_file_path!") else (set "nv=")
			) else (
				set "chn_list=0"
			)
		)

		if "!chn_list:~0,1!" == "a" (set "chn_list=1,2,3,4,5,6,7,8,9")

		if not "!chn_list!" == "0" (
			for %%C in (0,!chn_list!) do (
				if %%C leq !total_chn! (!sidplayfp_q! !mute_set:-u%%C=! !tw_nf! !nv! !com_set! -ri -m --wav"!ffmpeg_dir!\sv_%%R_%%C.wav" "!sid_file_path!")
			)
		)

	)

)


cd !ffmpeg_dir!


:: MASTER AUDIO - START SILENCE REMOVE, HIGH-PASS, RESAMPLE, FADE IN

if exist "sv_ma.wav" (

	if "!rec_clock!" == "-vnf" (set "ma_sync_rate=192008") else (set "ma_sync_rate=192045")

	!ffmpeg_q! -i "sv_ma.wav" ^
	-filter_complex "[0:a]silenceremove=start_periods=1,highpass=f=2:p=1,asetrate=!ma_sync_rate!,aresample=192000:resampler=soxr,afade=t=in:ns=!fadein_samples![ma_srm_hpf_res_fdi]" ^
	-map "[ma_srm_hpf_res_fdi]" "sv_ma_srm_hpf_res_fdi.wav"

)


:: SPLIT CHANNELS - START SILENCE REMOVE, GET TIME REF, CANCEL DC, MAKE OS CONCAT LIST

for /l %%R in (0,1,4) do (
	if exist "sv_%%R_0.wav" (
		
		!ffmpeg_q! -i "sv_%%R_0.wav" ^
		-filter_complex "[0:a]silenceremove=start_periods=1,aeval=-val(0):c=same[%%R_0_srm_inv]" ^
		-map "[%%R_0_srm_inv]" "sv_%%R_0_srm_inv.wav"
		
		set "time_ref=sv_%%R_0_srm_inv.wav"
	
		for /l %%C in (1,1,!total_chn!) do (
			if exist "sv_%%R_%%C.wav" (
	
				!ffmpeg_q! -i "sv_%%R_%%C.wav" -i "sv_%%R_0_srm_inv.wav" ^
				-filter_complex "[0:a]silenceremove=start_periods=1,[1:a]amix=normalize=0[%%R_%%C_srm_0dc]" ^
				-map "[%%R_%%C_srm_0dc]" "sv_%%R_%%C_srm_0dc.wav"

				if "%%R" == "4" (echo file 'sv_4_%%C_srm_0dc.wav' >> sv_4_cct_srm_0dc.txt)

			)
		)

	)
)


:: D418 DIGI - REMOVE START SILENCE, CANCEL DC, GET NORMALIZATION REF

if exist "sv_dd.wav"  (

	for /f "tokens=6 delims=- " %%A in ('ffmpeg -i "sv_dd.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
	
		!ffmpeg_q! -y -i "sv_dd.wav" ^
		-filter_complex "[0:a]silenceremove=start_periods=1,dcshift=%%A[dd_srm_0dc]" ^
		-map "[dd_srm_0dc]" "sv_dd_srm_0dc.wav"

	)

	!ffmpeg_q! -i "sv_dd_srm_0dc.wav" ^
	-filter_complex "[0:a]atrim=start_sample=!fadein_samples![dd_srm_0dc_nrf]" ^
	-map "[dd_srm_0dc_nrf]" "sv_dd_srm_0dc_nrf.wav"

	echo file 'sv_dd_srm_0dc_nrf.wav' >> sv_4_cct_srm_0dc.txt

)


:: GET TIMES IN SAMPLES

if "!ma_only!" == "1" (set "time_ref=sv_ma_srm_hpf_res_fdi.wav")

for /f "tokens=2 delims=@" %%L in ('ffmpeg -i "!time_ref!" -af "volumedetect" -f null nul 2^>^&1 ^|find "n_samples"') do (
	for /f "tokens=3" %%S in ("%%L") do (
	
		if "!ma_only!" == "1" (
			if "!pan:~0,1!" == "s" (set /a "samples_x1=%%S/2") else (set "samples_x1=%%S")
		) else (
			if exist "sv_4_cct_srm_0dc.txt" (for /l %%C in (1,1,!total_chn!) do (set /a "samples_x%%C=%%S*%%C"))
		)

	)
)


:: GET FADEOUT

if not "!ma_enable!!os_enable!" == "00" (

	set /a "fadeout_samples=fadeout_seconds*192000"

	set /a "fadeout_start_sample=samples_x1-fadeout_samples"
	if !fadeout_start_sample! lss 0 (set fadeout_start_sample=0)

	if !fadeout_seconds! geq 1 (set "fadeout=afade=t=out:ss=!fadeout_start_sample!:ns=!fadeout_samples!:curve=cub") else (set "fadeout=anull")
	
)


:: GET OUTPUT FILENAME PREFIX

set ot=0!track_number!
for %%F in ("!sid_file_path!") do (set "prefix=!wav_dir!\%%~nF_T!ot:~-2!")


:: SPLIT CHANNELS - NORMALIZE, FADEOUT OS, OUTPUT

for /l %%R in (0,1,4) do (
	if exist "sv_%%R_0.wav" (

		if "%%R" == "4" (
			
			!ffmpeg_q! -f concat -safe 0 -i "sv_4_cct_srm_0dc.txt" -c copy "sv_4_cct_srm_0dc.wav"
			for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_4_cct_srm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (

				for /l %%C in (1,1,!total_chn!) do (
				
					set /a "samples_xprev=samples_x%%C-samples_x1"

					!ffmpeg_q! -i "sv_4_cct_srm_0dc.wav" ^
					-filter_complex "[0:a]atrim=start_sample=!samples_xprev!:end_sample=!samples_x%%C!,volume=%%VdB,asetpts=PTS-STARTPTS,!fadeout![4_%%C_srm_0dc_nrm_fdo]" ^
					-map "[4_%%C_srm_0dc_nrm_fdo]" "!prefix!_OS_C%%C.wav"
				
				)
				
				if exist "sv_dd_srm_0dc.wav" (
				
					!ffmpeg_q! -i "sv_dd_srm_0dc.wav" ^
					-filter_complex "[0:a]volume=%%VdB,!fadeout![dd_srm_0dc_nrm_fdo]" ^
					-map "[dd_srm_0dc_nrm_fdo]" "!prefix!_OS_DD.wav"
		
				)
			
			)
			
		) else (
			
			if "%%R" == "0" (set "suffix=RW_FI")
			if "%%R" == "1" (set "suffix=RW_NF")
			if "%%R" == "2" (set "suffix=TW_FI")
			if "%%R" == "3" (set "suffix=TW_NF")
	
			for /l %%C in (1,1,!total_chn!) do (
				if exist "sv_%%R_%%C_srm_0dc.wav" (
					for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_%%R_%%C_srm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
					
						!ffmpeg_q! -i "sv_%%R_%%C_srm_0dc.wav" ^
						-filter_complex "[0:a]volume=%%VdB[%%R_%%C_srm_0dc_nrm]" ^
						-map "[%%R_%%C_srm_0dc_nrm]" "!prefix!_XT_!suffix!_C%%C.wav"
	
					)
				)
			)
		
		)

	)
)


:: MASTER AUDIO - SYNC, NORMALIZE, FADEOUT, OUTPUT

if exist "sv_ma_srm_hpf_res_fdi.wav" (
	for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_ma_srm_hpf_res_fdi.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (

		!ffmpeg_q! -i "sv_ma_srm_hpf_res_fdi.wav" ^
		-filter_complex "[0:a]apad=whole_len=!samples_x1!,atrim=end_sample=!samples_x1!,volume=%%VdB,!fadeout![ma_srm_hpf_res_fdi_snc_nrm_fdo]" ^
		-map "[ma_srm_hpf_res_fdi_snc_nrm_fdo]" "!prefix!_MA.wav"

	)
)


:: FINISH

echo Done.
pause

if "!del_ffmpeg_files!" == "1" (del "sv_*")