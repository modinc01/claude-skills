#!/bin/bash
# 画像スライド(img/slideNN.png) + ナレーション(narr/sNN.wav) → MP4。各スライドはナレーション長 + 0.6s 表示、0.5s クロスフェード
set -euo pipefail
cd "$(dirname "$0")"
OUT="${1:-$HOME/Desktop/商品撮影のコツと実例図鑑.mp4}"
GAP=0.6; FADE=0.5
rm -rf seg && mkdir -p seg
N=$(ls img/slide??.png | wc -l | tr -d ' ')
for f in img/slide??.png; do
  i=$(basename "$f" .png | sed 's/slide//'); w="narr/s$i.wav"
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$w")
  dur=$(python3 -c "print(round($d+$GAP+$FADE,3))")
  # 画像→1920x1080(レターボックス無し: 16:9前提)、ごく弱いズーム
  ffmpeg -y -loglevel error -loop 1 -framerate 30 -i "$f" -t "$dur" -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,zoompan=z='min(1.0+0.00025*on,1.06)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1920x1080:fps=30,format=yuv420p" -c:v libx264 -preset fast -crf 18 "seg/$i.mp4"
done
# xfade で連結
python3 - "$N" "$FADE" <<'PY'
import sys,subprocess,glob
n=int(sys.argv[1]); fade=float(sys.argv[2]); files=sorted(glob.glob('seg/*.mp4'))
durs=[float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f]).decode()) for f in files]
inputs=[]; 
for f in files: inputs+=['-i',f]
fc=''; prev='[0:v]'; offset=0.0
for i in range(1,len(files)):
    offset+=durs[i-1]-fade
    out=f'[v{i}]' if i<len(files)-1 else '[vout]'
    fc+=f'{prev}[{i}:v]xfade=transition=fade:duration={fade}:offset={offset:.3f}{out};'
    prev=out
fc=fc.rstrip(';')
subprocess.check_call(['ffmpeg','-y','-loglevel','error',*inputs,'-filter_complex',fc,'-map','[vout]','-c:v','libx264','-preset','medium','-crf','18','-pix_fmt','yuv420p','video-silent.mp4'])
print('video', round(sum(durs)-fade*(len(files)-1),2))
PY
# ナレーション: 各段落をスライド開始に合わせて配置(段落頭はスライド切替後 FADE 秒)
python3 - "$N" "$GAP" "$FADE" <<'PY'
import sys,subprocess,glob
n=int(sys.argv[1]); gap=float(sys.argv[2]); fade=float(sys.argv[3])
wavs=sorted(glob.glob('narr/s??.wav'))
durs=[float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',w]).decode()) for w in wavs]
starts=[]; t=fade
for d in durs: starts.append(t); t+=d+gap
inputs=[]; fc=''
for i,w in enumerate(wavs):
    inputs+=['-i',w]; fc+=f'[{i}:a]adelay={int(starts[i]*1000)}|{int(starts[i]*1000)}[a{i}];'
fc+=''.join(f'[a{i}]' for i in range(len(wavs)))+f'amix=inputs={len(wavs)}:normalize=0[aout]'
subprocess.check_call(['ffmpeg','-y','-loglevel','error',*inputs,'-filter_complex',fc,'-map','[aout]','-ar','44100','-ac','1','narr/mix.wav'])
print('audio', round(t,2), 'starts', [round(s,2) for s in starts])
PY
ffmpeg -y -loglevel error -i video-silent.mp4 -i narr/mix.wav -c:v copy -c:a aac -b:a 160k -shortest "$OUT"
ffprobe -v error -show_entries stream=codec_type,width,height,duration -of compact "$OUT"
