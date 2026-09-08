# claude-skills

Claude Code の個人スキル置き場。複数PCで共有するためのリポジトリ。

## 収録スキル

| スキル | 用途 |
|---|---|
| `slide-deck` | 記事・原稿を動画用スライドにする（構成→ChatGPT画像生成→Canva→読み上げ台本） |

## 別PCでのセットアップ

```sh
git clone https://github.com/modinc01/claude-skills.git ~/.claude/skills
```

すでに `~/.claude/skills` がある場合は、中身を退避してから clone する。

## 更新のやりとり

```sh
cd ~/.claude/skills
git pull            # 他PCの変更を取り込む
git add -A && git commit -m "..." && git push   # こちらの変更を送る
```

スキルはファイルを置くだけで有効になる。再起動も設定変更も不要。
