echo off
call set_sidvis.bat
setlocal enabledelayedexpansion

for /f "delims=: tokens=1,2" %%X in ("%time%") do (set /a "sec=(60*(1%%X-100))+(1%%Y-100)")
set "sid_path_fix=%sid_path:\=/%"
if "%use_hvsc%" == "1" (
	set "full_sid_path=%hvsc_path%\%sid_path%"
	for /f "delims=: eol=" %%N in ('findstr /inc:"%sid_path_fix%" %hvsc_path%\DOCUMENTS\Songlengths.md5') do (set /a "index_target=%%N/2")
    set "index_count=1"
	for /f "delims== tokens=2" %%L in (%hvsc_path%\DOCUMENTS\Songlengths.md5) do (
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
	:exit_index_count
    if "%decimals%" == "" (set "tenth=0") else (set "tenth=%decimals:~0,1%")
	if !tenth! geq 5 (set /a "rec_time=sl_mmss_sec+1+sec") else (set /a "rec_time=sl_mmss_sec+sec")
)
if "%use_hvsc%" == "0" (
	set "full_sid_path=%sid_path%"
	set "rec_time=%sec%"
)

cd %sidinfo_path%

if "%clock%" == "a" (
	for /f "delims=" %%C in ('sidinfo -p -F @videoclock@ %full_sid_path%') do (
		if "%%C" == "NTSC 60Hz" (set "rec_clock=n") else (set "rec_clock=p")
	) 
) else (set "rec_clock=%clock%")

if "%sid_model%" == "a" (
	for /f "delims=" %%M in ('sidinfo -p -F @sidmodel@ %full_sid_path%') do (
		if "%%M" == "MOS6581" (set "rec_model=o") else (set "rec_model=n")
	)
) else (
	if "%sid_model%" == "o" (set "rec_model=o") else (set "rec_model=n")
)

if "%sid_model%" == "d" (set "digiboost=--digiboost") else (set "digiboost=")

if "%rec_model%" == "o" (set "rec_filter_curve=%o_filter_curve%") else (set "rec_filter_curve=0.5")

if "%trigger_1_filter%" == "0" (set "tg1_nf=-nf") else (set "tg1_nf=")
if "%trigger_2_filter%" == "0" (set "tg2_nf=-nf") else (set "tg2_nf=")
if "%trigger_3_filter%" == "0" (set "tg3_nf=-nf") else (set "tg3_nf=")

if "%trigger_1_change_waves%" == "1" (set "tg1_tw=-tw") else (set "tg1_tw=")
if "%trigger_2_change_waves%" == "1" (set "tg2_tw=-tw") else (set "tg2_tw=")
if "%trigger_3_change_waves%" == "1" (set "tg3_tw=-tw") else (set "tg3_tw=")

cd %sidplayfp_path%

set "common_set=-f192000 -ols%track% -t%rec_time% --delay=%delay% -v%rec_clock%f -m%rec_model%f %digiboost% --fcurve=%rec_filter_curve% --frange=%o_filter_range%"

sidplayfp %common_set% --wav"%ffmpeg_path%\ch0.wav" -ri -u1 -u2 -u3 -g1                   "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\ch1.wav" -ri     -u2 -u3 -g1                   "%full_sid_path%" 
sidplayfp %common_set% --wav"%ffmpeg_path%\ch2.wav" -ri -u1     -u3 -g1                   "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\ch3.wav" -ri -u1 -u2     -g1                   "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\vol.wav" -ri -u1 -u2 -u3     -nf               "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\nf0.wav" -ri -u1 -u2 -u3 -g1 -nf               "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\tg1.wav" -ri     -u2 -u3 -g1 %tg1_nf% %tg1_tw% "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\tg2.wav" -ri -u1     -u3 -g1 %tg2_nf% %tg2_tw% "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\tg3.wav" -ri -u1 -u2     -g1 %tg3_nf% %tg3_tw% "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\all.wav" -rr                                   "%full_sid_path%"

cd %ffmpeg_path%

if "%trigger_1_filter%" == "0" (set "tg0_1.wav=nf0.wav") else (set "tg0_1.wav=ch0.wav")
if "%trigger_2_filter%" == "0" (set "tg0_2.wav=nf0.wav") else (set "tg0_2.wav=ch0.wav")
if "%trigger_3_filter%" == "0" (set "tg0_3.wav=nf0.wav") else (set "tg0_3.wav=ch0.wav")
set "trim=silenceremove=start_periods=1"
set "invert=aeval='-val(0)':c=same"
set "concat=concat=n=3:v=0:a=1"
set "mix=amix=normalize=0"
for %%N in ("%full_sid_path%") do (set "prefix=%%~nN")

for /f "tokens=6 delims=- " %%D in ('ffmpeg -i "vol.wav" -af "astats" -f null nul 2^>^&1 ^|find /i "DC offset"') do (
	ffmpeg -i "ch0.wav" -i "ch1.wav" -i "ch2.wav" -i "ch3.wav" -i "vol.wav"  -i "%tg0_1.wav%" -i "%tg0_2.wav%" -i "%tg0_3.wav%" -i "tg1.wav" -i "tg2.wav" -i "tg3.wav" -filter_complex ^"^
	[0:a]!trim!,!invert!,asplit=3[ch0_trm_inv_1][ch0_trm_inv_2][ch0_trm_inv_3];^
	[1:a]!trim!,[ch0_trm_inv_1]!mix![ch1_trm_0dc];^
	[2:a]!trim!,[ch0_trm_inv_2]!mix![ch2_trm_0dc];^
	[3:a]!trim!,[ch0_trm_inv_3]!mix![ch3_trm_0dc];^
	[ch1_trm_0dc][ch2_trm_0dc][ch3_trm_0dc]!concat![chn_trm_0dc_cct];^
	[4:a]!trim!,dcshift=%%D,asplit=2[vol_trm_0dc_1][vol_trm_0dc_2];^
	[vol_trm_0dc_2]highpass=f=!trigger_vol_highpass!:p=1,volume=16dB[vol_trm_0dc_hpf_tnm];^
	[5:a]!trim!,!invert![tg0_trm_inv_1];^
	[6:a]!trim!,!invert![tg0_trm_inv_2];^
	[7:a]!trim!,!invert![tg0_trm_inv_3];^
	[8:a]!trim!,[tg0_trm_inv_1]!mix!,volume=15dB[tg1_trm_0dc_tnm];^
	[9:a]!trim!,[tg0_trm_inv_2]!mix!,volume=15dB[tg2_trm_0dc_tnm];^
	[10:a]!trim!,[tg0_trm_inv_3]!mix!,volume=15dB[tg3_trm_0dc_tnm]^" ^
	-map "[chn_trm_0dc_cct]" "chn_trm_0dc_cct.wav" ^
	-map "[vol_trm_0dc_1]" "vol_trm_0dc.wav" ^
	-map "[vol_trm_0dc_hpf_tnm]" "!wav_path!\!prefix!_!track!_tgv.wav" ^
	-map "[tg1_trm_0dc_tnm]" "!wav_path!\!prefix!_!track!_tg1.wav" ^
	-map "[tg2_trm_0dc_tnm]" "!wav_path!\!prefix!_!track!_tg2.wav" ^
	-map "[tg3_trm_0dc_tnm]" "!wav_path!\!prefix!_!track!_tg3.wav"
	goto :exit_astats_dc
)
:exit_astats_dc

for /f "tokens=5" %%S in ('ffmpeg -i "%wav_path%\%prefix%_%track%_tg1.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "n_samples"') do (set "samples=%%S")
set /a "samples_x2=%samples%*2"
set /a "samples_x3=%samples%*3"
set /a "fade_samples=%fade_time%*192000"
set /a "fade_start_sample=%samples%-%fade_samples%"
if %fade_start_sample% lss 0 set fade_start_sample=0
if %fade_time% geq 1 (set "fade=afade=t=out:ss=%fade_start_sample%:ns=%fade_samples%:curve=cub") else (set "fade=anull")
if "%rec_clock%" == "n" set "adj_rate=192008"
if "%rec_clock%" == "p" set "adj_rate=192045"

for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "chn_trm_0dc_cct.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	ffmpeg -i "chn_trm_0dc_cct.wav" -i "vol_trm_0dc.wav" -i "all.wav" -filter_complex ^"^
	[0:a]volume=%%VdB,asplit=3[chn_trm_0dc_cct_nrm_1][chn_trm_0dc_cct_nrm_2][chn_trm_0dc_cct_nrm_3];^
	[chn_trm_0dc_cct_nrm_1]atrim=end_sample=!samples!,asetpts=PTS-STARTPTS,!fade![ch1_trm_0dc_nrm_fad];^
	[chn_trm_0dc_cct_nrm_2]atrim=start_sample=!samples!:end_sample=!samples_x2!,asetpts=PTS-STARTPTS,!fade![ch2_trm_0dc_nrm_fad];^
	[chn_trm_0dc_cct_nrm_3]atrim=start_sample=!samples_x2!,asetpts=PTS-STARTPTS,!fade![ch3_trm_0dc_nrm_fad];^
	[1:a]volume=%%VdB,!fade![vol_trm_0dc_nrm_fad];^
	[2:a]!trim!,highpass=f=2:p=1,asetrate=!adj_rate!,aresample=192000:resampler=soxr,apad=whole_len=!samples!,atrim=0:end_sample=!samples!,!fade![all_trm_hpf_adj_fad]^" ^
	-map "[ch1_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch1.wav" ^
	-map "[ch2_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch2.wav" ^
	-map "[ch3_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch3.wav" ^
	-map "[vol_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_vol.wav" ^
	-map "[all_trm_hpf_adj_fad]" "all_trm_hpf_adj_fad.wav"
)
for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "all_trm_hpf_adj_fad.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	ffmpeg -i "all_trm_hpf_adj_fad.wav" -af "volume=%%VdB" "!wav_path!\!prefix!_!track!_all.wav"
)

if "%keep_ffmpeg_wavs%" == "0" (
	del all.wav
	del all_trm_hpf_adj_fad.wav
	del ch0.wav
	del ch1.wav
	del ch2.wav
	del ch3.wav
	del chn_trm_0dc_cct.wav
	del nf0.wav
	del tg1.wav
	del tg2.wav
	del tg3.wav
	del vol.wav
	del vol_trm_0dc.wav
)