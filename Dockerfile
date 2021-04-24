FROM php:7.2-fpm-alpine3.12

LABEL maintainer="sheletao <sheletao@sina.cn>" version="1.0.0"

# 默认变量配置
ENV TIMEZONE=${timezone:-"Asia/Shanghai"} \
    NGINX_PATH=/run/nginx \
    PHPREDIS_VERSION=5.3.2 \
    IGBINARY_VERSION=3.1.6 \
    MEMCACHE_VERSION=4.0.5.2 \
    PKG_CONFIG_VERSION=0.29.2 \
    MEMCACHED_VERSION=3.1.5

WORKDIR ${APP_PATH}

# 修改nginx配置包含/mnt/httpd/conf(此步骤按个人需求添加，无需修改则不添加)
COPY ./nginx.conf /etc/nginx/nginx.conf

# 安装软件
RUN set -ex \
    && sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
	&& apk update \
	&& apk add --no-cache \
       nginx zip m4 autoconf make gcc g++ linux-headers bzip2 \
       bzip2-dev libpng-dev gettext-dev gmp-dev sqlite-dev \
       libxml2-dev libxslt-dev zlib-dev libmemcached-dev\
    && mkdir ${NGINX_PATH} \
    && touch ${NGINX_PATH}/nginx.pid \
# Install PHP extensions
    && docker-php-ext-install -j$(nproc) \
       bcmath bz2 calendar exif gd gettext gmp pcntl pdo_mysql \
       pdo_sqlite shmop sockets zip sysvmsg sysvsem sysvshm wddx xsl zip \
# Install composer
    && curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && composer self-update --1 --clean-backups \
# Install igbinary extension
    && wget https://pecl.php.net/get/igbinary-${IGBINARY_VERSION}.tgz -O igbinary.tgz \
    && mkdir -p igbinary \
    && tar -xf igbinary.tgz -C igbinary --strip-components=1 \
    && rm igbinary.tgz \
    && ( \
        cd igbinary \
        && phpize \
        && ./configure \
        && make -j$(nproc) \
        && make install \
        && cd .. \
        ) \
    && rm -r igbinary \
    && docker-php-ext-enable igbinary \
# Install redis extension
    && wget http://pecl.php.net/get/redis-${PHPREDIS_VERSION}.tgz -O redis.tgz \
    && mkdir -p redis \
    && tar -xf redis.tgz -C redis --strip-components=1 \
    && rm redis.tgz \
    && ( \
        cd redis \
        && phpize \
        && ./configure \
        && make -j$(nproc) \
        && make install \
        && cd .. \
        ) \
    && rm -r redis \
    && docker-php-ext-enable redis \
# Install memcache extension
    && wget http://pecl.php.net/get/memcache-${MEMCACHE_VERSION}.tgz -O memcache.tgz \
    && mkdir -p memcache \
    && tar -xf memcache.tgz -C memcache --strip-components=1 \
    && rm memcache.tgz \
    && ( \
        cd memcache \
        && phpize \
        && ./configure \
        && make -j$(nproc) \
        && make install \
        && cd .. \
        ) \
    && rm -r memcache \
    && docker-php-ext-enable memcache \
# Install pkg-config
    && wget https://pkg-config.freedesktop.org/releases/pkg-config-${PKG_CONFIG_VERSION}.tar.gz -O pkg-config.tar.gz \
    && mkdir -p pkg-config \
    && tar -xf pkg-config.tar.gz -C pkg-config --strip-components=1 \
    && rm pkg-config.tar.gz \
    && ( \
        cd pkg-config \
        && ./configure --with-internal-glib \
        && make -j$(nproc) \
        && make install \
        && cd .. \
        ) \
    && rm -r pkg-config \    
# Install memcached extension
    && wget http://pecl.php.net/get/memcached-${MEMCACHED_VERSION}.tgz -O memcached.tgz \
    && mkdir -p memcached \
    && tar -xf memcached.tgz -C memcached --strip-components=1 \
    && rm memcached.tgz \
    && ( \
        cd memcached \
        && phpize \
        && ./configure \
        && make -j$(nproc) \
        && make install \
        && cd .. \
        ) \
    && rm -r memcached \
    && docker-php-ext-enable memcached \   
# Timezone
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "${TIMEZONE}" > /etc/timezone \
    && echo "[Date]\ndate.timezone=${TIMEZONE}" > /usr/local/etc/php/conf.d/timezone.ini \
# Clear dev deps
    && apk del \
       autoconf m4 make gcc g++ linux-headers wget unzip bzip2 \
       libpng gettext gmp less procps lsof tcpdump sqlite \
       libxml2 libxslt zlib postgresql net-tools icu libuuid \
       vim pkgconf oniguruma libzip util-linux libmemcached \
    && rm -rf /var/lib/apk/* /var/cache/apk/* /tmp/* /usr/share/man /root/.cache ~/.composer/cache \
    && echo -e "\033[42;37m Build Completed :).\033[0m\n"

EXPOSE 80 9000

CMD ["sh", "-c", "php-fpm -D && nginx -g 'daemon off;'"]
