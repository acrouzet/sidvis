@echo off
call set_sidvis.bat
if "%quiet%" == "0" (set "q_echo=echo on") else (set "q_echo=")
%q_echo%


for /f "delims=: tokens=1,2" %%X in ("%time%") do (set /a "sec=(60*(1%%X-100))+(1%%Y-100)")

if "%use_hvsc%" == "1" (
	set "full_sid_path=%hvsc_path%\%sid_path%"
	for /f "delims=: eol=" %%N in ('findstr /inc:"%sid_path:\=/%" %hvsc_path%\DOCUMENTS\Songlengths.md5') do (set /a "index_target=%%N/2")
    set "index_count=1"
	setlocal enabledelayedexpansion
	for /f "delims== tokens=2" %%L in (%hvsc_path%\DOCUMENTS\Songlengths.md5) do (
		if !index_count! equ !index_target! (
			endlocal
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
if "%decimals%" == "" (set "tenth=0") else (set "tenth=%decimals:~0,1%")
if %tenth% geq 5 (set /a "rec_time=sl_mmss_sec+1+sec") else (set /a "rec_time=sl_mmss_sec+sec")

if "%use_hvsc%" == "0" (
	set "full_sid_path=%sid_path%"
	set "rec_time=%sec%"
)


if "%clock%" == "a" (
	for /f "tokens=5 delims= " %%C in ('%sidplayfp_path%\sidplayfp -v -t1 --none "%full_sid_path%" 2^>^&1 ^|find /i "Song Speed"') do (
		if "%%C" == "NTSC" (set "rec_clock=-vnf") else (set "rec_clock=-vpf")
	)
) else (set "rec_clock=-v%clock%f")


if "%sid_model%" == "a" (
	for /f "tokens=9 delims= " %%M in ('%sidplayfp_path%\sidplayfp -v -t1 --none "%full_sid_path%" 2^>^&1 ^|find /i "SID Model"') do (
		if "%%M" == "MOS6581" (set "rec_model=-mof") else (set "rec_model=-mnf")
	)
) else (if "%sid_model%" == "o" (set "rec_model=-mof") else (set "rec_model=-mnf"))


if "%sid_model%" == "d" (set "digiboost=--digiboost") else (set "digiboost=")

if "%rec_model%" == "-mof" (set "rec_filter_curve=%o_filter_curve%") else (set "rec_filter_curve=0.5")


if "%trigger_1_change_waves%" == "1" (set "tg1_tw=-tw") else (set "tg1_tw=")
if "%trigger_2_change_waves%" == "1" (set "tg2_tw=-tw") else (set "tg2_tw=")
if "%trigger_3_change_waves%" == "1" (set "tg3_tw=-tw") else (set "tg3_tw=")

if "%trigger_1_filter%" == "0" (set "tg1_nf=-nf") else (set "tg1_nf=")
if "%trigger_2_filter%" == "0" (set "tg2_nf=-nf") else (set "tg2_nf=")
if "%trigger_3_filter%" == "0" (set "tg3_nf=-nf") else (set "tg3_nf=")

if "%trigger_1_filter%" == "0" (set "tg0_1.wav=nf0.wav") else (set "tg0_1.wav=ch0.wav")
if "%trigger_2_filter%" == "0" (set "tg0_2.wav=nf0.wav") else (set "tg0_2.wav=ch0.wav")
if "%trigger_3_filter%" == "0" (set "tg0_3.wav=nf0.wav") else (set "tg0_3.wav=ch0.wav")


if "%quiet%" == "1" (set "q_sidplayfp=-q2") else (set "q_sidplayfp=")
if "%quiet%" == "1" (set "q_ffmpeg=-hide_banner -loglevel error") else (set "q_ffmpeg=")


set "common_set=-f192000 -ols%track% -t%rec_time% --delay=%delay% %rec_clock% %rec_model% %digiboost% --fcurve=%rec_filter_curve% --frange=%o_filter_range% -cw%combined_waves% %q_sidplayfp%"


if "%quiet%" == "1" (set "q_ffmpeg=-hide_banner -loglevel error") else (set "q_ffmpeg=")

set "trim=silenceremove=start_periods=1"

set "invert=aeval='-val(0)':c=same"

set "concat=concat=n=3:v=0:a=1"

set "mix=amix=normalize=0"

for %%N in ("%full_sid_path%") do (set "prefix=%%~nN")

set /a "fade_samples=%fade_time%*192000"

if "%rec_clock%" == "-vnf" set "adj_rate=192008"
if "%rec_clock%" == "-vpf" set "adj_rate=192045"


call "components\%channel_config%.bat"