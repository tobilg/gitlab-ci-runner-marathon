#!/bin/sh

set -eu

# Ensure GITLAB_SERVICE_NAME (custom defined variable). We need this to discover the GitLab location
if [ -z ${GITLAB_SERVICE_NAME+x} ]; then
    echo "Need to set GITLAB_SERVICE_NAME to the service name of GitLab (e.g. gitlab)"
    exit 1
fi

# Ensure REGISTRATION_TOKEN
if [ -z ${REGISTRATION_TOKEN+x} ]; then
    echo "Need to set REGISTRATION_TOKEN. You can get this token in GitLab -> Admin Area -> Overview -> Runners"
    exit 1
fi

# Ensure RUNNER_EXECUTOR
if [ -z ${RUNNER_EXECUTOR+x} ]; then
    echo "Need to set RUNNER_EXECUTOR. Please choose a valid executor, like 'shell' or 'docker' etc."
    exit 1
fi

# Check for RUNNER_CONCURRENT_BUILDS variable (custom defined variable)
if [ -z ${RUNNER_CONCURRENT_BUILDS+x} ]; then
    echo "Concurrency is set to 1"
else
    sed -i -e "s|concurrent = 1|concurrent = ${RUNNER_CONCURRENT_BUILDS}|g" /etc/gitlab-runner/config.toml
    echo "Concurrency is set to ${RUNNER_CONCURRENT_BUILDS}"
fi

# Set the CI_SERVER_URL by resolving the Mesos DNS service name endpoint.
# Environment variable GITLAB_SERVICE_NAME must be defined in the Marathon app.json
export CI_SERVER_PORT=$(dig srv _instance._$GITLAB_SERVICE_NAME._tcp.marathon.mesos +short | head -1 | awk '{print $3}')
export CI_SERVER_URL=http://$GITLAB_SERVICE_NAME.marathon.mesos:$CI_SERVER_PORT/ci

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
env

# Register the runner
gitlab-runner register

# Start the runner
exec gitlab-runner run --working-directory=${RUNNER_WORK_DIR}