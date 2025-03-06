-------------------------------------[sidvis]-------------------------------------

[ABOUT]

sidvis is a batch file script that records .SID music files and outputs .WAV
files that are meant to be used to create oscilloscope views. To run the script,
first edit "set_sidvis.bat" to input your desired settings, then run "sidvis.bat".
It records many 192 kHz sample rate .WAV files, so wait times may be lengthy.



[REQUIRED PROGRAMS]

The .WAV files are recorded from a modified version of sidplayfp (a SID emulation
software) and are then processed with ffmpeg.

You may need to have the C64 KERNAL and BASIC ROMs in the sidplayfp directory for
some tunes to playback properly.

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
programs and the SID music you'd like to record. Edit sidvis-set.bat in a text
editor to provide and/or change the settings used by sidvis.

Settings must be placed directly after the equals sign, with no spaces.


:: DIRECTORY PATHS

set sidplayfp_dir=
   * The path to the directory containing the sidvis-sidplayfp executable.
   * The .ZIP release sets this for you.

set ffmpeg_dir=
   * The path to the directory containing the ffmpeg executable.

set hvsc_dir=
   * The path to the directory containing the High Voltage SID Collection.

set wav_dir=
   * The path to the directory to output the .WAV recordings in.


:: TRACK

set sid_file_path=
   * The path to the .SID file to record.

set track_number=
   * The .SID file track (sub-tune) to record. 


:: TIMING

set record_mm_ss=
   * Must always be in "MM:SS" format.
   * The length of time to record each .WAV for.

set fadeout_seconds=
   * The length, in seconds, of a fade-out that can be added to the end of the
     recordings.

set add_hvsc_time=
   * Must be either "0" or "1".
   * "1" adds the track length indexed by the HVSC to the set record time.

set fadein_samples=
   * The length, in number of samples, of a fade-in that can be added to the start 
     of the master audio recording.
   * This is also how many samples of the D418 digi recording to skip when
     normalizing.
   * Set this higher if you wish to minimize a pop that often occurs at the start 
     of the master audio recording, or if the recordings are too quiet.	 

set start_delay_cycles=
   * C64 power on delay in CPU cycles, ranging from 0 to 8191.
   * Set this higher if the start of the track is cut off in the recordings.


:: EMULATION

set clock=
   * Must be either "a(uto)", "n(tsc)", or "p(al)". Lower-case only.
   * The C64 clock rates to use.
   * "auto" chooses based on the .SID header.

set sid_model=
   * Must be either "6(581)", "8(580)", or "d(igiboost)". Lower-case only.
   * The SID model to use.
   * "digiboost" emulates a 8580 modified to have the ability to playback D418
     digi like the 6581.
   * "auto" chooses based on the .SID header.

set filter_curve_6581=
  * Must be a number between 0 (light) and 1 (dark). Decimal settings must have a 
    leading 0.
  * Together with filter_range_6581, determines the cutoff response of the 6581's
    filter.

set filter_range_6581=
  * Must be a number between 0 (dark) and 1 (light). Decimal settings must have a 
    leading 0.
  * Together with filter_curve_6581, determines the cutoff response of the 6581's
    filter.


:: MASTER AUDIO

set ma_record=
   * Must be either "0" or "1".
   * "1" enables master audio recording.

set ma_pan=
   * Must be either "m(ono)" or "s(tereo)".
   * Determines whether the master audio recording is in mono or stereo.
   * Only works with tracks that use over 2 SID chips.
   * Stereo options are currently quite limited and may not be ideal, especially
     for 3 SID chips.


:: ON-SCREEN WAVEFORMS

set os_record=
   * Must be either "0" or "1".
   * "1" enables on-screen waveform recordings.

set os_d418_digi=
   * Must be either "0" or "1".
   * "1" enables separate D418 digi recording.


:: EXTERNAL TRIGGERS

set xt_record=
   * Must be either "0" or "1".
   * "1" enables external trigger recordings.

set xt_triggerwaves=
   * Must be either "0" or "1".
   * "1" modifies the SID's output to be easier to trigger.

set xt_no_filter=
   * Must be either "0" or "1".
   * "1" disables the SID's filter.



[.WAV RECORDINGS]

The contents of a .WAV recording can be determined by looking at its filename.

In order, the filename contains:
   * The .SID filename.
   * The track number.
   * "OS" or "XT". "OS" indicates on-screen waveforms. "XT" indicates external
     triggers.
   * "TW" and/or "NF", or neither. "TW" means triggerwaves are enabled. "NF"
     means the SID's filter is disabled.
   * The channel number.

----------------------------------------------------------------------------------