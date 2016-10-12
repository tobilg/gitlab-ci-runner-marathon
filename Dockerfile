FROM ubuntu:16.04

MAINTAINER TobiLG <tobilg@gmail.com>

# Download dumb-init
ADD https://github.com/Yelp/dumb-init/releases/download/v1.0.2/dumb-init_1.0.2_amd64 /usr/bin/dumb-init

# Add wrapper script
ADD register_and_run.sh /

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

# Install components and do the preparations
# 1. Install needed packages
# 2. Install GitLab CI runner
# 3. Install mesosdns-resolver
# 4. Install Docker
# 5. Install DinD hack
# 6. Cleanup
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates apt-transport-https curl dnsutils && \
    chmod +x /usr/bin/dumb-init && \
    echo "deb https://packages.gitlab.com/runner/gitlab-ci-multi-runner/ubuntu/ `lsb_release -cs` main" > /etc/apt/sources.list.d/runner_gitlab-ci-multi-runner.list && \
    curl -sSL https://packages.gitlab.com/gpg.key | apt-key add - && \
    apt-get update -y && \
    apt-get install -y gitlab-ci-multi-runner && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    curl -sSL https://raw.githubusercontent.com/tobilg/mesosdns-resolver/master/mesosdns-resolver.sh -o /usr/local/bin/mesosdns-resolver && \
    chmod +x /usr/local/bin/mesosdns-resolver && \
    curl -sSL https://get.docker.com | sh && \
    curl -sSL https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind -o /usr/local/bin/dind && \
    chmod a+x /usr/local/bin/dind && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]

ENTRYPOINT ["/usr/bin/dumb-init", "/register_and_run.sh"]
