FROM encoflife/ruby
MAINTAINER Dmitry Mozzherin
ENV LAST_FULL_REBUILD 2015-03-05
RUN apt-get update -q && \
    apt-get install -qq -y software-properties-common nodejs \
      libmysqlclient-dev libqt4-dev supervisor && \
    add-apt-repository -y ppa:nginx/stable && \
    apt-get update && \
    apt-get install -qq -y nginx && \
    echo "\ndaemon off;" >> /etc/nginx/nginx.conf && \
    chown -R www-data:www-data /var/lib/nginx && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY config/docker/nginx-sites.conf /etc/nginx/sites-enabled/default

WORKDIR /app
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN bundle install
COPY . /app

COPY config/docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir /app/public/uploads/data_search_files && \
    mkdir /app/public/uploads/datasets && \
    mkdir /app/public/uploads/images && \
    chmod a+rx /app/public/uploads/* && \
    chown -R www-data:www-data /app/public/uploads
RUN chmod a+rx /
RUN umask 0022

CMD /usr/bin/supervisord
