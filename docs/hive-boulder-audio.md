# Hive boulder audio preparation

The pinned Hive commands select localized bank records 701 (`stone6.aud`),
704 (`stone4.aud`) and 709 (`stonel1.aud`). Four exact command payloads occur
once each in the supported Hive archive. See `hive-boulder-audio-source.json`
for hashes, request words, configuration bytes and PCM counts.

The local preparation tool validates every AUD chunk before accepting FFmpeg
output and checks the WAV round trip. As with the existing bridge voice
exporter, a declared extra sample is not synthesized: encoded nibble counts
own the decoded length. The first attempted strict header-count check failed;
chunk inspection identified this existing source-format edge case.

This is media preparation, not live sound acceptance. Native looping,
attenuation, owner removal and checkpoint playback remain unverified here.
Original AUD/WAV files remain local. Act One and boulder contact damage remain
open. No gameplay code changed in this checkpoint.
