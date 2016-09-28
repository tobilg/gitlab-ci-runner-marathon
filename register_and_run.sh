#!/bin/sh

set -eu

# Ensure GITLAB_SERVICE_NAME (custom defined variable). We need this to discover the GitLab location
if [ -z "$GITLAB_SERVICE_NAME" ]; then
    echo "Need to set GITLAB_SERVICE_NAME to the service name of GitLab (e.g. _gitlab._tcp.marathon.mesos)"
    exit 1
fi

# Ensure REGISTRATION_TOKEN
if [ -z "$REGISTRATION_TOKEN" ]; then
    echo "Need to set REGISTRATION_TOKEN. You can get this token in GitLab -> Admin Area -> Overview -> Runners"
    exit 1
fi

# Ensure RUNNER_EXECUTOR
if [ -z "$RUNNER_EXECUTOR" ]; then
    echo "Need to set RUNNER_EXECUTOR. Please choose a alid executor, like 'shell' or 'docker' etc."
    exit 1
fi

# Check for RUNNER_CONCURRENT_BUILDS variable (custom defined variable)
if [[ -v RUNNER_CONCURRENT_BUILDS ]]; then
  sed -i -e "s|concurrent = 1|concurrent = ${RUNNER_CONCURRENT_BUILDS}|g" /etc/gitlab-runner/config.toml
fi

# Derive the Mesos DNS server ip address by getting the first nameserver entry from /etc/resolv.conf
# Nasty workaround!
export MESOS_DNS_SERVER=$(cat /etc/resolv.conf | grep nameserver | awk -F" " '{print $2}' | head -n 1)

# Set the CI_SERVER_URL by resolving the Mesos DNS service name endpoint.
# Environment variable GITLAB_SERVICE_NAME must be defined in the Marathon app.json
export CI_SERVER_URL=http://$(mesosdns-resolver --serviceName $GITLAB_SERVICE_NAME --server $MESOS_DNS_SERVER --portIndex 0)/ci

# Derive the RUNNER_NAME from the MESOS_TASK_ID
export RUNNER_NAME="runner.${MESOS_TASK_ID}"

# Enable non-interactive registration the the main GitLab instance
export REGISTER_NON_INTERACTIVE=true

# Set the RUNNER_BUILDS_DIR
export RUNNER_BUILDS_DIR=${MESOS_SANDBOX}/builds

# Set the RUNNER_CACHE_DIR
export RUNNER_CACHE_DIR=${MESOS_SANDBOX}/cache

# Set the RUNNER_WORK_DIR
export RUNNER_WORK_DIR=${MESOS_SANDBOX}/cache

# Print the environment for debugging purposes
env

# Register the runner
gitlab-runner register

# Start the runner
exec gitlab-runner run --working-directory=${RUNNER_WORK_DIR}