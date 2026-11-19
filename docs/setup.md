# セットアップ手順（Phase 1 + Phase 2）

## 1. 集約リポジトリを用意する

このディレクトリを `<OWNER>/vul-tori-aji` というリポジトリに push します（`<OWNER>` は自分のアカウントまたは Org に読み替えてください）。

```bash
git init
git add .
git commit -m "chore: initial CVE triage scaffolding"
git remote add origin git@github.com:<OWNER>/vul-tori-aji.git
git push -u origin main
```

集約リポジトリを **private** にする場合、各サービスリポジトリから reusable workflow を呼び出すには、Org のプランで private reusable workflow が利用できること、および呼び出し元が集約 repo への read 権限を持つことを確認してください（公開 repo なら追加設定不要）。

## 2. Actions の依存を lockfile に固定する

GitHub Actions の [workflow dependency lockfiles](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles) を使い、直接・推移的な Action 依存を commit に固定します。

```bash
gh auth login                              # github.com で認証
gh extension install github/gh-actions-lock
gh actions-lock                            # .github/workflows/actions.lock を生成
git add .github/workflows/
git commit -m "chore: lock GitHub Actions dependencies"
git push
```

`gh actions-lock` は工作流の `uses:` を読みやすいタグのままにしつつ、実際に動く commit を lockfile に記録します。生成されたファイルは手で編集せず、必ずこのコマンドで更新してください。

Workflow を追加・変更したら再実行します。CI の `verify-lockfile` job が `--verify` で同期をチェックします。

> **重要**: lockfile は **reusable workflow の呼び出し（`jobs.<id>.uses`）を固定しません**。各呼び出し元では `@<COMMIT_SHA>` のように、集約 workflow を commit SHA で指定してください（`examples/` を参照）。

## 3. 集約リポジトリへ書き込むトークンを作る

reusable workflow は呼び出し元リポジトリのコンテキストで動くため、呼び出し元の `GITHUB_TOKEN` では集約リポジトリへ書き込めません。専用のトークンを用意します。

**Fine-grained personal access token** を推奨します。

| 項目 | 設定 |
|---|---|
| Resource owner | 自分の Org / アカウント |
| Repository access | **Only select repositories** → `vul-tori-aji` のみ |
| Permissions → Contents | **Read and write** |
| Permissions → Metadata | Read（自動で付与される） |
| Expiration | 例: 90 日（ローテーション運用する） |

トークンを、**スキャン対象の全リポジトリ**の Secrets に `CENTRAL_REPO_TOKEN` という名前で登録します。

- Settings → Secrets and variables → Actions → New repository secret
- 集約リポジトリ自身もスキャンするなら、集約リポジトリにも同じ secret を登録してください。

より安全にしたい場合は GitHub App を導入し、`actions/create-github-app-token` で都度トークンを発行する構成に差し替えてください（改善候補）。

## 4. Copilot 枠（AI トリアージ）の準備

Phase 2 の AI 調査は **GitHub Copilot CLI** を Actions から programmatic mode（`-p`）で呼び出して行います。利用量は Copilot の枠（GITHUB_TOKEN 認証時は Org 課金）に計上されます。GitHub Models は 2026-07-30 に廃止されたため使いません。

1. Org の Copilot ポリシーで **Allow use of Copilot CLI billed to the organization** が有効か確認します（Copilot CLI が有効な Org では既定で有効）。
2. 呼び出し元 workflow に次の permission を付与します（`examples/` に記載済み）。reusable workflow は呼び出し元以上の権限を要求できないため、ここでの設定が必須です。

   ```yaml
   permissions:
     contents: read
     packages: read
     copilot-requests: write
   ```

3. `triage_model` input でモデルを指定できます（既定 `claude-haiku-4.5`）。`/model` で表示される文字列を指定してください。
4. 一時的に止めたい場合は `enable_triage: false` を渡します。差分検出（`diff.json` / `diff.md`）はそのまま動きます。

Copilot にはファイル読み書きやシェル実行の権限を与えず、CVE 情報だけをプロンプトに埋め込んで JSON を返させています。CVE のタイトル等は信頼できない入力として扱うよう明示しています。

## 5. プライベート Docker イメージをスキャンする場合（任意）

GHCR などのプライベートイメージをスキャンするリポジトリでは、追加で 2 つの secret を登録します。

- `REGISTRY_USERNAME`
- `REGISTRY_PASSWORD`（PAT や GITHUB_TOKEN。読み取り権限のみで可）

`registry` input でレジストリホストを指定します（既定値 `ghcr.io`）。公開イメージのみなら不要です。

## 6. 各リポジトリに呼び出し用 workflow を追加する

`examples/` を参考に、対象リポジトリの `.github/workflows/cve-scan.yml` を作成します。

| リポジトリ種別 | 参考ファイル | ポイント |
|---|---|---|
| Rails アプリ | `examples/rails-app.yml` | `scan_type: fs`。`Gemfile.lock` を Trivy が検出します |
| Ubuntu ベースイメージ | `examples/ubuntu-image.yml` | `scan_type: both`。`image_refs` にイメージを列挙 |
| nginx 設定 | `examples/nginx-config.yml` | `enable_misconfig: true` で設定不備も検出 |

`<OWNER>` と `<COMMIT_SHA>` は実際の値に置き換えてください。`central_repo` は必須 input なので、呼び出し元から必ず渡します。`target_name` は集約リポジトリ内の `results/<target_name>/` になる一意な名前を付けてください（リポジトリ名推奨）。

確認のため、まずは `workflow_dispatch` から手動実行します。

```bash
gh workflow run cve-scan.yml --repo <OWNER>/rails-app
```

## 7. 成果物の確認

実行後、集約リポジトリに次の内容がコミットされます。

```text
results/
  rails-app/
    latest.md          # 直近のスキャン概要（Markdown）
    latest.json        # 直近のメタデータ（CVE 件数など）
    history/
      20261119T180000Z-1234567890/
        vuln-fs.json
        sbom-fs.cdx.json
        misconfig-fs.json
        vuln-image-....json
        sbom-image-....cdx.json
        summary.md
        meta.json
        diff.json          # 前回との added / updated / removed
        diff.md
        triage.json        # Copilot による優先度・根拠・推奨対応
        triage.md
```

- `history/` は実行ごとのスナップショットです。`keep_snapshots`（既定 30）を超えるものは自動削除されます。
- 初回実行には前回スナップショットがないため、全件が `added` として扱われます（`first_run: true`）。
- 差分キーは「成果物ファイル + Trivy Target + CVE ID + パッケージ + インストール済みバージョン」です。修正版や重要度、タイトルが変わると `updated` になります。
- Copilot の呼び出しに失敗してもスキャン結果は失われません。`triage.json` に `status: "error"` と理由が書き込まれます。
- 各リポジトリの Actions ページからも `trivy-<target_name>` という artifact としてダウンロードできます（保持 30 日）。

## 開発・テスト

実装は Ruby の小さなモジュールに分割しています。

```text
lib/cve_triage/         # 設定、Trivy、レポート、差分、AI、git 公開などのモジュール
bin/scan                # スキャン実行
bin/summarize           # summary.md / meta.json 生成
bin/diff                # 直前スナップショットとの差分を生成
bin/triage              # Copilot で新規・更新 CVE をトリアージ
bin/publish             # 集約リポジトリへのコミット
spec/                   # RSpec（fixtures を含む）
```

```bash
bundle install
bundle exec rspec
```

依存はテスト用の RSpec のみで、ランタイムは Ruby 標準ライブラリだけを使います（`jq` は不要）。

## 注意点

- Phase 1 は検出と可視化、Phase 2 は差分検出と Copilot によるトリアージです。Issue/PR 作成（Phase 4）や継続監視（Phase 5）は未実装です。
- `on.schedule` は既定ブランチでしか動きません。また、リポジトリが 60 日間アクティビティがないと GitHub がスケジュールを停止します。
- 2026-03 の Trivy エコシステムのサプライチェーン攻撃を受け、Trivy 本体は `v0.76.2` に固定しています。Action 側は `actions.lock` で固定します。更新時はリリースノートを確認してください。
- 成果物には脆弱性情報が含まれます。集約リポジトリを private にする、必要に応じてアクセス制限をかけることを推奨します。
