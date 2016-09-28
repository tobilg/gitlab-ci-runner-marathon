# gitlab-ci-runner-marathon
A customized Docker image for running scalable GitLab CI runners on Marathon

## Run on Marathon

An example for a shell runner (on CoreOS):

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
