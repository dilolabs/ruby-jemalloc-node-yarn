FROM debian:latest

ENV MIRROR="debian.mirrors.ovh.net"

RUN sed -i "s|deb.debian.org|$MIRROR|g" /etc/apt/sources.list \
  && apt-get update \
  && apt-get -y upgrade \
  && apt-get -y install wget \
  && apt-get -y remove --purge wget \
  && apt-get -y autoremove --purge \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bzip2 \
    ca-certificates \
    openssl \
    curl \
    libffi-dev \
    libssl-dev \
    libyaml-dev \
    libxml2 \
    libxml2-dev \
    libpq-dev \
    libxslt1-dev \
    procps \
    zlib1g-dev \
    libjemalloc-dev \
    imagemagick \
  && rm -rf /var/lib/apt/lists/*

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc

ENV BUNDLER_VERSION 2.2.23
ENV RUBY_MAJOR 2.7
ENV RUBY_VERSION 2.7.4
ENV RUBY_DOWNLOAD_SHA256 3043099089608859fc8cce7f9fdccaa1f53a462457e3838ec3b25a7d609fbc5b
ENV RUBYGEMS_VERSION 3.2.22

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN set -ex \
  && buildDeps=' \
    autoconf \
    bison \
    gcc \
    libbz2-dev \
    libgdbm-dev \
    libglib2.0-dev \
    libncurses-dev \
    libreadline-dev \
    libxml2-dev \
    libxslt-dev \
    make \
    ruby \
  ' \
  && apt-get update \
  && apt-get install -y --no-install-recommends $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fSL -o ruby.tar.gz "https://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" \
  && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.gz" | sha256sum -c - \
  && mkdir -p /usr/src/ruby \
  && tar -xzf ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.gz \
  && cd /usr/src/ruby \
  && { echo '#define ENABLE_PATH_CHECK 0'; echo; cat file.c; } > file.c.new && mv file.c.new file.c \
  && autoconf \
  && ./configure --with-jemalloc --disable-install-doc \
  && make -j"$(nproc)" \
  && make install \
  && apt-get purge -y --auto-remove $buildDeps \
  && gem update --system $RUBYGEMS_VERSION \
  && rm -r /usr/src/ruby

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
  BUNDLE_BIN="$GEM_HOME/bin" \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

RUN gem install bundler -v $BUNDLER_VERSION
RUN apt-get update
RUN apt-get -y install curl
RUN apt-get install -my gnupg
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get -qqyy install nodejs yarn && rm -rf /var/lib/apt/lists/*

RUN echo 'LC_ALL="en_US.UTF-8"' > /etc/default/locale
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update
RUN apt-get install -y openssl libpq-dev build-essential libcurl4-openssl-dev software-properties-common

RUN apt-get -y install wget

# Add postgresql client
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -sc)-pgdg main" > /etc/apt/sources.list.d/PostgreSQL.list'

RUN wget https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key add ACCC4CF8.asc
RUN apt-get update
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install postgresql-12

# Add libvips
RUN apt-get -y install pkg-config \
    libgsf-1-dev \
    glib-2.0-dev \
    libexpat-dev \
    librsvg2-dev \
    libpng-dev \
    libjpeg-dev \
    libtiff5-dev \
    libexif-dev \
    liblcms2-dev \
    libxml2-dev \
    libfftw3-dev \
    libpoppler-glib-dev \
  && cd /tmp \
  && wget https://github.com/libvips/libvips/releases/download/v8.9.2/vips-8.9.2.tar.gz \
  && tar xf vips-8.9.2.tar.gz \
  && cd vips-8.9.2 \
  && ./configure \
  && make \
  && make install \
  && ldconfig \
  && rm -rf /tmp/*
