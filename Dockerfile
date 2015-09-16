#
#  vim:ts=2:sw=2:et
#
FROM fedora:latest
MAINTAINER Rohith <gambol99@gmail.com>

RUN dnf install -y tar ruby rubygems rubygem-mysql2.x86_64 && \
    gem install optionscrapper

ADD https://github.com/michaloo/go-cron/releases/download/v0.0.2/go-cron.tar.gz /tmp/go-cron.tar
RUN tar xvf /tmp/go-cron.tar -C / && \
    rm -f /tmp/go-cron.tar

ADD bin/gitlab-alert.rb /bin/gitlab-alert.rb
ADD bin/run.sh /run.sh

# every monday at 10am
ENV SCHEDULE 0 0 10 * * 1

ENTRYPOINT [ "/run.sh" ]
