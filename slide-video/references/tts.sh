#!/usr/bin/env bash
# 台本（空行区切りの段落）を 1 段落 = 1 wav で生成し、timings.json（各段落の開始秒）を出す。
# 使い方: tts.sh narration.txt outdir
# 設定は ~/.config/tts/.env（Claude はこのファイルの中身を読まない。ユーザーが貼る）:
#   TTS_PROVIDER=elevenlabs | gemini
#   ELEVENLABS_API_KEY=…  ELEVENLABS_VOICE_ID=…  [ELEVENLABS_MODEL=eleven_multilingual_v2]
#   GEMINI_API_KEY=…      [GEMINI_VOICE=Charon]  [GEMINI_TTS_MODEL=gemini-2.5-flash-preview-tts]
set -euo pipefail
SRC="${1:?narration.txt}"; OUT="${2:-narr}"; mkdir -p "$OUT"
ENVF="$HOME/.config/tts/.env"; [ -f "$ENVF" ] || { echo "missing $ENVF" >&2; exit 1; }
set -a; source "$ENVF"; set +a
PROVIDER="${TTS_PROVIDER:-elevenlabs}"
python3 - "$SRC" "$OUT" <<'PY'
import sys,io,re,json
src,out=sys.argv[1],sys.argv[2]
paras=[p.strip() for p in re.split(r'\n\s*\n',io.open(src,encoding='utf-8').read()) if p.strip()]
for i,p in enumerate(paras,1): io.open(f'{out}/s{i:02d}.txt','w',encoding='utf-8').write(p)
print(len(paras))
PY
N=$(ls "$OUT"/s*.txt | wc -l | tr -d ' ')
for f in "$OUT"/s*.txt; do
  base="${f%.txt}"; [ -s "$base.wav" ] && { echo "skip $(basename "$base")"; continue; }
  text=$(cat "$f")
  if [ "$PROVIDER" = "elevenlabs" ]; then
    body=$(python3 -c 'import json,sys;print(json.dumps({"text":sys.argv[1],"model_id":sys.argv[2],"voice_settings":{"stability":0.5,"similarity_boost":0.8,"style":0.0,"use_speaker_boost":True}},ensure_ascii=False))' "$text" "${ELEVENLABS_MODEL:-eleven_multilingual_v2}")
    curl -sS --fail -X POST "https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}?output_format=mp3_44100_128" \
      -H "xi-api-key: ${ELEVENLABS_API_KEY}" -H "content-type: application/json" -d "$body" -o "$base.mp3"
    ffmpeg -y -loglevel error -i "$base.mp3" -ar 44100 -ac 1 "$base.wav"; rm -f "$base.mp3"
  else
    body=$(python3 -c 'import json,sys;print(json.dumps({"contents":[{"parts":[{"text":sys.argv[1]}]}],"generationConfig":{"responseModalities":["AUDIO"],"speechConfig":{"voiceConfig":{"prebuiltVoiceConfig":{"voiceName":sys.argv[2]}}}}},ensure_ascii=False))' "$text" "${GEMINI_VOICE:-Charon}")
    curl -sS --fail -X POST "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_TTS_MODEL:-gemini-2.5-flash-preview-tts}:generateContent" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" -H "content-type: application/json" -d "$body" -o "$base.json"
    python3 - "$base" <<'PY'
import sys,json,base64,wave
b=sys.argv[1]; j=json.load(open(b+'.json'))
part=j['candidates'][0]['content']['parts'][0]['inlineData']; pcm=base64.b64decode(part['data'])
rate=int((part.get('mimeType','').split('rate=')+['24000'])[1].split(';')[0]) if 'rate=' in part.get('mimeType','') else 24000
w=wave.open(b+'.wav','wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(pcm); w.close()
PY
    rm -f "$base.json"
  fi
  echo "ok $(basename "$base") $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$base.wav")s"
done
# 結合（段落間に 0.6 秒の無音）と timings.json
python3 - "$OUT" <<'PY'
import sys,subprocess,json,glob,os
out=sys.argv[1]; gap=0.6; files=sorted(glob.glob(f'{out}/s*.wav')); t=0.0; tim=[]
for f in files:
    d=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',f]).decode().strip())
    tim.append(round(t,2)); t+=d+gap
json.dump({'timings':tim,'total':round(t,2)},open(f'{out}/timings.json','w'))
lst=open(f'{out}/list.txt','w')
for f in files: lst.write(f"file '{os.path.abspath(f)}'\nfile '{os.path.abspath(out)}/gap.wav'\n")
lst.close()
rate=subprocess.check_output(['ffprobe','-v','error','-select_streams','a','-show_entries','stream=sample_rate','-of','csv=p=0',files[0]]).decode().strip()
subprocess.check_call(['ffmpeg','-y','-loglevel','error','-f','lavfi','-i',f'anullsrc=r={rate}:cl=mono','-t',str(gap),f'{out}/gap.wav'])
subprocess.check_call(['ffmpeg','-y','-loglevel','error','-f','concat','-safe','0','-i',f'{out}/list.txt','-c','copy',f'{out}/narration.wav'])
print('narration.wav', round(t,1),'s', 'timings', tim)
PY
