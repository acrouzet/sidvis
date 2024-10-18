setlocal enabledelayedexpansion

for %%N in ("%full_sid_path%") do (
	%sidplayfp_path%\sidplayfp -v -f192000 -ols%track% -t%rec_time% --delay=%delay% %rec_clock% %rec_model% %digiboost% --fcurve=%rec_filter_curve% --frange=%o_filter_range% -cw%combined_waves% --wav"%wav_path%\%%~nN_t.wav" "%full_sid_path%"
)