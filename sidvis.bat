@echo off
call set_sidvis.bat
setlocal enabledelayedexpansion
if !quiet! equ 0 (set "q_echo=echo on") else (set "q_echo=")
!q_echo!

cd !sidplayfp_path!


for /f "delims=: tokens=1,2" %%X in ("!time!") do (set /a "sec=(60*(1%%X-100))+(1%%Y-100)")

if !use_hvsc! equ 1 (
	set "full_sid_path=!hvsc_path!\!sid_path!"
	for /f "delims=: eol=" %%N in ('findstr /inc:"!sid_path:\=/!" !hvsc_path!\DOCUMENTS\Songlengths.md5') do (set /a "index_target=%%N/2")
    set "index_count=1"
	for /f "delims== tokens=2" %%L in (!hvsc_path!\DOCUMENTS\Songlengths.md5) do (
		if !index_count! equ !index_target! (
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

if !use_hvsc! equ 0 (
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

for %%F in ("!full_sid_path!") do (set "prefix=%%~nF")

set "common_set=-f192000 -ols!track! -t!rec_time! --delay=!delay! !rec_clock! !rec_model! !digiboost! --fcurve=!rec_filter_curve! --frange=!o_filter_range! -cw!combined_waves!"

if !quiet! equ 1 (set "q_sidplayfp=sidplayfp -q2") else (set "q_sidplayfp=sidplayfp")


if "!channel_config!" == "t" (
	sidplayfp -!pan! !common_set! -v -rr --wav"!wav_path!\!prefix!_!track!_t.wav" "!full_sid_path!"
	pause
	exit
) else (
	!q_sidplayfp! -!pan! !common_set! -rr --wav"!ffmpeg_path!\all.wav" "!full_sid_path!"
)



if !channel_config! equ 4 (
	!q_sidplayfp! -m !common_set! -ri --wav"!ffmpeg_path!\vol.wav" -ri -u1 -u2 -u3 -nf "!full_sid_path!"
	set "rec_g1=-g1"
) else (set "rec_g1=")


set "na_sidplayfp=!q_sidplayfp! -m !rec_g1! !common_set! -ri --wav"!ffmpeg_path!"


if !channel_config! leq 4 set "nums=1,1,3"
if !channel_config! equ 6 set "nums=1,1,6"
if !channel_config! equ 9 set "nums=1,1,9"


for /l %%N in (!nums!) do (
	if !trigger_%%N_filter! equ 0 (
		set "tg%%N_nf=-nf"
		set "tg0_%%N.wav=nf0.wav"
	) else (
		set "tg%%N_nf="
		set "tg0_%%N.wav=ch0.wav"
	)
	if !trigger_%%N_change_waves! equ 1 (
		set "tg%%N_tw=-tw"
	) else ( 
		set "tg%%N_tw="
	)
)


!na_sidplayfp!\ch0.wav" -u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9                   "!full_sid_path!"
!na_sidplayfp!\ch1.wav"     -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9                   "!full_sid_path!" 
!na_sidplayfp!\ch2.wav" -u1     -u3 -u4 -u5 -u6 -u7 -u8 -u9                   "!full_sid_path!"
!na_sidplayfp!\ch3.wav" -u1 -u2     -u4 -u5 -u6 -u7 -u8 -u9                   "!full_sid_path!"
!na_sidplayfp!\nf0.wav" -u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9 -nf               "!full_sid_path!"
!na_sidplayfp!\tg1.wav"     -u2 -u3 -u4 -u5 -u6 -u7 -u8 -u9 !tg1_nf! !tg1_tw! "!full_sid_path!"
!na_sidplayfp!\tg2.wav" -u1     -u3 -u4 -u5 -u6 -u7 -u8 -u9 !tg2_nf! !tg2_tw! "!full_sid_path!"
!na_sidplayfp!\tg3.wav" -u1 -u2     -u4 -u5 -u6 -u7 -u8 -u9 !tg3_nf! !tg3_tw! "!full_sid_path!"

if !channel_config! geq 6 (
	!na_sidplayfp!\ch4.wav" -u1 -u2 -u3     -u5 -u6 -u7 -u8 -u9                   "!full_sid_path!" 
	!na_sidplayfp!\ch5.wav" -u1 -u2 -u3 -u4     -u6 -u7 -u8 -u9                   "!full_sid_path!"
	!na_sidplayfp!\ch6.wav" -u1 -u2 -u3 -u4 -u5     -u7 -u8 -u9                   "!full_sid_path!"
	!na_sidplayfp!\tg4.wav" -u1 -u2 -u3     -u5 -u6 -u7 -u8 -u9 !tg4_nf! !tg4_tw! "!full_sid_path!"
	!na_sidplayfp!\tg5.wav" -u1 -u2 -u3 -u4     -u6 -u7 -u8 -u9 !tg5_nf! !tg5_tw! "!full_sid_path!"
	!na_sidplayfp!\tg6.wav" -u1 -u2 -u3 -u4 -u5     -u7 -u8 -u9 !tg6_nf! !tg6_tw! "!full_sid_path!"
)
if !channel_config! equ 9 (
	!na_sidplayfp!\ch7.wav" -u1 -u2 -u3 -u4 -u5 -u6     -u8 -u9                   "!full_sid_path!" 
	!na_sidplayfp!\ch8.wav" -u1 -u2 -u3 -u4 -u5 -u6 -u7     -u9                   "!full_sid_path!"
	!na_sidplayfp!\ch9.wav" -u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8                       "!full_sid_path!"
	!na_sidplayfp!\tg7.wav" -u1 -u2 -u3 -u4 -u5 -u6     -u8 -u9 !tg7_nf! !tg7_tw! "!full_sid_path!"
	!na_sidplayfp!\tg8.wav" -u1 -u2 -u3 -u4 -u5 -u6 -u7     -u9 !tg8_nf! !tg8_tw! "!full_sid_path!"
	!na_sidplayfp!\tg9.wav" -u1 -u2 -u3 -u4 -u5 -u6 -u7 -u8     !tg9_nf! !tg9_tw! "!full_sid_path!"
)


cd !ffmpeg_path!


if !quiet! equ 1 (set "q_ffmpeg=ffmpeg -hide_banner -loglevel error") else (set "q_ffmpeg=ffmpeg")

set "trim=silenceremove=start_periods=1"

set "invert=aeval='-val(0)':c=same"

set "mix=amix=normalize=0"


for /l %%N in (!nums!) do (

	!q_ffmpeg! -i "ch0.wav" -i "ch%%N.wav" -filter_complex "[0:a]!trim!,!invert![ch0_trm_inv];[1:a]!trim!,[ch0_trm_inv]!mix![chn_trm_0dc]" -map "[chn_trm_0dc]" "ch%%N_trm_0dc.wav"
	echo file 'ch%%N_trm_0dc.wav' >> chn_trm_0dc_cct.txt
	
	for /f "tokens=5" %%S in ('ffmpeg -i "ch1_trm_0dc.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "n_samples"') do (set /a "samples_x%%N=%%S*%%N")
	
)

!q_ffmpeg! -f concat -safe 0 -i chn_trm_0dc_cct.txt -c copy "chn_trm_0dc_cct.wav"


set /a "fade_samples=fade_time*192000"
set /a "fade_start_sample=!samples_x1!-!fade_samples!"
if !fade_start_sample! lss 0 set fade_start_sample=0
if !fade_time! geq 1 (set "fade=afade=t=out:ss=!fade_start_sample!:ns=!fade_samples!:curve=cub") else (set "fade=anull")


for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "chn_trm_0dc_cct.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (

	!q_ffmpeg! -i "chn_trm_0dc_cct.wav" -af "volume=%%VdB" "chn_trm_0dc_cct_nrm.wav"
	
	if !channel_config! equ 4 (
		for /f "tokens=6 delims=- " %%D in ('ffmpeg -i "vol.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
			!q_ffmpeg! -y -i "vol.wav" -filter_complex "[0:a]!trim!,dcshift=%%D,volume=%%VdB,!fade![vol_trm_0dc_nrm_fad]" -map "[vol_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_vol.wav"
		)
	)
	
)

for /l %%N in (!nums!) do (

	set /a "samples_xprev=!samples_x%%N!-!samples_x1!"
	
	!q_ffmpeg! -i "chn_trm_0dc_cct_nrm.wav" -filter_complex "[0:a]atrim=start_sample=!samples_xprev!:end_sample=!samples_x%%N!,asetpts=PTS-STARTPTS,!fade![chn_trm_0dc_nrm_fad]" ^
	-map "[chn_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch%%N.wav"
	
)
	

for /l %%N in (!nums!) do (
	!q_ffmpeg! -i "!tg0_%%N.wav!" -i "tg%%N.wav" -filter_complex "[0:a]!trim!,!invert![tg0_trm_inv];[1:a]!trim!,[tg0_trm_inv]!mix!,volume=15dB[tgn_trm_0dc_nrm]" -map "[tgn_trm_0dc_nrm]" "!wav_path!\!prefix!_!track!_tg%%N.wav"
)


if "!rec_clock!" == "-vnf" set "adj_rate=192008"
if "!rec_clock!" == "-vpf" set "adj_rate=192045"

!q_ffmpeg! -i "all.wav" -filter_complex "[0:a]!trim!,highpass=f=2:p=1,asetrate=!adj_rate!,aresample=192000:resampler=soxr,apad=whole_len=!samples_x1!,atrim=0:end_sample=!samples_x1!,!fade![all_trm_hpf_adj_fad]" ^
-map "[all_trm_hpf_adj_fad]" "all_trm_hpf_adj_fad.wav"

for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "all_trm_hpf_adj_fad.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	!q_ffmpeg! -i "all_trm_hpf_adj_fad.wav" -af "volume=%%VdB" "!wav_path!\!prefix!_!track!_all.wav"
)


if "!delete_ffmpeg_wavs!" == "1" (
	del all.wav
	del all_trm_hpf_adj_fad.wav
	del ch0.wav
	del ch1.wav
	del ch1_trm_0dc.wav
	del ch2.wav
	del ch2_trm_0dc.wav
	del ch3.wav
	del ch3_trm_0dc.wav
	del ch4.wav
	del ch4_trm_0dc.wav
	del ch5.wav
	del ch5_trm_0dc.wav
	del ch6.wav
	del ch6_trm_0dc.wav
	del ch7.wav
	del ch7_trm_0dc.wav
	del ch8.wav
	del ch8_trm_0dc.wav
	del ch9.wav
	del ch9_trm_0dc.wav
	del chn_trm_0dc_cct.txt
	del chn_trm_0dc_cct.wav
	del chn_trm_0dc_cct_nrm.wav
	del nf0.wav
	del tg1.wav
	del tg2.wav
	del tg3.wav
	del tg4.wav
	del tg5.wav
	del tg6.wav
	del tg7.wav
	del tg8.wav
	del tg9.wav
	del vol.wav
)