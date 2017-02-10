#!/bin/sh

set -eu

# Ensure GITLAB_SERVICE_NAME (custom defined variable). We need this to discover the GitLab location
if [ -z ${GITLAB_SERVICE_NAME+x} ]; then
    echo "==> Need to set GITLAB_SERVICE_NAME to the service name of GitLab (e.g. gitlab.marathon.mesos)"
    exit 1
fi

# Ensure REGISTRATION_TOKEN
if [ -z ${REGISTRATION_TOKEN+x} ]; then
    echo "==> Need to set REGISTRATION_TOKEN. You can get this token in GitLab -> Admin Area -> Overview -> Runners"
    exit 1
fi

# Ensure RUNNER_EXECUTOR
if [ -z ${RUNNER_EXECUTOR+x} ]; then
    echo "==> Need to set RUNNER_EXECUTOR. Please choose a valid executor, like 'shell' or 'docker' etc."
    exit 1
fi

# Check for RUNNER_CONCURRENT_BUILDS variable (custom defined variable)
if [ -z ${RUNNER_CONCURRENT_BUILDS+x} ]; then
    echo "==> Concurrency is set to 1"
else
    sed -i -e "s|concurrent = 1|concurrent = ${RUNNER_CONCURRENT_BUILDS}|g" /etc/gitlab-runner/config.toml
    echo "==> Concurrency is set to ${RUNNER_CONCURRENT_BUILDS}"
fi

# Include the original entrypoint contents

# Set data directory
DATA_DIR="/etc/gitlab-runner"

# Set config file
CONFIG_FILE=${CONFIG_FILE:-$DATA_DIR/config.toml}

# Set custom certificate authority paths
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-$DATA_DIR/certs/ca.crt}
LOCAL_CA_PATH="/usr/local/share/ca-certificates/ca.crt"

# Create update_ca function
update_ca() {
  echo "==> Updating CA certificates..."
  cp "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}"
  update-ca-certificates --fresh > /dev/null
}

# Compare the custom CA path to the current CA path
if [ -f "${CA_CERTIFICATES_PATH}" ]; then
  # Update the CA if the custom CA is different than the current
  cmp --silent "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}" || update_ca
fi

# /Include the original entrypoint contents

# Derive the Mesos DNS server ip address by getting the first nameserver entry from /etc/resolv.conf
# Nasty workaround!
export MESOS_DNS_SERVER=$(cat /etc/resolv.conf | grep nameserver | awk -F" " '{print $2}' | head -n 1)

# Set the CI_SERVER_URL by resolving the Mesos DNS service name endpoint.
# Environment variable GITLAB_SERVICE_NAME must be defined in the Marathon app.json
export CI_SERVER_URL=http://$(mesosdns-resolver --serviceName $GITLAB_SERVICE_NAME --server $MESOS_DNS_SERVER --portIndex 0)/ci

# Derive the RUNNER_NAME from the MESOS_TASK_ID
export RUNNER_NAME=${MESOS_TASK_ID}

# Enable non-interactive registration the the main GitLab instance
export REGISTER_NON_INTERACTIVE=true

# Set the RUNNER_BUILDS_DIR
export RUNNER_BUILDS_DIR=${MESOS_SANDBOX}/builds

# Set the RUNNER_CACHE_DIR
export RUNNER_CACHE_DIR=${MESOS_SANDBOX}/cache

# Set the RUNNER_WORK_DIR
export RUNNER_WORK_DIR=${MESOS_SANDBOX}/work

# Create directories
mkdir -p $RUNNER_BUILDS_DIR $RUNNER_CACHE_DIR $RUNNER_WORK_DIR

# Print the environment for debugging purposes
echo "==> Printing the environment"
env

# Launch Docker daemon
# taken from https://github.com/mesosphere/jenkins-dind-agent/blob/master/wrapper.sh

# Check for DOCKER_EXTRA_OPTS. If not present set to empty value
if [ -z ${DOCKER_EXTRA_OPTS+x} ]; then
    echo "==> Not using DOCKER_EXTRA_OPTS"
    DOCKER_EXTRA_OPTS=
else
    echo "==> Using DOCKER_EXTRA_OPTS"
    echo ${DOCKER_EXTRA_OPTS}
fi

echo "==> Launching the Docker daemon..."
dind docker daemon --host=unix:///var/run/docker.sock --storage-driver=vfs $DOCKER_EXTRA_OPTS &

# Wait for the Docker daemon to start
while(! docker info > /dev/null 2>&1); do
    echo "==> Waiting for the Docker daemon to come online..."
    sleep 1
done
echo "==> Docker Daemon is up and running!"

# Termination function
_getTerminationSignal() {
    echo "Caught SIGTERM signal! Deleting GitLab Runner!"
    # See https://docs.gitlab.com/ce/api/ci/runners.html#delete-a-runner
    curl --request DELETE "${CI_SERVER_URL}/api/v1/runners/delete" --form "token=${REGISTRATION_TOKEN}"
}

# Trap SIGTERM
trap _getTerminationSignal TERM

# Register the runner
gitlab-runner register

# Start the runner
gitlab-runner run --working-directory=${RUNNER_WORK_DIR}