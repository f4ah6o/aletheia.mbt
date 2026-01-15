# Aletheia - MoonBit Property-Based Testing Tool

Property-Based Testing (PBT) コード生成ツール for MoonBit。

## 概要

Aletheia は MoonBit ソースコードから自動的にプロパティベーステストを生成するツールです。

- **パターン検出**: Round-Trip, Idempotent, Producer-Consumer パターンを自動検出
- **テスト生成**: 検出されたパターンに基づいて PBT コードを自動生成
- **PBT同期**: `<module>.pbt.mbt.md` のコードブロックをパッケージごとのテストに同期
- **Dogfooding**: ツール自身の品質を自己検証

## 現在のステータス

### ✅ 実装済み

| モジュール | 説明 | 状態 |
|-----------|------|------|
| `parser` | Markdownパーサー | ✅ 完了 |
| `patterns` | パターン検出 | ✅ 完了 |
| `generator` | PBTコード生成 | ✅ 完了 |
| `cli` | CLIコマンドパーサー | ✅ 完了 |
| `analyzer` | 関数抽出器 | ✅ 完了 |
| `pbt` | PBTランタイム | ✅ 完了 |
| `pbt_sync` | PBT同期 | ✅ 完了 |
| `dogfooding` | 自己テスト | ✅ 完了 |
| `state_machine` | 状態マシンテスト | ✅ 完了 |

### テスト状況

- **総テスト数**: 50
- **パス率**: 100%

## 実行方法

```bash
# 全テスト実行
moon test

# ビルド確認
moon check

# CLI実行（ヘルプ表示）
moon run src/aletheia

# PBTターゲット収集
moon run src/aletheia -- generate ./src

# 変更内容のサマリをJSONで出力（dry-run）
moon run src/aletheia -- generate ./src --dry-run --format json

# 検出根拠の詳細表示
moon run src/aletheia -- analyze ./src --explain

# PBT markdown同期（デフォルト: src/aletheia.pbt.mbt.md）
moon run src/aletheia -- sync
# 自己適用PBTの生成（テンプレート出力）
./scripts/self_pbt.sh
# self_pbt.sh は generate/sync + moon info + moon fmt を実行

# 開発時の一括チェック
./scripts/dev-check.sh
```

## Claude Code Plugin

```bash
# ローカルでプラグインを試す
claude --plugin-dir ./plugins/aletheia-self-pbt

# マーケットプレイスを追加してインストール（Claude Code内）
/plugin marketplace add .
/plugin install aletheia-self-pbt@f4ah6o-plugins
```

## モジュール構成

```
src/
├── aletheia.pbt.mbt.md  # PBTターゲット/プロパティ集約
├── aletheia/       # CLI エントリポイント
├── analyzer/       # 関数抽出器
├── ast/            # AST定義
├── cli/            # CLI コマンド処理
├── dogfooding/     # 自己テスト（Dogfooding）
├── generator/      # PBT コード生成
├── parser/         # Markdown パーサー
├── patterns/       # パターン検出
├── pbt/            # PBTランタイム
├── pbt_sync/       # PBT同期
└── state_machine/  # 状態マシンテスト
```

## 制約事項

- **AST解析の精度**: 現在は簡易的な行スキャンのため、複雑なシグネチャや型推論には未対応
- **生成テストの調整**: 生成された `.pbt.mbt.md` はテンプレートとして扱い、必要に応じて型やプロパティを調整
- **生成マーカー**: `.pbt.mbt.md` に `<!-- aletheia:begin -->` と `<!-- aletheia:end -->` を挿入。手編集はマーカー外に書くと再生成で保持される
- **ワーニング**: ビルド時に未使用変数/関数に関する警告あり（機能に影響なし）

## ライセンス

Apache-2.0
