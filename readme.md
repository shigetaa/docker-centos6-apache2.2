# CentOS6 環境で Apache2.2 環境をDockerコンテナで構築
CentOS をベースに Apache をソースからインストールしてイメージを作成する。

## コンテナ内で作業をする
```bash
docker run -it -p 8080:80 --rm --name centos6 centos:6 /bin/bash
```

### 問題
Docker Desktop for Windows (WSL2 backend) を使っていて centos:5 を動かそうとすると、起動せずに Exited (139) で即落ちるというエラーに遭遇しました。

### 対処方法
Docker Desktop for Windows (WSL2 backend) で問題を回避するには %USERPROFILE%/.wslcofig に設定を追加して PC を再起動します。
```bash
[wsl2]
kernelCommandLine = vsyscall=emulate
```
そうすると、以降は起動できるようになります。

### YumリポジトリURLを変更
CentOS6サポート終了のためYumリポジトリURL変更
```bash
sed -i "s|#baseurl=|baseurl=|g" /etc/yum.repos.d/CentOS-Base.repo
sed -i "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-Base.repo
sed -i "s|http://mirror\.centos\.org/centos/|http://vault\.centos\.org/centos/|g" /etc/yum.repos.d/CentOS-Base.repo
```

### リポジトリ追加
EPEL リポジトリ追加
```bash
rpm -Uvh http://archives.fedoraproject.org/pub/archive/epel/6/x86_64/epel-release-6-8.noarch.rpm
```
REMI リポジトリ追加
```bash
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
```

### パッケージのアップデートをしておく
```bash
yum check-update
yum -y update
```

### タイムゾーンの設定
以下のコマンドで日本標準時に設定する
`cp`コマンドの前に`\`を入れて`-f`で上書き確認をなしにする。
```bash
\cp -y /usr/share/zoneinfo/Japan /etc/localtime
```

## tar.gz から Apache をインストールする

### 環境変数を設定する
```bash
export HTTPD_PREFIX=/usr/local/apache2
export PATH=$HTTPD_PREFIX/bin:$PATH
export HTTPD_VERSION=2.2.34
```

### インストールフォルダを設定する
```bash
mkdir -p "$HTTPD_PREFIX"/src
```

### 必要なパッケージをインストールする
```bash
yum -y install gcc zlib-devel wget
```

### Apache source をダウンロードする
```bash
cd $HTTPD_PREFIX
wget -O httpd-$HTTPD_VERSION.tar.gz https://archive.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.gz
```
```bash
tar zxvf httpd-$HTTPD_VERSION.tar.gz -C src --strip-components=1 && rm -f httpd-$HTTPD_VERSION.tar.gz && cd src
```
### インストール設定をする
```bash
./configure \
--with-expat=builtin \
--enable-so \
--enable-deflate=shared \
--enable-dav_fs=shared \
--enable-dav=shared \
--enable-rewrite
```
### インストールする
```bash
make -j "$(nproc)" && make install
```

### 後始末
```bash
cd $HTTPD_PREFIX
rm -Rf src man manual
```
### 起動設定
```bash
/usr/local/apache2/bin/apachectl start
```


## Dockerfile から Apache のコンテナイメージを作成
以下の Dockerfileファイルを作成する。
```bash
FROM centos:6

ENV HTTPD_PREFIX /usr/local/apache2
ENV PATH $HTTPD_PREFIX/bin:$PATH
ENV HTTPD_VERSION 2.2.34

RUN set -x \
  && sed -i "s|#baseurl=|baseurl=|g" /etc/yum.repos.d/CentOS-Base.repo \
  && sed -i "s|mirrorlist=|#mirrorlist=|g" /etc/yum.repos.d/CentOS-Base.repo \
  && sed -i "s|http://mirror\.centos\.org/centos/|http://vault\.centos\.org/centos/|g" /etc/yum.repos.d/CentOS-Base.repo \
  \
  && yum -y update \
  && \cp -f /usr/share/zoneinfo/Japan /etc/localtime \
  \
  && yum -y install gcc make zlib-devel wget \
  \
  && mkdir -p "$HTTPD_PREFIX"/src \
  && cd $HTTPD_PREFIX \
  && wget -O httpd-$HTTPD_VERSION.tar.gz https://archive.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.gz \
  && tar zxvf httpd-$HTTPD_VERSION.tar.gz -C src --strip-components=1 \
  && rm -f httpd-$HTTPD_VERSION.tar.gz \
  && cd src \
  \
  && ./configure \
     --with-expat=builtin \
     --enable-so \
     --enable-deflate=shared \
     --enable-dav_fs=shared \
     --enable-dav=shared \
     --enable-rewrite \
  && make -j "$(nproc)" \
  && make install \
  \
  && cd $HTTPD_PREFIX \
  && rm -Rf src man manual \
  \
  && sed -ri \
     -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
     -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
     "$HTTPD_PREFIX/conf/httpd.conf"

COPY httpd-foreground /usr/local/bin/
RUN chmod 755 /usr/local/bin/httpd-foreground
EXPOSE 80
CMD ["httpd-foreground"]
```

以下のコマンドで Dockerfile ファイルからコンテナイメージを作成する。
```bash
docker build -t イメージ名 Dockerfileディレクトリ
```
例 Apache のイメージを作成してみる `-t` は イメージ名 最後の文字列は `Dockerfile` のディレクトリを指定します。 `.` はカレントディレクトリを表します。
```bash
docker build -t apache2.2.34 .
```

下記のコマンドでコンテナを動作させる
```bash
docker run -d -p 8080:80 --name コンテナ名 イメージ名
```
例 DocmentRoot をマウントしてコンテナを起動してみる。 \
`-d` は コンテナをバックグラウンドで実行させる \
`-p` は ホストのポート番号:コンテナのポート番号 \
`-v` は ボリュームをマウントするオプションです。 \
`$Pwd` は Windowsのカレントディレクトリを返す変数 \
`--name` は コンテナ名を指定する \
最後の文字列はイメージ名になります。
```bash
docker run -d -p 8080:80 -v $Pwd/public:/usr/local/apache2/htdocs --name container-apache apache2.2.34
```

実行中のコンテナでシェルを実行する
```bash
docker container exec -it container-apache /bin/bash
```




