# プロジェクトルール

## セッション管理

- ユーザーが「exit」「終了」「おわり」などセッション終了を依頼したら、**必ず CLAUDE.md の「セッション記録」セクションを最新の状態に更新してから**終了すること
  - 完了した作業を「完了済みの作業」に追記
  - 次にやるべきことがあれば「これからやってほしい作業」を更新
  - 現在の状態（ブランチ、未コミットの変更など）を更新

- セッション開始時、最初の応答で必ずセッション記録を確認し、前回の状況を簡潔に要約してからユーザーの指示を待つこと（ユーザーに言われなくても自動で行う）

## 言語

- ユーザーとの会話は日本語で行う

---

# セッション記録

## プロジェクト概要
- iOS/iPadOS向けアプリ
- 写真を最大4枚選択し、A4用紙1ページに2x2で配置してPDFを生成する
- 生成したPDFをプレビュー・共有（印刷）できる

## 完了済みの作業

1. Xcodeプロジェクト作成（Initial Commit）

2. 主要機能の実装（未コミット）
   - ContentView.swift: PhotosPickerで写真選択、A4プレビューグリッド表示、PDF生成ボタン
   - PDFGenerator.swift: A4サイズ(595.28x841.89pt)のPDF生成、マージン5mm、
     横長写真の自動回転、大きい画像のダウンサンプリング(3000px上限)、アスペクト比維持配置
   - PDFPreviewView.swift: PDFKitによるプレビュー表示、共有シート（印刷・AirDrop等）

3. Claude Code の設定
   - ~/.claude/settings.json にフック設定済み
     - Stop: 応答完了時に Glass.aiff を再生
     - Notification: 選択肢表示時に Glass.aiff を再生
   - swift-lsp プラグイン有効化済み

4. Google AdMob インタースティシャル広告の統合（コード実装済み、SPMパッケージ追加は未実施）
   - Info.plist: GADApplicationIdentifier、ATS設定
   - AdInterstitialManager.swift: 広告管理クラス（ロード・表示・自動リロード）
   - A4PrintPDFApp.swift: AppDelegate追加、MobileAds SDK初期化
   - ContentView.swift: PDF生成後に広告表示→プレビュー遷移のフロー
   - project.pbxproj: INFOPLIST_FILE設定追加

5. Fastlane による TestFlight 配布・App Store 提出の自動化
   - Homebrew で Ruby 4.0.1 をインストール
   - Gemfile 作成、bundle install（vendor/bundle にインストール）
   - fastlane/Appfile: Bundle ID、Team ID 設定
   - fastlane/Fastfile: create_app / screenshots / beta / release の4レーン
   - fastlane/Snapfile: iPhone 16 Pro Max / iPad Pro 13-inch (M4)、日本語
   - fastlane/Deliverfile: 無料、自動リリース、IDFA 申告設定
   - fastlane/rating_config.json: 年齢レーティング設定（全項目0）
   - fastlane/metadata/ja/: name, subtitle, description, keywords, privacy_url, support_url, promotional_text, release_notes
   - docs/privacy-policy.html: プライバシーポリシー（GitHub Pages 用）
   - A4PrintPDFUITests/A4PrintPDFUITests.swift: スクリーンショット撮影用 UI テスト
   - .gitignore: vendor/bundle, fastlane 出力, Xcode ビルド等を除外

## 現在の状態
- mainブランチ、Initial Commitの上に未コミットの変更あり
- アプリの基本機能＋AdMob広告統合のコードは実装済み
- Fastlane 環境構築済み（Fastlane 2.232.0）
- **SPMパッケージ追加がまだ**（Xcode UIで手動操作が必要）

## これからやってほしい作業
- XcodeでSPMパッケージを追加: `https://github.com/googleads/swift-package-manager-google-mobile-ads` → `GoogleMobileAds` を `A4PrintPDF` ターゲットに追加
- Xcode で UI Testing Bundle ターゲット `A4PrintPDFUITests` を追加（File → New → Target → UI Testing Bundle）
- `bundle exec fastlane snapshot init` で SnapshotHelper.swift を生成し、UI テストターゲットに追加
- fastlane/Appfile の `apple_id` にApple IDメールアドレスを設定
- docs/privacy-policy.html の連絡先メールアドレスを確認・修正
- GitHub にリポジトリを push → GitHub Pages を docs/ ディレクトリで公開
- `bundle exec fastlane create_app` で App Store Connect にアプリ作成
- ビルド確認・シミュレータでの動作テスト
- `bundle exec fastlane beta` で TestFlight 配布テスト
- 本番リリース時: テスト用Ad ID（`ca-app-pub-3940256099942544~1458002511` / `ca-app-pub-3940256099942544/1033173712`）をAdMobコンソールの実IDに差し替え

## Fastlane 使用時の注意
- Homebrew Ruby を使うため、PATH に `/usr/local/opt/ruby/bin` を含める必要あり
- `export PATH="/usr/local/opt/ruby/bin:/usr/local/lib/ruby/gems/4.0.0/bin:$PATH"` を実行してから `bundle exec fastlane ...` を実行
- または .bash_profile / .zshrc に上記 PATH を追加
