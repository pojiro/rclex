[![Hex version](https://img.shields.io/hexpm/v/rclex.svg "Hex version")](https://hex.pm/packages/rclex)
[![API docs](https://img.shields.io/hexpm/v/rclex.svg?label=hexdocs "API docs")](https://hexdocs.pm/rclex/readme.html)
[![License](https://img.shields.io/hexpm/l/rclex.svg)](https://github.com/rclex/rclex/blob/main/LICENSE)
[![ci-all_version](https://github.com/rclex/rclex/actions/workflows/ci.yml/badge.svg)](https://github.com/rclex/rclex/actions/workflows/ci.yml)

注：READMEは[英語版](README.md)が常に最新かつ確実です．

# Rclex [Ja]
ElixirによるROS 2クライアントライブラリです．
ROS 2共通階層であるRCL（ROS Client Library）APIをElixirコードから呼び出すことで基本的なROS 2の振る舞いをさせています．
またノード間の出版購読通信およびそれに付随するコールバック関数をプロセスモデルの一つであるタスクに実行させることで軽量にしています．
これにより，メモリへの負荷を抑えつつ，また耐障害性を高めてノードを大量に生成，通信させることが可能になっています．

## ROS 2とは

ROS（Robot Operating System）というロボット開発支援フレームワークの次世代版です．
ROS，ROS 2ともに，機能単位をノードと表現し，ノードを複数組み合わせて所望のさまざまなロボットアプリケーションが作成できます．
またノード間通信には出版購読通信が主に用いられ，パブリッシャとサブスクライバがトピックという名前でデータを識別してやりとりしています．

ROSからの大きな違いとして，通信にDDS（Data Distribution Service）プロトコルが採用されたこと，そしてライブラリが階層構造に分けられ，様々な言語でROS 2クライアントライブラリを開発できるようになったことです．これにより，Elixirでもロボットアプリケーションを開発できるようになりました．

詳しくはROS 2の[公式ドキュメント](https://index.ros.org/doc/ros2/)を参照ください．

## 動作環境（開発環境）

現在，下記の環境を対象として開発を進めています．

- Ubuntu 20.04.2 LTS (Focal Fossa)
- ROS 2 [Foxy Fitzroy](https://docs.ros.org/en/foxy/Releases/Release-Foxy-Fitzroy.html)
  - NOTE: [Dashing Diademata](https://index.ros.org/doc/ros2/Releases/Release-Dashing-Diademata/) on Ubuntu 18.04.5 LTS does not work well since v0.6.0 (we try to continue to support it, see #89)
- Elixir 1.12.3-otp-24
- Erlang/OTP 24.1.5

動作確認として，[rclex/rclex_connection_tests](https://github.com/rclex/rclex_connection_tests)を用いてRclcppで実装されたノードとの通信に関するテストを実施しています．

[GitHub Actions](https://github.com/rclex/rclex/actions)では，複数の環境でのCIを実行しています．ただし，これら全ての環境での動作保証には対応できません．

[Docker Hub](https://hub.docker.com/r/rclex/rclex_docker)にCIで利用しているビルド済みのDockerイメージを公開しています．
これを用いてRclexを簡単に試行することもできます．

## インストール方法

`rclex`は[Hexパッケージとして公開](https://hex.pm/docs/publish)しています．

`mix.exs`の依存関係に`rclex`を追加することで，ご自身のプロジェクトにて使用することができます．

```elixir
def deps do
  [
    {:rclex, "~> 0.7.0"}
  ]
end
```

ドキュメントは[ExDoc](https://github.com/elixir-lang/ex_doc)で生成されて[HexDocs](https://hexdocs.pm)に公開されています．  
[https://hexdocs.pm/rclex](https://hexdocs.pm/rclex)をご参照ください．

## 使い方

現時点では以下のことができるよう，Rclex APIを提供しています．
1. 同一トピックに対して，複数のパブリッシャおよびサブスクライバを大量に作成できる．
2. パブリッシャ，トピック，サブスクライバが1つずつのペアを大量に作成できる．

[こちら](https://github.com/rclex/rclex_examples)を参照してください．サンプルコードとともに使い方を記しています．

## 主な管理者と開発者（過去分も含む）

- [@takasehideki](https://github.com/takasehideki)
- [@HiroiImanishi](https://github.com/HiroiImanishi)
- [@kebus426](https://github.com/kebus426)
- [@shiroro466](https://github.com/shiroro466)
- [@s-hosoai](https://github.com/s-hosoai)
