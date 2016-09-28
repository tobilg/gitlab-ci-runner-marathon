FROM gitlab/gitlab-runner:ubuntu-v1.5.3

MAINTAINER TobiLG <tobilg@gmail.com>

RUN apt-get update && apt-get install -y curl dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    curl -cL https://raw.githubusercontent.com/tobilg/mesosdns-resolver/master/mesosdns-resolver.sh > /usr/bin/mesosdns-resolver && \
    chmod +x /usr/bin/mesosdns-resolver

ADD register-and-run /

ENTRYPOINT ["/register-and-run"]