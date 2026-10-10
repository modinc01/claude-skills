---
name: slide-video
description: 記事・原稿を「ChatGPT で生成したスライド画像 ＋ 本人の声（Gemini TTS カスタムボイス たいせい）のナレーション」の MP4 動画にする。台本→ChatGPT で1枚ずつ画像生成→画像回収→TTS→ffmpeg で合成→UTAGE にアップロード。「スライド動画化して」「記事を動画にして」「講座動画を作って」と言われたら使う。HTML で自作のスライドは作らない。Canva 用スライドだけなら slide-deck。
---

# スライド動画化（ChatGPT 画像 ＋ TTS → MP4）

ゴールは **ナレーション入り MP4 を `~/Desktop/<タイトル>.mp4` に置き、UTAGE の該当レッスンに動画要素として入れること**。途中で確認を挟まず最後まで通す。

**やってはいけないこと**: HTML/CSS で自作スライドを作ること（2026-10-10 に「全く指示に従っていない」と差し戻し）。スライド画像は必ず ChatGPT で生成する。声は必ず「たいせい」。

## 手順

### 1. 台本
記事を 10〜15 シーンに分け、各シーンの「画像に載せる内容」と「ナレーション」を `script.md` に表で書く。ナレーションは話し言葉・短文。`narration.txt` に段落（空行区切り）で書き出す。

### 2. スライド画像（ChatGPT、1 枚ずつ、1 チャット 1 枚）
ユーザーの Chrome の chatgpt.com（Plus）で、**毎回新しいチャット**に次の定型を送る（Mac mini と同じ文面。`references/prompt-template.txt`）:

```
解説スライドの画像を1枚作ってください。
・白青基調
・フォントは Noto Sans JP
・横長16:9 (1920x1080)
・1枚1メッセージ。文字は大きく、遠くから読めるサイズ
・写真や人物イラストは使わない
・指定した文字列をそのまま正確に描画する。カギ括弧『』は描かない
・見出し、まとめ、などの項目名ラベルの文字は描かない
・メモリにある他案件の設定は無視する
レイアウトはお任せします。

見出し『…』
・…
・…
```

- 入力は `div[contenteditable=true]` に `document.execCommand('insertText')`（`computer type` は数字が欠ける）。送信は **JS で `button[type=submit]` を click**（ref クリックや Enter は効かないことがある）
- 生成は 40〜70 秒。`img` の naturalWidth>600 が出たら完了。「画像生成に失敗しました」が出たら「もう一度試す」を JS click
- 各チャットの URL を `chats.json` に控える（回収で戻るため）
- 待ちは 1 回の browser_batch を 40 秒以内に収める（長いとタイムアウト）

### 3. 画像の回収（ダウンロード → Finder でコピー）
window.name リレー・クリップボード・ページ内 fetch は **全部使えない**（Chrome が cross-site で window.name を消す／クリップボードは本人の作業と競合／CSP）。使えるのは **ChatGPT のダウンロードボタン**:

1. 事前に **ダウンロードの許可を本人にもらう**（ファイル数・サイズを明示）。Chrome の「連続ダウンロード」ブロックが出るので、chrome://settings/content/automaticDownloads で chatgpt.com を許可してもらう
2. 各チャットを開き、`button[aria-label="生成画像1"]` を JS click（ビューアーが開く）→ `[role=dialog]` 内の「ダウンロード」を JS click → ~/Downloads に `<見出し>.png`（1672×941）
3. ~/Downloads は Terminal から読めない（TCC）。**Finder の AppleScript で複製**する: `references/grab_latest.sh slideNN`（Downloads の最新 PNG を img/slideNN.png にコピー）。2 枚以上まとめて落としたときは名前で振り分ける
4. `ffmpeg -i img/slide%02d.png -vf "scale=480:-1,tile=4x4" contact.jpg` で一覧を作って **目視**（誤字・文字欠け・順番ズレ）

### 4. ナレーション（たいせい）
Google AI Studio https://aistudio.google.com/generate-speech（stox.japan@gmail.com）。
- 右上の鍵アイコン →「有料の API キーをリンク」→ プロジェクトを **Default Gemini Project** に変更 → キーを選択（これをしないとカスタムボイスが出ない）
- Create new dialog → Speaker → Custom voices の **「たいせい 講師ナレーション」**
- 段落ごとに生成（textarea は native setter + input、Run は **実クリック**）。音声は `<audio src="data:audio/wav;base64,…">`。取り出しはクリックイベント内 `navigator.clipboard.writeText(base64)` → `pbpaste | base64 -D > narr/sNN.wav`（本人がクリップボードを使っていない時間帯に）
- API キーがローカルにある場合は `references/tts.sh` でも可（カスタムボイスの API 指定は未確認）

### 5. 合成
`references/assemble.sh` をプロジェクトにコピーして実行。各スライドをナレーション長＋0.6 秒表示、0.5 秒クロスフェード、ごく弱いズーム。段落音声をスライド開始に合わせて配置して MP4 に。
```sh
./assemble.sh "$HOME/Desktop/<タイトル>.mp4"
ffmpeg -i out.mp4 -crf 27 -tune stillimage -b:a 64k -ac 1 <タイトル>_UTAGE用.mp4   # 10MB 以下にする（file_upload の上限）
```
`ffmpeg -ss 140 -i out.mp4 -frames:v 1 check.jpg` で 1 枚確認。

### 6. UTAGE にアップロード
`utage-video-lesson` メモリの手順どおり: 動画管理 `utage-system.com/media/video/{folderId}` → 新規アップロード（実クリック）→ #modal-upload の input#input-file に file_upload → 「アップロード」実クリック → 埋め込み URL → レッスンのビルダーで Vue データに `{type:'video',video_type:'app',video_url,…}` を挿入 → 保存は **座標クリック** → 再読み込みで確認。既存の動画要素を差し替えるときは `video_url` を書き換えるだけ。

## 納品
MP4 のパス・長さ・枚数、UTAGE のレッスン名を 1 行ずつ報告する。

## 参考実装
- `~/projects/mercari-course/videos/photo-tips/`（2026-10-11: 13 枚・4 分 39 秒、script.md / prompts.json / chats.json / img/ / narr/ / assemble.sh）
