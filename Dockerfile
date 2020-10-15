FROM ubuntu:16.04

MAINTAINER TobiLG <tobilg@gmail.com>

# Download dumb-init
ADD https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64 /usr/bin/dumb-init

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

ENV GITLAB_RUNNER_VERSION="13.4.1"

ENV DOCKER_CE_VERSION="5:19.03.13~3-0~ubuntu-xenial"

# Install components and do the preparations
# 1. Install needed packages
# 2. Install GitLab CI runner
# 3. Install mesosdns-resolver
# 4. Install Docker
# 5. Install DinD hack
# 6. Cleanup
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y ca-certificates apt-transport-https curl dnsutils bridge-utils lsb-release software-properties-common && \
    chmod +x /usr/bin/dumb-init && \
    curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash && \
    apt-get update -y && \
    apt-get install -y gitlab-runner=${GITLAB_RUNNER_VERSION} && \
    mkdir -p /etc/gitlab-runner/certs && \
    chmod -R 700 /etc/gitlab-runner && \
    curl -sSL https://raw.githubusercontent.com/tobilg/mesosdns-resolver/master/mesosdns-resolver.sh -o /usr/local/bin/mesosdns-resolver && \
    chmod +x /usr/local/bin/mesosdns-resolver && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get update && \
    apt-get install -y docker-ce=${DOCKER_CE_VERSION} docker-ce-cli=${DOCKER_CE_VERSION} containerd.io && \
    curl -sSL https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind -o /usr/local/bin/dind && \
    chmod a+x /usr/local/bin/dind && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add wrapper script
ADD register_and_run.sh /

# Expose volumes
VOLUME ["/var/lib/docker", "/etc/gitlab-runner", "/home/gitlab-runner"]

ENTRYPOINT ["/usr/bin/dumb-init", "/register_and_run.sh"]
