@echo off
call sidvis-set.bat
setlocal enabledelayedexpansion

if !quiet! geq 1 (set "echo_q=") else (set "echo_q=echo on")
if !quiet! geq 2 (set "ffmpeg_q=ffmpeg -hide_banner -loglevel error") else (set "ffmpeg_q=ffmpeg")
if !quiet! geq 3 (set "sidplayfp_q=sidplayfp -q2") else (set "sidplayfp_q=sidplayfp -v")

!echo_q!


cd !sidplayfp_path!


for /f "delims=: tokens=1,2" %%X in ("!time!") do (set /a "sec=(60*(1%%X-100))+(1%%Y-100)")


if "!use_hvsc!" == "1" (

	set "full_sid_path=!hvsc_path!\!sid_path!"

	for /f "delims=: eol=" %%N in ('findstr /inc:"!sid_path:\=/!" !hvsc_path!\DOCUMENTS\Songlengths.md5') do (set /a "index_target=%%N/2")
    set "index_count=1"
	for /f "delims== tokens=2" %%L in (!hvsc_path!\DOCUMENTS\Songlengths.md5) do (
		if "!index_count!" == "!index_target!" (
			for /f "tokens=%track%" %%T in ("%%L") do (
				for /f "delims=:. tokens=1-3" %%X in ("%%T") do (
					set /a "sl_mmss_sec=(60*%%X)+(1%%Y-100)"
					set "decimals=%%Z"
					goto :exit_index_count
				)
			)
		) else (set /a "index_count+=1")
	)
)
:exit_index_count
if "!decimals!" == "" (set "tenth=0") else (set "tenth=!decimals:~0,1!")
if !tenth! geq 5 (set /a "rec_time=sl_mmss_sec+1+sec") else (set /a "rec_time=sl_mmss_sec+sec")


if "!use_hvsc!" == "0" (

	set "full_sid_path=!sid_path!"
	
	set "rec_time=!sec!"
)


if /i "!clock:~0,1!" == "a" (
	for /f "tokens=5 delims= " %%C in ('sidplayfp -v -t0 --none "!full_sid_path!" 2^>^&1 ^|find /i "Song Speed"') do (
		if /i "%%C" == "NTSC" (set "rec_clock=vnf") else (set "rec_clock=vpf")
	)
) else (set "rec_clock=v!clock:~0,1!f")


if /i "!sid_model:~0,1!" == "a" (
	for /f "tokens=7 delims= " %%M in ('sidplayfp -v -t0 --none "!full_sid_path!" 2^>^&1 ^|find /i "SID Details"') do (
		if /i "%%M" == "MOS6581" (set "rec_model=mof") else (set "rec_model=mnf")
	)
) else (
	if "!sid_model:~0,1!" == "6" (set "rec_model=mof") else (set "rec_model=mnf")
)
if /i "!sid_model:~0,1!" == "d" (set "digiboost=--digiboost") else (set "digiboost=")

if /i "!rec_model!" == "mof" (set "rec_filter_curve=!filter_curve_6581!") else (set "rec_filter_curve=0.5")


set "common_set=-ols!track! -t!rec_time! --delay=!delay! -!rec_clock! -!rec_model! !digiboost! --fcurve=!rec_filter_curve! --frange=!filter_range_6581! -cw!combined_waves:~0,1! -f192000"

set "mute_set=-u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9"

set "chn=3"
for /f "tokens=3" %%2 in ('sidplayfp -v -t1 --none "!full_sid_path!" 2^>^&1 ^|find /i "2nd SID"') do (if /i "%%2" == "2nd" set "chn=6")
for /f "tokens=3" %%3 in ('sidplayfp -v -t1 --none "!full_sid_path!" 2^>^&1 ^|find /i "3rd SID"') do (if /i "%%3" == "3rd" set "chn=9")


if /i not "!record_mode:~0,1!" == "t" (

	for /l %%N in (0,1,!chn!) do (

		for /l %%E in (0,1,1) do (
			if "%%E" == "1" (set "tw=-tw%%N") else (set "tw=")
		
			for /l %%D in (0,1,1) do (
				if "%%D" == "1" (set "nf=-nf") else (set "nf=")
			
				if /i "%%E%%D!record_mode:~0,1!" == "00n" (set "g=") else (set "g=-g1 -g2 -g3")
			
				!sidplayfp_q! !mute_set:-u%%N=! !tw! !nf! !g! !common_set! -ri -m --wav"!ffmpeg_path!\sv_%%N_tw%%E_nf%%D.wav" "!full_sid_path!"
			)
		)
	)
)

!sidplayfp_q! !common_set! -rr -!pan:~0,1! --wav"!ffmpeg_path!\sv_a.wav" "!full_sid_path!"

if /i "!record_mode:~0,1!" == "v" (!sidplayfp_q! !mute_set! -nf !common_set! -ri -m --wav"!ffmpeg_path!\sv_v.wav" "!full_sid_path!")


cd !ffmpeg_path!


set "trim=silenceremove=start_periods=1"

if /i "!rec_clock!" == "vnf" (set "a_match_rate=192008") else (set "a_match_rate=192045")


!ffmpeg_q! -i "sv_a.wav" ^
-filter_complex "[0:a]!trim!,highpass=f=2:p=1,asetrate=!a_match_rate!,aresample=192000:resampler=soxr,afade=t=in:ns=!fadein_samples![a_trm_hpf_rsm_fdi]" ^
-map "[a_trm_hpf_rsm_fdi]" "sv_a_trm_hpf_rsm_fdi.wav"

if /i "!record_mode:~0,1!" == "v" (
	for /f "tokens=6 delims=- " %%A in ('ffmpeg -i "sv_v.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
		!ffmpeg_q! -y -i "sv_v.wav" -filter_complex "[0:a]!trim!,dcshift=%%A[v_trm_0dc]" -map "[v_trm_0dc]" "sv_v_trm_0dc.wav"
	)
)


set "invert=aeval='-val(0)':c=same"

set "mix=amix=normalize=0"


if /i not "!record_mode:~0,1!" == "t" (

	for /l %%N in (1,1,!chn!) do (
		for /l %%E in (0,1,1) do (
			for /l %%D in (0,1,1) do (
			
				!ffmpeg_q! -i "sv_0_tw%%E_nf%%D.wav" -i "sv_%%N_tw%%E_nf%%D.wav" ^
				-filter_complex "[0:a]!trim!,!invert![0_tw%%E_nf%%D_trm_inv];[1:a]!trim!,[0_tw%%E_nf%%D_trm_inv]!mix![%%N_tw%%E_nf%%D_trm_0dc]" ^
				-map "[%%N_tw%%E_nf%%D_trm_0dc]" "sv_%%N_tw%%E_nf%%D_trm_0dc.wav"
	
				echo file 'sv_%%N_tw%%E_nf%%D_trm_0dc.wav' >> sv_cct_tw%%E_nf%%D_trm_0dc.txt

			)
		)
	)

	if /i "!record_mode:~0,1!" == "v" (
	
		!ffmpeg_q! -i "sv_v_trm_0dc.wav" -filter_complex "[0:a]atrim=start_sample=!fadein_samples![v_trm_0dc_nrf]" -map "[v_trm_0dc_nrf]" "sv_v_trm_0dc_nrf.wav"
		
		echo file 'sv_v_trm_0dc_nrf.wav' >> sv_cct_tw0_nf0_trm_0dc.txt
		
	)

	for /f "tokens=2 delims=@" %%L in ('ffmpeg -i "sv_1_tw0_nf0_trm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "n_samples"') do (
		for /f "tokens=3" %%S in ("%%L") do (
			for /l %%N in (1,1,!chn!) do (set /a "samples_x%%N=%%S*%%N")
		)
	)
) else (
	for /f "tokens=2 delims=@" %%L in ('ffmpeg -i "sv_a_trm_hpf_rsm_fdi.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "n_samples"') do (
		for /f "tokens=3" %%S in ("%%L") do (
			if /i "!pan:~0,1!" == "s" (set /a "samples_x1=%%S/2") else (set "samples_x1=%%S")
		)
	)
)


set /a "fadeout_samples=fadeout_seconds*192000"
set /a "fadeout_start_sample=!samples_x1!-!fadeout_samples!"
if !fadeout_start_sample! lss 0 set fadeout_start_sample=0
if !fadeout_seconds! geq 1 (set "fadeout=afade=t=out:ss=!fadeout_start_sample!:ns=!fadeout_samples!:curve=cub") else (set "fadeout=anull")

set ot=0!track!
for %%F in ("!full_sid_path!") do (set "prefix=!wav_path!\!ot:~-2!_%%~nF")


if /i not "!record_mode:~0,1!" == "t" (
	for /l %%E in (0,1,1) do (
		for /l %%D in (0,1,1) do (
	
			!ffmpeg_q! -f concat -safe 0 -i "sv_cct_tw%%E_nf%%D_trm_0dc.txt" -c copy "sv_cct_tw%%E_nf%%D_trm_0dc.wav"
		
			for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_cct_tw%%E_nf%%D_trm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
			
				for /l %%N in (1,1,!chn!) do (
			
					set /a "samples_xprev=!samples_x%%N!-!samples_x1!"
	
					!ffmpeg_q! -i "sv_cct_tw%%E_nf%%D_trm_0dc.wav" ^
					-filter_complex "[0:a]atrim=start_sample=!samples_xprev!:end_sample=!samples_x%%N!,volume=%%VdB,asetpts=PTS-STARTPTS,!fadeout![%%N_tw%%E_nf%%D_trm_0dc_nrm_fdo]" ^
					-map "[%%N_tw%%E_nf%%D_trm_0dc_nrm_fdo]" "!prefix!_tw%%E_nf%%D_%%N.wav"
				)
				
				if /i "%%E%%D!record_mode:~0,1!" == "00v" (
					!ffmpeg_q! -i "sv_v_trm_0dc.wav" -filter_complex "[0:a]volume=%%VdB,!fadeout![v_trm_0dc_nrm_fdo]" -map "[v_trm_0dc_nrm_fdo]" "!prefix!_tw0_nf0_v.wav"
				)

			)
		)
	)
)


for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_a_trm_hpf_rsm_fdi.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	!ffmpeg_q! -i "sv_a_trm_hpf_rsm_fdi.wav" ^
	-filter_complex "[0:a]apad=whole_len=!samples_x1!,atrim=end_sample=!samples_x1!,volume=%%VdB,!fadeout![a_trm_hpf_rsm_fdi_adj_nrm_fdo]" ^
	-map "[a_trm_hpf_rsm_fdi_adj_nrm_fdo]" "!prefix!_tw0_nf0_a.wav"
)


echo Done.
pause

if "!delete_ffmpeg_wavs!" == "1" del sv_*
