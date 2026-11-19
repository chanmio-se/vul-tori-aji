# vul-tori-aji

CVE トリアージ基盤。**Phase 1（資産の可視化）と Phase 2（差分検出 + AI トリアージ）** を実装しています。

## 構成

```text
┌─────────────────────┐   workflow_call    ┌──────────────────────────┐
│ Rails app repo      │ ──────────────────▶ │ vul-tori-aji (集約 repo)  │
│ Ubuntu image repo   │ ──────────────────▶ │  reusable workflow       │
│ nginx config repo   │ ──────────────────▶ │  results/<target>/...    │
└─────────────────────┘                    └──────────────────────────┘
        GITHUB_TOKEN で自 repo を checkout      CENTRAL_REPO_TOKEN で成果物を commit
```

- 各サービスリポジトリは、集約リポジトリにある `.github/workflows/trivy-scan.yml` を `workflow_call` で呼び出します。
- スキャン対象はリポジトリ（`Gemfile.lock` 等の依存関係、Dockerfile、nginx.conf など）と Docker イメージ（Ubuntu ベースイメージ等）です。
- 成果物（脆弱性 JSON + CycloneDX SBOM + サマリ + 差分 + トリアージ結果）は集約リポジトリの `results/<target_name>/` に毎日コミットされます。
- 新規・更新 CVE だけを Copilot の利用枠で調査し、優先度（P0〜P3）・根拠・推奨対応を付与します。
- 実装言語は Ruby（標準ライブラリのみ）。テストは RSpec です。

## ファイル

| パス | 内容 |
|---|---|
| `.github/workflows/trivy-scan.yml` | 共通スキャン用 reusable workflow |
| `.github/workflows/verify-lockfile.yml` | Actions 依存 lockfile の検証 |
| `lib/cve_triage/` | 設定・Trivy 呼び出し・レポート生成・git 公開などのモジュール |
| `bin/scan`, `bin/summarize`, `bin/diff`, `bin/triage`, `bin/publish` | workflow から呼ぶエントリーポイント |
| `spec/` | RSpec とフィクスチャ |
| `examples/` | リポジトリ種別ごとの呼び出し元 workflow 例 |
| `docs/setup.md` | セットアップ手順 |

## はじめに

[docs/setup.md](docs/setup.md) を参照してください。概要は次のとおりです。

1. このリポジトリを `<OWNER>/vul-tori-aji` に push する
2. `gh actions-lock` で `.github/workflows/actions.lock` を生成・コミットする
3. 集約リポジトリにだけ書き込める `CENTRAL_REPO_TOKEN` を作り、各対象 repo の Secrets に登録する
4. Org の Copilot ポリシーで CLI の利用（Org 課金）を有効にする
5. `examples/` を参考に各対象 repo へ workflow を追加する（reusable workflow は commit SHA で固定）
6. `workflow_dispatch` で手動実行し、`results/` を確認する

## 開発

```bash
bundle install
bundle exec rspec
```

## 成果物の例

```text
results/rails-app/
├── latest.md
├── latest.json
└── history/20261119T180000Z-1234567890/
    ├── summary.md
    ├── meta.json
    ├── vuln-fs.json
    ├── sbom-fs.cdx.json
    ├── misconfig-fs.json
    ├── diff.json
    ├── diff.md
    ├── triage.json
    └── triage.md
```

## セキュリティ

- 2026-03 の Trivy エコシステムのサプライチェーン攻撃（GHSA-69fq-xp46-6x23）を踏まえ、Trivy 本体は固定バージョン（`v0.76.2`）を使用しています。
- GitHub Actions の依存は `.github/workflows/actions.lock` で commit に固定し、CI で検証します。lockfile は **reusable workflow の呼び出しを対象外** とするため、呼び出し元では `@<COMMIT_SHA>` を使ってください。
- Copilot CLI は `GITHUB_TOKEN` で認証し、tool 権限を与えずにプロンプトだけで応答させます。CVE データは信頼できない入力として扱うよう指示しています。

## ロードマップ

- [x] **Phase 1**: Trivy でリポジトリ / Docker イメージをスキャンし、SBOM を生成
- [x] **Phase 2**: 毎日実行し、新規・更新 CVE を検出して Copilot 枠でトリアージする（GitHub Models は廃止済み）
- [ ] **Phase 3**: Ubuntu / nginx / MySQL / AWS の公式情報統合
- [ ] **Phase 4**: P0〜P2 を GitHub Issue 化し、可能なら AI が PR を作成
- [ ] **Phase 5**: 再発・修正漏れ・期限超過の継続監視
