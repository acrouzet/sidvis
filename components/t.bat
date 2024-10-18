setlocal enabledelayedexpansion

for %%N in ("%full_sid_path%") do (
	%sidplayfp_path%\sidplayfp %common_set% --wav"%wav_path%\%%~nN_all_raw.wav" "%full_sid_path%"
)