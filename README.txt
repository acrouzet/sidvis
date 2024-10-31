------------------------------------- sidvis -------------------------------------

[ABOUT]

sidvis is a batch file script that records .SID music files and outputs .WAV
files that are meant to be used to create oscilloscope views. To run the script,
first edit "set_sidvis.bat" to input your desired settings, then run "sidvis.bat".
It records many 192 kHz sample rate .WAV files, so wait times may be lengthy.



[REQUIRED PROGRAMS]

The .WAV files are recorded from a modified version of sidplayfp (a SID emulation 
software) and are then processed with ffmpeg.

The .ZIP release contains the sidvis-sidplayfp executable for Windows.

The source code of sidvis-sidplayfp is in these repositories:
   * https://github.com/acrouzet/sidvis-libsidplayfp
   * https://github.com/acrouzet/sidvis-sidplayfp

If you don't have the ffmpeg executable, you can download it here:
   * https://www.ffmpeg.org/download.html

sidvis's .WAV recordings are designed for corrscope, but other oscilloscope view 
programs may be compatible:
   * https://github.com/corrscope/corrscope



[SIDVIS-SET.BAT]

Before using sidvis, you need to provide some settings pointing to required 
programs and the SID music you'd like to record. Edit sidvis_set.bat in a text 
editor to provide and/or change the settings used by sidvis. 
(Non-path options must be lower-case.)


set sidplayfp_path=<(path)>
   * Path to the folder containing the sidvis-sidplayfp executable. 
   * The .ZIP release sets this for you.

set ffmpeg_path=<(path)>
   * Path to the folder containing the ffmpeg executable.

set hvsc_path=<(path)>
   * Path to the folder containing the High Voltage SID Collection.

set wav_path=<(path)>
   * Path to the folder to output the .WAV recordings in.


set use_hvsc=<0|1>
   * Determines how other settings will be interpreted.
   * 0 = Don't use the HVSC.
   * 1 = Use the HVSC.

set sid_path=<(path)>
   * Path to the .SID file to record. 
   * If use_hvsc=1, this path must start from your hvsc_path (i.e. this setting 
     will be expanded to the full path "<hvsc_path>\<sid_path>").

set track=<#>
   * The number of the .SID track (sub-tune) to record. If there's only one track, 
     set this to 1.


set record_mode=<[n]ormal|[v]olume|[t]est>
   * volume = Record the master volume output separate from the other channels. 
     Use this for tracks that use the master volume as a fourth channel.
   * test = Only do one recording with all channels enabled.

set time=<##:##>
   * Must always be in MM:SS format.
   * If use_hvsc=0, the total record time.
   * If use_hvsc=1, the record time to add onto the track length provided by the 
     HVSC.

set fadeout_seconds=<#>
   * The length, in seconds, of a fade-out that can be added to the end of the 
    .WAV recordings.


set pan=<[m]ono|[s]tereo>
   * Set the stereo configuration of the master audio. 
   * Only works with tracks that use over 2 SID chips.
   * Stereo options are currently quite limited and may not be ideal, especially
     for 3 SID chips.


set clock=<[n]tsc|[p]al]|[a]uto>
   * The C64 clock rates to use.
   * auto = Automatically choose based on the .SID header.

set sid_model=<[6]581|[8]580|[d]igiboost|[a]uto>
   * The SID model to use.
   * digiboost = 8580 modified to have the ability to use the master volume as a 
     fourth channel like the 6581.
   * auto = Automatically choose based on the .SID header.
	
set combined_waves=<[w]eak|[a]verage|[s]trong>
   * Strength of the combined waves. 
   * Weaker combined waves tend to have a thinner timbre.

set filter_curve_6581=<0.0-1.0>
   * Together with filter_range_6581, determines the cutoff response of the 6581's
     filter.
   * Ranges from 0.0 (light) to 1.0 (dark).

set filter_range_6581=<0.0-1.0>
   * Together with filter_curve_6581, determines the cutoff response of the 6581's
     filter.  
   * Ranges from 0.0 (dark) to 1.0 (light).


set delay=<#>
   * C64 power on delay in CPU cycles, ranging from 0 to 8191. 
   * Set this higher if the start of the track is cut off in the .WAV recordings.
	
set fadein_samples=<#>
   * The length, in number of samples, of a fade-in that can be added to the start
     of the .WAV recording with all channels enabled.
   * Set this higher if the .WAV recordings are too quiet.


set quiet=<#>
   * For debug purposes.
   * 1 = Echo off.
   * 2 = Quiet ffmpeg.
   * 3 = Quiet sidplayfp.

set delete_ffmpeg_wavs=<0|1>
   * For debug purposes. Delete the intermediary files in the ffmpeg_path?
   * 0 = No
   * 1 = Yes



[.WAV RECORDINGS]

The contents of a .WAV recording can be determined by looking at its filename. 

In order, the filename contains:
   * The .SID track number.
   * The .SID filename.
   * "tw0" or "tw1". "tw1" means particularly difficult-to-trigger waveforms are 
     replaced with simpler ones. In particular, pulse waves and sawtooth-combined 
     waves are replaced with sawtooth waves, and triangle+pulse waves are replaced 
     with triangle waves. Changes to the master volume are also disabled. 
   * "nf0" or "nf1". "nf1" means the filter and changes to the master volume are 
     disabled.
   * A single character representing which channel is enabled/isolated. "v" means 
     the master volume output is isolated, and "a" means all channels are enabled.

----------------------------------------------------------------------------------