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