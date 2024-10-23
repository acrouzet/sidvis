@echo off
call set_sidvis.bat
setlocal enabledelayedexpansion


if "!quiet!" == "0" (
	set "echo_q=echo on"
	set "sidplayfp_q=sidplayfp"
	set "ffmpeg_q=ffmpeg"
) else (
	set "echo_q="
	set "sidplayfp_q=sidplayfp -q2"
	set "ffmpeg_q=ffmpeg -hide_banner -loglevel error"
)

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


if "!clock!" == "a" (
	for /f "tokens=5 delims= " %%C in ('sidplayfp -v -t1 --none "!full_sid_path!" 2^>^&1 ^|find /i "Song Speed"') do (
		if "%%C" == "NTSC" (set "rec_clock=-vnf") else (set "rec_clock=-vpf")
	)
) else (set "rec_clock=-v!clock!f")


if "!sid_model!" == "a" (
	for /f "tokens=7 delims= " %%M in ('sidplayfp -v -t1 --none "!full_sid_path!" 2^>^&1 ^|find /i "SID Details"') do (
		if "%%M" == "MOS6581" (set "rec_model=-mof") else (set "rec_model=-mnf")
	)
) else (if "!sid_model!" == "o" (set "rec_model=-mof") else (set "rec_model=-mnf"))


if "!sid_model!" == "d" (set "digiboost=--digiboost") else (set "digiboost=")

if "!rec_model!" == "-mof" (set "rec_filter_curve=!o_filter_curve!") else (set "rec_filter_curve=0.5")

set "common_set=-ols!track! -t!rec_time! --delay=!delay! !rec_clock! !rec_model! !digiboost! --fcurve=!rec_filter_curve! --frange=!o_filter_range! -cw!combined_waves! -f192000"

for %%F in ("!full_sid_path!") do (set "prefix=%%~nF")

set z_track=0!track!


if "!channel_config!" == "t" (
	sidplayfp -v !common_set! -rr -!pan! --wav"!wav_path!\!z_track:~-2!_!prefix!_t.wav" "!full_sid_path!"
	pause
	exit
) else (
	!sidplayfp_q! !common_set! -rr -!pan! --wav"!ffmpeg_path!\sv_m.wav" "!full_sid_path!"
)


if "!channel_config!" == "4" (

	!sidplayfp_q! -u1 -u2 -u3 -nf !common_set! -ri -m --wav"!ffmpeg_path!\sv_v.wav" "!full_sid_path!"
	
	set "g1=-g1"
	set "fin=3"
	
) else (

	set "g1="
	set "fin=!channel_config!"
	
)


set "mute_set=-u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9"

for /l %%N in (0,1,!fin!) do (
	for /l %%E in (0,1,1) do (
		if "%%E" == "1" (set "tw=-tw%%N") else (set "tw=")
		for /l %%D in (0,1,1) do (
			if "%%D" == "1" (set "nf=-nf") else (set "nf=")
			!sidplayfp_q! !mute_set:-u%%N=! !tw! !nf! !g1! !common_set! -ri -m --wav"!ffmpeg_path!\sv_%%N_tw%%E_nf%%D.wav" "!full_sid_path!"
		)
	)
)


cd !ffmpeg_path!


set "trim=silenceremove=start_periods=1"
set "invert=aeval='-val(0)':c=same"
set "mix=amix=normalize=0"

for /l %%N in (1,1,!fin!) do (
	for /l %%E in (0,1,1) do (
		for /l %%D in (0,1,1) do (
			
			!ffmpeg_q! -i "sv_0_tw%%E_nf%%D.wav" -i "sv_%%N_tw%%E_nf%%D.wav" ^
			-filter_complex "[0:a]!trim!,!invert![0_tw%%E_nf%%D_trm_inv];[1:a]!trim!,[0_tw%%E_nf%%D_trm_inv]!mix![%%N_tw%%E_nf%%D_trm_0dc]" ^
			-map "[%%N_tw%%E_nf%%D_trm_0dc]" "sv_%%N_tw%%E_nf%%D_trm_0dc.wav"
	
			echo file 'sv_%%N_tw%%E_nf%%D_trm_0dc.wav' >> sv_cct_tw%%E_nf%%D_trm_0dc.txt
			
		)
	)
)

for /l %%N in (1,1,!fin!) do (		
	for /f "tokens=5" %%S in ('ffmpeg -i "sv_1_tw0_nf0_trm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "n_samples"') do (set /a "samples_x%%N=%%S*%%N")
)
set /a "fade_samples=fade_time*192000"
set /a "fade_start_sample=!samples_x1!-!fade_samples!"
if !fade_start_sample! lss 0 set fade_start_sample=0
if !fade_time! geq 1 (set "fade=afade=t=out:ss=!fade_start_sample!:ns=!fade_samples!:curve=cub") else (set "fade=anull")


for /l %%E in (0,1,1) do (
	for /l %%D in (0,1,1) do (
	
		!ffmpeg_q! -f concat -safe 0 -i "sv_cct_tw%%E_nf%%D_trm_0dc.txt" -c copy "sv_cct_tw%%E_nf%%D_trm_0dc.wav"
		
		for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_cct_tw%%E_nf%%D_trm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
		
			if "!channel_config!%%E%%D" == "400" (
				for /f "tokens=6 delims=- " %%A in ('ffmpeg -i "sv_v.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
					!ffmpeg_q! -y -i "sv_v.wav" -filter_complex "[0:a]!trim!,dcshift=%%A,volume=%%VdB,!fade![v_trm_0dc_nrm_fad]" -map "[v_trm_0dc_nrm_fad]" "!wav_path!\!z_track:~-2!_!prefix!_v.wav"
				)
			)
			
			for /l %%N in (1,1,!fin!) do (
			
				set /a "samples_xprev=!samples_x%%N!-!samples_x1!"
	
				!ffmpeg_q! -i "sv_cct_tw%%E_nf%%D_trm_0dc.wav" ^
				-filter_complex "[0:a]atrim=start_sample=!samples_xprev!:end_sample=!samples_x%%N!,volume=%%VdB,asetpts=PTS-STARTPTS,!fade![%%N_tw%%E_nf%%D_trm_0dc_nrm_fad]" ^
				-map "[%%N_tw%%E_nf%%D_trm_0dc_nrm_fad]" "!wav_path!\!z_track:~-2!_!prefix!_tw%%E_nf%%D_%%N.wav"
				
			)
		
		)
		
	)
)

if "!rec_clock!" == "-vnf" set "adj_rate=192008"
if "!rec_clock!" == "-vpf" set "adj_rate=192045"

!ffmpeg_q! -i "sv_m.wav" ^
-filter_complex "[0:a]!trim!,highpass=f=2:p=1,asetrate=!adj_rate!,aresample=192000:resampler=soxr,apad=whole_len=!samples_x1!,atrim=0:end_sample=!samples_x1!,!fade![m_trm_hpf_adj_fad]" ^
-map "[m_trm_hpf_adj_fad]" "sv_m_trm_hpf_adj_fad.wav"

for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "sv_m_trm_hpf_adj_fad.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	!ffmpeg_q! -i "sv_m_trm_hpf_adj_fad.wav" -af "volume=%%VdB" "!wav_path!\!z_track:~-2!_!prefix!_m.wav"
)


if "!delete_ffmpeg_wavs!" == "1" (del sv_*)