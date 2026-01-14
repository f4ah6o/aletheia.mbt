# Aletheia - MoonBit Property-Based Testing Tool

Property-Based Testing (PBT) コード生成ツール for MoonBit。

## 概要

Aletheia は MoonBit ソースコードから自動的にプロパティベーステストを生成するツールです。

- **パターン検出**: Round-Trip, Idempotent, Producer-Consumer パターンを自動検出
- **テスト生成**: 検出されたパターンに基づいて PBT コードを自動生成
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
| `dogfooding` | 自己テスト | ✅ 完了 |
| `state_machine` | 状態マシンテスト | ✅ 完了 |

### テスト状況

- **総テスト数**: 41
- **パス率**: 100%

## 実行方法

```bash
# 全テスト実行
moon test

# ビルド確認
moon check

# CLI実行（ヘルプ表示）
moon run src/aletheia
```

## モジュール構成

```
src/
├── aletheia/       # CLI エントリポイント
├── analyzer/       # 関数抽出器
├── cli/            # CLI コマンド処理
├── dogfooding/     # 自己テスト（Dogfooding）
├── generator/      # PBT コード生成
├── parser/         # Markdown パーサー
├── patterns/       # パターン検出
└── state_machine/  # 状態マシンテスト
```

## 制約事項

- **AST解析**: 簡易版の文字列処理ベース（本格的な構文解析は未実装）
- **型推論**: 静的型チェック機能は未実装
- **ワーニング**: ビルド時に36個の未使用変数/関数に関する警告あり（機能に影響なし）

## ライセンス

Apache-2.0
