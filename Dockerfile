FROM php:7.4.27-apache

MAINTAINER Andreas Krüger <ak@patientsky.com>

ENV DEBIAN_FRONTEND noninteractive
ENV php_conf /etc/php/7.1/apache2/php.ini
ENV apache2_conf $APACHE_CONFDIR/conf-available/docker-php.conf
ENV composer_hash 669656bab3166a7aff8a7506b8cb2d1c292f042046c5a994c43155c0be6190fa0355160742ab2e1c88d40d5be660b410
ENV APACHE_RUN_USER ps-data
ENV APACHE_RUN_GROUP www-data

RUN apt-get update \
    && apt-get install -y -q --no-install-recommends \
    apt-transport-https \
    lsb-release \
    wget \
    vim \
    host \
    tzdata \
    apt-utils \
    ca-certificates


RUN echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list && \
    echo "deb-src http://packages.dotdeb.org jessie all" >> /etc/apt/sources.list.d/dotdeb.list && \
    wget https://www.dotdeb.org/dotdeb.gpg && apt-key add dotdeb.gpg

RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

RUN echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list && \
    wget -O- https://download.newrelic.com/548C16BF.gpg | apt-key add -

RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng12-dev \
        libcurl4-openssl-dev \
        locales \
        git \
        openssl \
        openssh-client \
        librabbitmq-dev \
        pkg-config \
        net-tools \
        libmagickwand-dev \
        libmagickcore-dev \
        libssl-dev \
        zlib1g-dev \
        libicu-dev \
        g++ \
        unzip \
        make \
        php-pear \
    && docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) pdo_mysql json bcmath intl opcache mbstring xml zip

RUN pecl install redis \
    && pecl install amqp \
    && pecl install igbinary \
    && pecl install mongodb \
    && pecl install imagick \
    && docker-php-ext-enable redis amqp igbinary imagick mongodb

RUN useradd -G $APACHE_RUN_GROUP -ms /bin/bash $APACHE_RUN_USER

RUN mkdir -p /var/www/app

RUN a2enmod rewrite

# nginx site conf
RUN rm -Rf /var/www/* && \
    mkdir /var/www/html/

#ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
#RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf


RUN sed -i 's/# nb_NO.UTF-8 UTF-8/nb_NO.UTF-8 UTF-8/' /etc/locale.gen && \
    ln -sf /etc/locale.alias /usr/share/locale/locale.alias && \
    locale-gen nb_NO.UTF-8


ADD conf/default.conf $APACHE_CONFDIR/sites-available/000-default.conf
ADD conf/mods-available/opcache.ini /etc/php/7.1/mods-available/opcache.ini

RUN apt-get install sudo

# Add Scripts
ADD scripts/start.sh /start.sh
ADD scripts/setup.sh /setup.sh
RUN chmod 755 /start.sh && \
    chmod 755 /setup.sh

# copy in code and errors
# ADD src/ /var/www/html/
ADD errors/ /var/www/errors

# RUN docker-php-ext-install -j$(nproc) curl




RUN composer_hash=$(wget -q -O - https://composer.github.io/installer.sig) && \
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '${composer_hash}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php --install-dir=/usr/bin --filename=composer && \
    php -r "unlink('composer-setup.php');"

EXPOSE 80
RUN mkfifo -m 600 /tmp/logpipe
CMD ["/start.sh"]
