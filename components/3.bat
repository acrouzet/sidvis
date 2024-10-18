setlocal enabledelayedexpansion

cd %sidplayfp_path% 

sidplayfp %common_set% --wav"%ffmpeg_path%\ch0.wav" -ri -u1 -u2 -u3                   "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\ch1.wav" -ri     -u2 -u3                   "%full_sid_path%" 
sidplayfp %common_set% --wav"%ffmpeg_path%\ch2.wav" -ri -u1     -u3                   "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\ch3.wav" -ri -u1 -u2                       "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\nf0.wav" -ri -u1 -u2 -u3 -nf               "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\tg1.wav" -ri     -u2 -u3 %tg1_nf% %tg1_tw% "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\tg2.wav" -ri -u1     -u3 %tg2_nf% %tg2_tw% "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\tg3.wav" -ri -u1 -u2     %tg3_nf% %tg3_tw% "%full_sid_path%"
sidplayfp %common_set% --wav"%ffmpeg_path%\all.wav" -rr                               "%full_sid_path%"

cd %ffmpeg_path%

ffmpeg %q_ffmpeg% -i "ch0.wav" -i "ch1.wav" -i "ch2.wav" -i "ch3.wav" -i "%tg0_1.wav%" -i "%tg0_2.wav%" -i "%tg0_3.wav%" -i "tg1.wav" -i "tg2.wav" -i "tg3.wav" -filter_complex ^"^
[0:a]%trim%,%invert%,asplit=3[ch0_trm_inv_1][ch0_trm_inv_2][ch0_trm_inv_3];^
[1:a]%trim%,[ch0_trm_inv_1]%mix%[ch1_trm_0dc];^
[2:a]%trim%,[ch0_trm_inv_2]%mix%[ch2_trm_0dc];^
[3:a]%trim%,[ch0_trm_inv_3]%mix%[ch3_trm_0dc];^
[ch1_trm_0dc][ch2_trm_0dc][ch3_trm_0dc]%concat%[chn_trm_0dc_cct];^
[4:a]%trim%,%invert%[tg0_trm_inv_1];^
[5:a]%trim%,%invert%[tg0_trm_inv_2];^
[6:a]%trim%,%invert%[tg0_trm_inv_3];^
[7:a]%trim%,[tg0_trm_inv_1]%mix%,volume=15dB[tg1_trm_0dc_tnm];^
[8:a]%trim%,[tg0_trm_inv_2]%mix%,volume=15dB[tg2_trm_0dc_tnm];^
[9:a]%trim%,[tg0_trm_inv_3]%mix%,volume=15dB[tg3_trm_0dc_tnm]^" ^
-map "[chn_trm_0dc_cct]" "chn_trm_0dc_cct.wav" ^
-map "[tg1_trm_0dc_tnm]" "%wav_path%\%prefix%_%track%_tg1.wav" ^
-map "[tg2_trm_0dc_tnm]" "%wav_path%\%prefix%_%track%_tg2.wav" ^
-map "[tg3_trm_0dc_tnm]" "%wav_path%\%prefix%_%track%_tg3.wav"

for /f "tokens=5" %%S in ('ffmpeg -i "%wav_path%\%prefix%_%track%_tg1.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "n_samples"') do (set "samples=%%S")
set /a "samples_x2=%samples%*2"
set /a "fade_start_sample=%samples%-%fade_samples%"
if %fade_start_sample% lss 0 set fade_start_sample=0
if %fade_time% geq 1 (set "fade=afade=t=out:ss=%fade_start_sample%:ns=%fade_samples%:curve=cub") else (set "fade=anull")

for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "chn_trm_0dc_cct.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	ffmpeg !q_ffmpeg! -i "chn_trm_0dc_cct.wav" -i "all.wav" -filter_complex ^"^
	[0:a]volume=%%VdB,asplit=3[chn_trm_0dc_cct_nrm_1][chn_trm_0dc_cct_nrm_2][chn_trm_0dc_cct_nrm_3];^
	[chn_trm_0dc_cct_nrm_1]atrim=end_sample=!samples!,asetpts=PTS-STARTPTS,!fade![ch1_trm_0dc_nrm_fad];^
	[chn_trm_0dc_cct_nrm_2]atrim=start_sample=!samples!:end_sample=!samples_x2!,asetpts=PTS-STARTPTS,!fade![ch2_trm_0dc_nrm_fad];^
	[chn_trm_0dc_cct_nrm_3]atrim=start_sample=!samples_x2!,asetpts=PTS-STARTPTS,!fade![ch3_trm_0dc_nrm_fad];^
	[1:a]!trim!,highpass=f=2:p=1,asetrate=!adj_rate!,aresample=192000:resampler=soxr,apad=whole_len=!samples!,atrim=0:end_sample=!samples!,!fade![all_trm_hpf_adj_fad]^" ^
	-map "[ch1_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch1.wav" ^
	-map "[ch2_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch2.wav" ^
	-map "[ch3_trm_0dc_nrm_fad]" "!wav_path!\!prefix!_!track!_ch3.wav" ^
	-map "[all_trm_hpf_adj_fad]" "all_trm_hpf_adj_fad.wav"
)
for /f "tokens=5 delims=- " %%V in ('ffmpeg -i "all_trm_hpf_adj_fad.wav" -af "volumedetect" -f null nul 2^>^&1 ^|find /i "max_volume"') do (
	ffmpeg !q_ffmpeg! -i "all_trm_hpf_adj_fad.wav" -af "volume=%%VdB" "!wav_path!\!prefix!_!track!_all.wav"
)

if "%delete_ffmpeg_wavs%" == "1" (
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
)