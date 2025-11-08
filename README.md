<h1 align="center">
  <br>
  <a href="http://thebored.name"><img src="https://framerusercontent.com/images/RFK4vs0kn8pRMuOO58JeyoemXA.png?scale-down-to=256" alt="Boring Notch" width="150"></a>
  <br>
  Boring Notch
  <br>
</h1>


<p align="center">
  <a title="Crowdin" target="_blank" href="https://crowdin.com/project/boring-notch"><img src="https://badges.crowdin.net/boring-notch/localized.svg"></a>
  <img src="https://github.com/TheBoredTeam/boring.notch/actions/workflows/cicd.yml/badge.svg" alt="TheBoringNotch Build & Test" style="margin-right: 10px;" />
  <a href="https://discord.gg/c8JXA7qrPm">
    <img src="https://dcbadge.limes.pink/api/server/https://discord.gg/c8JXA7qrPm?style=flat" alt="Discord Badge" />
  </a>
</p>

<!--Welcome to **Boring.Notch**, the coolest way to make your MacBook's notch the star of the show! Forget about those boring status bars—our notch turns into a dynamic music control center, complete with a snazzy visualizer and all the music controls you need. It's like having a mini concert right at the top of your screen! -->

**Boring Notch**へようこそ！MacBookのノッチを主役にする最高の方法です！退屈なステータスバーとはおさらば。Boring Notchを使えば、ノッチが鮮やかなビジュアライザーと必要な音楽コントロールを備えたダイナミックな音楽コントロールセンターに変身します。しかし、これは始まりにすぎません！Boring Notchは、カレンダー統合、AirDropサポート付きの便利なファイルシェルフなど、さらに多くの機能を提供します！

<p align="center">
  <img src="https://github.com/user-attachments/assets/2d5f69c1-6e7b-4bc2-a6f1-bb9e27cf88a8" alt="Demo GIF" />
</p>

<!--https://github.com/user-attachments/assets/19b87973-4b3a-4853-b532-7e82d1d6b040-->
---
<!--## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Roadmap](#-roadmap)
- [Building from Source](#building-from-source)
- [Contributing](#-contributing)
- [Join our Discord Server](#join-our-discord-server)
- [Star History](#star-history)
- [Buy us a coffee!](#buy-us-a-coffee)
- [Acknowledgments](#-acknowledgments)-->

## インストール

**システム要件:**
- macOS **14 Sonoma** 以降
- Apple Silicon または Intel Mac

---
> [!IMPORTANT]
> まだApple Developer アカウントを持っていません。初回起動時に、未確認の開発元からのアプリケーションであることを示すポップアップが表示されます。
> 1. **OK** をクリックしてポップアップを閉じます。
> 2. **システム設定** > **プライバシーとセキュリティ** を開きます。
> 3. 下にスクロールして、アプリに関する警告の横にある **このまま開く** をクリックします。
> 4. プロンプトが表示されたら選択を確認します。
>
> これは一度だけ行う必要があります。


### オプション1: 手動でダウンロードしてインストール
<a href="https://github.com/TheBoredTeam/boring.notch/releases/latest/download/boringNotch.dmg" target="_self"><img width="200" src="https://github.com/user-attachments/assets/e3179be1-8416-4b8a-b417-743e1ecc67d6" alt="Download for macOS" /></a>

---

### オプション2: Homebrew経由でインストール

[Homebrew](https://brew.sh)を使用してアプリをインストールすることもできます：

```bash
brew install --cask TheBoredTeam/boring-notch/boring-notch --no-quarantine
```

## 使い方

- アプリを起動すれば、ノッチが画面で最もクールな部分になります。
- ノッチの上にカーソルを合わせると、展開してすべての機能が表示されます。
- コントロールを使用してロックスターのように音楽を管理しましょう。

## 📋 ロードマップ
- [x] 再生ライブアクティビティ 🎧
- [x] カレンダー統合 📆
- [x] ミラー 📷
- [x] 充電インジケーターと現在のパーセンテージ 🔋
- [x] カスタマイズ可能なジェスチャー制御 👆🏻
- [x] AirDrop対応のシェルフ機能 📚
- [x] ノッチサイズのカスタマイズ、さまざまなディスプレイサイズでの微調整 🖥️
- [ ] リマインダー統合 ☑️
- [ ] カスタマイズ可能なレイアウトオプション 🛠️
- [ ] 拡張システム 🧩
- [ ] システムHUD置き換え（音量、輝度、バックライト）🎚️💡⌨️
- [ ] 通知（検討中）🔔
<!-- - [ ] Clipboard history manager 📌 `Extension` -->
<!-- - [ ] Download indicator of different browsers (Safari, Chromium browsers, Firefox) 🌍 `Extension`-->
<!-- - [ ] Customizable function buttons 🎛️ -->
<!-- - [ ] App switcher 🪄 -->

<!-- ## 🧩 Extensions
> [!NOTE]
> We’re hard at work on some awesome extensions! Stay tuned, and we’ll keep you updated as soon as they’re released. -->

## ソースからビルド

### 前提条件

- **macOS 14以降**: 最新のmacOSを使用していない場合は、捜索隊を送る必要があるかもしれません。
- **Xcode 16以降**: ここで魔法が起こるので、最新の状態であることを確認してください。

### インストール

1. **リポジトリをクローン**:
   ```bash
   git clone https://github.com/TheBoredTeam/boring.notch.git
   cd boring.notch
   ```

2. **Xcodeでプロジェクトを開く**:
   ```bash
   open boringNotch.xcodeproj
   ```

3. **ビルドして実行**:
    - 「実行」ボタンをクリックするか、`Cmd + R` を押します。魔法が展開するのを見守りましょう！

## 🤝 コントリビューション

私たちは良い雰囲気と素晴らしい貢献を大切にしています！参加方法は次のとおりです：

1. **リポジトリをフォーク**: 光り輝く「Fork」ボタンをクリックして、自分のバージョンを作成します。
2. **フォークをクローン**:
   ```bash
   git clone https://github.com/{your-name}/boring.notch.git
   # {your-name}をあなたのGitHubユーザー名に置き換えてください
   ```
3. **ベースとして `dev` ブランチを使用してください。**
4. **新しいブランチを作成**:
   ```bash
   git checkout -b feature/{your-feature-name}
   # {your-feature-name}をブランチの説明的で簡潔な名前に置き換えてください
   # 英数字のみを使用し、単語を小文字で書き、単語をハイフン1つで区切るのがベストプラクティスです
   ```
5. **変更を加える**: 機能を追加するか、バグを修正します。
6. **変更をコミット**:
   ```bash
   git commit -m "わかりやすいメッセージをここに挿入"
   ```
7. **フォークにプッシュ**:
   ```bash
   git push origin feature/{your-feature-name}
   # 選択した名前に {your-feature-name} を置き換えることを忘れないでください
   ```
8. **プルリクエストを作成**: 元のリポジトリに移動し、「New Pull Request」をクリックします。必要な詳細を入力し、**ベースブランチが `dev` に設定されていることを確認**して、PRを送信します。あなたの作品を見せてください！

## Discordサーバーに参加

<a href="https://discord.gg/GvYcYpAKTu" target="_blank"><img src="https://iili.io/28m3GHv.png" alt="Join The Boring Server!" style="height: 60px !important;width: 217px !important;" ></a>

## スター履歴

<a href="https://www.star-history.com/#TheBoredTeam/boring.notch&Timeline">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=TheBoredTeam/boring.notch&type=Timeline&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=TheBoredTeam/boring.notch&type=Timeline" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=TheBoredTeam/boring.notch&type=Timeline" />
 </picture>
</a>

## コーヒーをおごってください！

<a href="https://www.buymeacoffee.com/jfxh67wvfxq" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-red.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## 🎉 謝辞

Boring Notchの「シェルフ」機能の開発に尽力してくれた、オープンソースプロジェクトである[NotchDrop](https://github.com/Lakr233/NotchDrop)の開発者に感謝の意を表します。NotchDropへの貢献に対するLakr233、およびプロジェクトへの統合を行った[Hugo Persson](https://github.com/Hugo-Persson)に特別な感謝を捧げます。

### アイコンクレジット: [@maxtron95](https://github.com/maxtron95)
### ウェブサイトクレジット: [@himanshhhhuv](https://github.com/himanshhhhuv)

- **SwiftUI**: 私たちをコーディングの魔法使いのように見せてくれてありがとう。
- **あなた**: 素晴らしい人で、**boring.notch**をチェックしてくれてありがとう！


