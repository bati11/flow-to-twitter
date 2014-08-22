Flow to Twitter
====

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

GitHubのNews FeedをTwitterに投稿するツールです。

## 使い方
cloneしてスクリプトを実行するか、Herokuにデプロイして使います。上記のHerokuボタンを使うと簡単にHeroku上にデプロイできます。

どちらにしろ、GitHubのPersonal Access TokenとTwitter botのAPI Keysを環境変数に設定します。
ローカルにcloneした場合は`bundle install --path vendor/bundle`でセットアップした後、以下のコマンドで実行できます。

```
$ bundle exec ruby batch.rb
```

Herokuにデプロイした場合は、以下のコマンドをHeroku Schedulerに登録してください。

```
$ ruby batch.rb
```

