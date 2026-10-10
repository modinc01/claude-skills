# ffmpeg / ffprobe メモ

- ナレーション長: `ffprobe -i narration.wav -show_entries format=duration -v quiet -of csv=p=0`
- 無音動画: `ffmpeg -y -framerate 30 -i frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart video-silent.mp4`
- 合成: `ffmpeg -y -i video-silent.mp4 -i narration.wav -c:v copy -c:a aac -b:a 192k -shortest out.mp4`
- 音声を少し遅らせて開始: `-itsoffset 0.5 -i narration.wav`（映像の前に置く）
- 確認: `ffprobe -v error -show_entries stream=codec_type,width,height,duration -of compact out.mp4`
- 1 フレームだけ確認: `ffmpeg -y -ss 12.5 -i out.mp4 -frames:v 1 check.jpg`
- frames/ は数千枚になる。完成後は削除してよい（render.js で再生成できる）
