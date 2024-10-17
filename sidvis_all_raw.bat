echo off
call set_sidvis.bat
setlocal enabledelayedexpansion

if "%quiet%" == "0" (set "q_echo=echo on") else (set "q_echo=")
%q_echo%

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

if "%quiet%" == "1" (set "q_sidplayfp=-q2") else (set "q_sidplayfp=")

set "common_set=-f192000 -rr -ols%track% -t%rec_time% --delay=%delay% -v%rec_clock%f -m%rec_model%f %digiboost% --fcurve=%rec_filter_curve% --frange=%o_filter_range% -cw%combined_waves% %q_sidplayfp%"

cd %sidplayfp_path%

for %%N in ("%full_sid_path%") do (
	sidplayfp %common_set% --wav"%wav_path%\%%~nN_all_raw.wav" "%full_sid_path%"
)
