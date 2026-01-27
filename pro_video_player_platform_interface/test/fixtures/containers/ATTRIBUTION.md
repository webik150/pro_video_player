# Container Test Fixtures Attribution

All video files in this directory are generated test patterns created with FFmpeg.
They contain no copyrighted content - only color test patterns and sine wave audio.

## Generation

Files were generated using FFmpeg with lavfi (libavfilter) sources:
- Video: `color` filter generating solid color frames
- Audio: `sine` filter generating pure sine wave tones

## Files

### MP4/MOV/M4A (ISO Base Media File Format)
- `sample_h264_aac.mp4` - H.264 + AAC
- `sample_hevc_aac.mp4` - HEVC + AAC
- `sample_h264.mov` - H.264 + AAC (QuickTime)
- `sample_audio.m4a` - AAC audio only

### MKV/WebM (Matroska/EBML)
- `sample_h264_aac.mkv` - H.264 + AAC
- `sample_hevc_opus.mkv` - HEVC + Opus
- `sample_vp9_opus.webm` - VP9 + Opus
- `sample_vp8_vorbis.webm` - VP8 + Vorbis

### MPEG Transport Stream
- `sample_h264_aac.ts` - H.264 + AAC
- `sample_mpeg2_mp2.ts` - MPEG-2 + MP2
- `sample_h264_videoonly.ts` - H.264 video only

### FLV (Flash Video)
- `sample_h264_aac.flv` - H.264 + AAC
- `sample_h264_mp3.flv` - H.264 + MP3
- `sample_h264_videoonly.flv` - H.264 video only

### AVI (Audio Video Interleave)
- `sample_h264_mp3.avi` - H.264 + MP3
- `sample_mpeg4_pcm.avi` - MPEG-4 Part 2 + PCM
- `sample_mjpeg_mp3.avi` - Motion JPEG + MP3
- `sample_xvid_videoonly.avi` - MPEG-4 (XVID tag) video only

## License

These files are in the public domain. No rights reserved.
