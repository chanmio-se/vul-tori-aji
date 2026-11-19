# セットアップ手順（Phase 1）

## 1. 集約リポジトリを用意する

このディレクトリを `mioarai/vul-tori-aji` というリポジトリに push します。

```bash
git init
git add .
git commit -m "chore: initial CVE triage scaffolding"
git remote add origin git@github.com:mioarai/vul-tori-aji.git
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

より安全にしたい場合は GitHub App を導入し、`actions/create-github-app-token` で都度トークンを発行する構成に差し替えてください（Phase 2 以降の改善候補）。

## 4. プライベート Docker イメージをスキャンする場合（任意）

GHCR などのプライベートイメージをスキャンするリポジトリでは、追加で 2 つの secret を登録します。

- `REGISTRY_USERNAME`
- `REGISTRY_PASSWORD`（PAT や GITHUB_TOKEN。読み取り権限のみで可）

`registry` input でレジストリホストを指定します（既定値 `ghcr.io`）。公開イメージのみなら不要です。

## 5. 各リポジトリに呼び出し用 workflow を追加する

`examples/` を参考に、対象リポジトリの `.github/workflows/cve-scan.yml` を作成します。

| リポジトリ種別 | 参考ファイル | ポイント |
|---|---|---|
| Rails アプリ | `examples/rails-app.yml` | `scan_type: fs`。`Gemfile.lock` を Trivy が検出します |
| Ubuntu ベースイメージ | `examples/ubuntu-image.yml` | `scan_type: both`。`image_refs` にイメージを列挙 |
| nginx 設定 | `examples/nginx-config.yml` | `enable_misconfig: true` で設定不備も検出 |

`target_name` は集約リポジトリ内の `results/<target_name>/` になる一意な名前を付けてください（リポジトリ名推奨）。

確認のため、まずは `workflow_dispatch` から手動実行します。

```bash
gh workflow run cve-scan.yml --repo mioarai/rails-app
```

## 6. 成果物の確認

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
```

- `history/` は実行ごとのスナップショットです。`keep_snapshots`（既定 30）を超えるものは自動削除されます。
- 各リポジトリの Actions ページからも `trivy-<target_name>` という artifact としてダウンロードできます（保持 30 日）。

## 開発・テスト

実装は Ruby の小さなモジュールに分割しています。

```text
lib/cve_triage/         # 設定、Trivy 呼び出し、レポート生成、git 公開などのモジュール
bin/scan                # スキャン実行
bin/summarize           # summary.md / meta.json 生成
bin/publish             # 集約リポジトリへのコミット
spec/                   # RSpec（fixtures を含む）
```

```bash
bundle install
bundle exec rspec
```

依存はテスト用の RSpec のみで、ランタイムは Ruby 標準ライブラリだけを使います（`jq` は不要）。

## 注意点

- **CVE のトリアージ（AI 調査・優先度付け）は Phase 2 以降です。** Phase 1 では検出と可視化のみ行います。GitHub Models の利用も Phase 2 からです。
- `on.schedule` は既定ブランチでしか動きません。また、リポジトリが 60 日間アクティビティがないと GitHub がスケジュールを停止します。
- 2026-03 の Trivy エコシステムのサプライチェーン攻撃を受け、Trivy 本体は `v0.76.2` に固定しています。Action 側は `actions.lock` で固定します。更新時はリリースノートを確認してください。
- 成果物には脆弱性情報が含まれます。集約リポジトリを private にする、必要に応じてアクセス制限をかけることを推奨します。
