# gitlab-ci-runner-marathon

A customized Docker image for running scalable GitLab CI runners on Marathon

## Configuration

The GitLab runner can be configured by environment variables. For a complete overview, have a look at the [docs/gitlab_runner_register_arguments.md](docs/gitlab_runner_register_arguments.md) file.

The most important ones are:

* `GITLAB_SERVICE_NAME`: The Mesos DNS service name, e.g. `gitlab.marathon.mesos`. This strongly depends on your setup, i.e. how you launched GitLab and how you configured Mesos DNS. **(mandatory)**
* `REGISTRATION_TOKEN`: The registration token tu use with the GitLab instance. See the [docs](https://docs.gitlab.com/ce/ci/runners/README.html) for details. **(mandatory)**
* `RUNNER_EXECUTOR`: The type of the executor to use, e.g. `shell` or `docker`. See the [executor docs](https://github.com/ayufan/gitlab-ci-multi-runner/blob/master/docs/executors/README.md) for more details. **(mandatory)**
* `RUNNER_CONCURRENT_BUILDS`: The number of concurrent builds this runner should be able to handel. Default is `1`.
* `RUNNER_TAG_LIST`: If you want to use tags in you `.gitlab-ci.yml`, then you need to specify the comma-separated list of tags. This is useful to distinguish the runner types.

## Run on Marathon

An example for a shell runner (on CoreOS), where you need to map the Docker binary and socket, as well as other libs to the GitLab runner container. This enables the build of Docker images.

```javascript
{
  "id": "gitlab-runner-shell",
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "tobilg/gitlab-ci-runner-marathon:latest",
      "network": "HOST",
      "forcePullImage": true
    },
    "volumes": [
      {
        "containerPath": "/usr/bin/docker",
        "hostPath": "/usr/bin/docker",
        "mode": "RO"
      },
      {
        "containerPath": "/var/run/docker.sock",
        "hostPath": "/var/run/docker.sock",
        "mode": "RW"
      },
      {
        "containerPath": "/lib/libdevmapper.so.1.02",
        "hostPath": "/lib64/libdevmapper.so.1.02",
        "mode": "RO"
      },
      {
        "containerPath": "/lib/libsystemd.so.0",
        "hostPath": "/lib64/libsystemd.so.0",
        "mode": "RO"
      },
      {
        "containerPath": "/lib/libgcrypt.so.20",
        "hostPath": "/lib64/libgcrypt.so.20",
        "mode": "RO"
      },
      {
        "containerPath": "/lib/x86_64-linux-gnu/libgpg-error.so.0",
        "hostPath": "/lib64/libgpg-error.so.0",
        "mode": "RO"
      }
    ]
  },
  "instances": 1,
  "cpus": 1,
  "mem": 2048,
  "env": {
    "GITLAB_SERVICE_NAME": "gitlab.marathon.mesos",
    "REGISTRATION_TOKEN": "zzNWmRE--SBfeMfiKCMh",
    "RUNNER_EXECUTOR": "shell",
    "RUNNER_TAG_LIST": "shell,build-as-docker",
    "RUNNER_CONCURRENT_BUILDS": "4"
  }
}
``` 
