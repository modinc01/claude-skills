---
name: slide-video
description: スライドや LP のセクションを「ナレーション付きの MP4 動画」にする。HTML で 1920×1080 のスライドを組み、puppeteer-core で連番フレームを書き出し、ffmpeg でナレーション(Gemini TTS)と合成する。「スライドを動画にして」「紹介動画を作って」「LP を動画化して」と言われたら使う。Canva で読み上げ用スライドを作るだけなら slide-deck を使う。
---

# スライド動画化（HTML → MP4）

ゴールは **ナレーション入りの MP4 を 1 本、`~/Desktop/<サービス名>紹介動画.mp4` に置くこと**。途中で確認を挟まず、台本 → ナレーション → スライド HTML → レンダー → 合成 → 目視確認まで通す。

## 方針（ユーザーの過去の評価から）

- **既存 LP のデザインをそのまま流用する**。独自のモーショングラフィックスを作ると「デザインが稚拙」と評価された（2026-09-29）。LP の CSS とセクション HTML を抜き出し、スライドとして並べる
- モーションは最小限。フェード、カードへのズーム（注目部分だけ不透明にする）程度
- 1 シーン = 台本 1 段落。60〜90 秒、6〜8 シーンが目安
- 「唯一の」「必ず」などの断定表現は使わない。最終 CTA は「まずは N 日間、無料でお試しください」の形
- フォントは Noto Sans JP をローカル同梱（`assets/fonts/`）。Google Fonts 参照は headless で欠けることがある

## 手順

### 1. 台本（ナレーション原稿）

シーンごとに「画面に出すもの」「ナレーション」「秒数の目安」を md に書く（`docs/promo/<name>-video.md`）。
ナレーションは聞き取りやすい短文。改行＝息継ぎ。全体で 60〜90 秒。

### 2. ナレーション音声（API 連携・本人の声）

**ブラウザの AI Studio は使わない。** `references/tts.sh` で API から生成する（声は本人クローン「たいせい」）。設定は `~/.config/tts/.env`（ユーザーが貼る。Claude は読まない）:

```
TTS_PROVIDER=elevenlabs            # elevenlabs | gemini
ELEVENLABS_API_KEY=…
ELEVENLABS_VOICE_ID=…              # 「たいせい」の voice_id
```

```sh
bash ~/.claude/skills/slide-video/references/tts.sh narration.txt narr
# → narr/s01.wav … narr/narration.wav（段落間 0.6 秒）と narr/timings.json（各段落の開始秒 = window.timings にそのまま使う）
```

narration.txt は台本の「ナレーション」列を **空行区切りの段落** にしたもの（1 段落 = 1 シーン）。timings.json の `timings` と `total` を slides.html の `window.timings` / `window.totalSeconds` に入れれば、音声とスライドが自動で同期する。

（旧手順: AI Studio の画面で Gemini TTS。声が既定の Fola になり本人の声と別物になるので使わない）


### 3. スライド HTML（references/slides-template.html をコピー）

1920×1080 固定。**必須の 3 つ**を window に生やす:

- `window.ready` … フォント読み込み完了を resolve する Promise
- `window.totalSeconds` … 動画の長さ（秒）
- `window.seek(t)` … 時刻 t（秒）の見た目を **決定的に** 作る関数。アニメーションは Web Animations API の `pause()` + `currentTime` か、t から直接 opacity/transform を計算する。setTimeout/requestAnimationFrame に依存しない

LP を流用するときは `references/capture-lp.js` の要領で、本番 LP から CSS とセクション HTML を取り出して `lp/` に置く（固定ヘッダー・CTA バー・ヘルプボットは CSS で非表示）。

### 4. レンダー（references/render.js をコピー）

```sh
cd docs/promo/video && npm i puppeteer-core          # 初回のみ。Chrome 本体は /Applications のものを使う
FILE=slides.html node render.js 12.5                 # 12.5 秒目のプレビュー → preview-12.5.jpg を目視
FILE=slides.html node render.js                      # frames/00000.jpg … を 30fps で書き出し
```

プレビューは **シーンの切り替わり直後と直前** を数か所見る。文字欠け・画像の遅延読み込み漏れ・はみ出しはここで潰す。

### 5. 合成（ffmpeg）

```sh
ffmpeg -y -framerate 30 -i frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart video-silent.mp4
ffmpeg -y -i video-silent.mp4 -i ../narration.wav -c:v copy -c:a aac -b:a 192k -shortest "$HOME/Desktop/<サービス名>紹介動画.mp4"
```

長さ・解像度・音声の有無を `ffprobe` で確認してから渡す。

### 6. サムネイル（任意）

`thumbnail.html`（1280×720、ロゴ＋一言）を `node render-thumb.js out.jpg` で書き出す。

## 納品

- 完成 MP4 のパス、長さ、シーン構成を 1 行ずつ報告する
- LP に埋め込む場合は `public/assets/video/intro.mp4` に置き、`<video>` の `src` に `?v=N` を付けてキャッシュを切る（自社配信、YouTube は使わない）

## 参考実装

- `~/projects/baysync/docs/promo/video/`（slides.html = LP 流用 6 シーン、render.js、capture-lp.js、thumbnail.html）
- 完成例: `~/Desktop/eベイブリッジ紹介動画.mp4`、LP 埋め込み版 `eベイブリッジ_LP版_v4.mp4`（66 秒）
