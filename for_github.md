# AlarmWeatherApp を自分の GitHub にアップロードする手順

このプロジェクトはローカルでは Git 管理されていますが、現時点では GitHub の保存先 remote が設定されていません。

対象ディレクトリ:

```bash
/Users/mikael/docs/AlarmWeatherApp
```

現在のブランチ:

```bash
main
```

## 1. プロジェクトフォルダへ移動する

```bash
cd /Users/mikael/docs/AlarmWeatherApp
```

## 2. 現在の変更状態を確認する

```bash
git status
```

現在、以下のような未コミット変更があります。

```text
modified: AlarmWeatherApp/AppState.swift
modified: AlarmWeatherApp/ContentView 2.swift
```

GitHub に上げる前に、この変更をコミットするか判断してください。

## 3. 変更内容をコミットする

変更内容をすべてコミットする場合:

```bash
git add .
git commit -m "Update app files"
```

もし一部のファイルだけコミットしたい場合は、`git add .` の代わりに対象ファイルを指定します。

```bash
git add AlarmWeatherApp/AppState.swift
git add "AlarmWeatherApp/ContentView 2.swift"
git commit -m "Update app files"
```

## 4. GitHub で新しいリポジトリを作成する

GitHub にログインし、新しいリポジトリを作成します。

例:

```text
Repository name: AlarmWeatherApp
Visibility: Public または Private
```

注意:

- README、.gitignore、license は GitHub 側で追加しない方が安全です。
- すでにローカルに Git 履歴があるため、空のリポジトリとして作成してください。

## 5. GitHub の remote URL を確認する

GitHub でリポジトリを作成すると、次のような URL が表示されます。

HTTPS の例:

```text
https://github.com/YOUR_USERNAME/AlarmWeatherApp.git
```

SSH の例:

```text
git@github.com:YOUR_USERNAME/AlarmWeatherApp.git
```

`YOUR_USERNAME` は自分の GitHub ユーザー名に置き換えてください。

## 6. ローカル Git に GitHub の保存先を登録する

HTTPS を使う場合:

```bash
git remote add origin https://github.com/YOUR_USERNAME/AlarmWeatherApp.git
```

SSH を使う場合:

```bash
git remote add origin git@github.com:YOUR_USERNAME/AlarmWeatherApp.git
```

登録できたか確認します。

```bash
git remote -v
```

期待される表示例:

```text
origin  https://github.com/YOUR_USERNAME/AlarmWeatherApp.git (fetch)
origin  https://github.com/YOUR_USERNAME/AlarmWeatherApp.git (push)
```

## 7. GitHub に push する

```bash
git push -u origin main
```

これで、ローカルの `main` ブランチが GitHub の `main` ブランチにアップロードされます。

## 8. GitHub 上で確認する

ブラウザで GitHub のリポジトリページを開き、以下を確認します。

- `AlarmWeatherApp`
- `AlarmWeatherApp.xcodeproj`
- `AlarmWeatherAppTests`
- `AlarmWeatherAppUITests`
- コミット履歴

## 2回目以降の更新手順

一度 `origin` を設定した後は、通常は以下だけで更新できます。

```bash
cd /Users/mikael/docs/AlarmWeatherApp
git status
git add .
git commit -m "Update"
git push
```

## よくあるエラー

### remote origin already exists

すでに `origin` が登録されている場合に出ます。

確認:

```bash
git remote -v
```

URL を変更したい場合:

```bash
git remote set-url origin https://github.com/YOUR_USERNAME/AlarmWeatherApp.git
```

### Authentication failed

HTTPS で push する場合、GitHub のパスワードではなく Personal Access Token が必要になることがあります。

SSH を使う場合は、GitHub に SSH key が登録されている必要があります。

### Updates were rejected

GitHub 側に README などを作ってしまい、ローカルと GitHub の履歴が違う場合に出ることがあります。

この場合は状況によって対応が変わるため、エラーメッセージを確認してから作業してください。
