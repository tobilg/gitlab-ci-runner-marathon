# gitlab-ci-runner-marathon (DinD version)

A customized Docker image for running scalable GitLab CI runners on DC/OS or vanilla Mesos via Marathon.

## Configuration

The GitLab runner can be configured by environment variables. For a complete overview, have a look at the [docs/gitlab_runner_register_arguments.md](docs/gitlab_runner_register_arguments.md) file.

The most important ones are:

* `GITLAB_SERVICE_NAME`: The Mesos DNS service name, e.g. `gitlab.marathon.mesos`. This strongly depends on your setup, i.e. how you launched GitLab and how you configured Mesos DNS. **(mandatory)**
* `REGISTRATION_TOKEN`: The registration token tu use with the GitLab instance. See the [docs](https://docs.gitlab.com/ce/ci/runners/README.html) for details. **(mandatory)**
* `RUNNER_EXECUTOR`: The type of the executor to use, e.g. `shell` or `docker`. See the [executor docs](https://github.com/ayufan/gitlab-ci-multi-runner/blob/master/docs/executors/README.md) for more details. **(mandatory)**
* `RUNNER_CONCURRENT_BUILDS`: The number of concurrent builds this runner should be able to handel. Default is `1`.
* `RUNNER_TAG_LIST`: If you want to use tags in you `.gitlab-ci.yml`, then you need to specify the comma-separated list of tags. This is useful to distinguish the runner types.

## Run on DC/OS (or vanilla Mesos)

This version of the GitLab CI runner for Marathon project uses Docker-in-Docker techniques, with all of its pros and cons. See also [jpetazzo's article](http://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/) on this topic.

In the following examples, we assume that you're running the GitLab Universe package as service `gitlab` on DC/OS internal Marathon instance, which is also available to the runners via the `external_url` of the GitLab configuration. This normally means that GitLab is exposed on a public agent node via marathon-lb. 

Have a look below for a GitLab CE sample configuration.

### Shell runner

An example for a shell runner. This enables the build of Docker images.

```javascript
{
  "id": "gitlab-runner-shell",
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "tobilg/gitlab-ci-runner-marathon:dind",
      "network": "HOST",
      "forcePullImage": true,
      "privileged": true
    }
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

### Docker runner

Here's an example for a Docker runner, which enables builds *inside* Docker containers:

```javascript
{
  "id": "gitlab-runner-docker",
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "tobilg/gitlab-ci-runner-marathon:dind",
      "network": "HOST",
      "forcePullImage": true,
      "privileged": true
    }
  },
  "instances": 1,
  "cpus": 1,
  "mem": 2048,
  "env": {
    "GITLAB_SERVICE_NAME": "gitlab.marathon.mesos",
    "REGISTRATION_TOKEN": "zzNWmRE--SBfeMfiKCMh",
    "RUNNER_EXECUTOR": "docker",
    "RUNNER_TAG_LIST": "docker,build-in-docker",
    "RUNNER_CONCURRENT_BUILDS": "4",
    "DOCKER_IMAGE": "node:6-wheezy"
  }
}
```

Make sure you choose a useful default Docker image via `DOCKER_IMAGE`, for example if you want to build Node.js projects, the `node:6-wheezy` image. This can be overwritten with the `image` property in the `.gitlab-ci.yml` file (see the [GitLab CI docs](https://docs.gitlab.com/ce/ci/yaml/README.html).

## Usage in GitLab CI

### Builds as Docker

An `.gitlab-ci.yml` example of using the `build-as-docker` tag to trigger a build on the runner(s) with shell executors:

```yaml
stages:
  - ci

build-job:
  stage: ci
  tags:
    - build-as-docker
  script:
    - docker build -t tobilg/test .
```

This assumes your project has a `Dockerfile`, for example

```
FROM nginx
```

### Builds in Docker

An `.gitlab-ci.yml` example of using the `build-in-docker` tag to trigger a build on the runner(s) with Docker executors:

```yaml
image: node:6-wheezy

stages:
  - ci

test-job:
  stage: ci
  tags:
    - build-in-docker
  script:
    - node --version
```

## GitLab CE sample configuration

To customize the configuration below, you'd have to set/replace

* `gitlab.dcos-public-agent-1.mydomain.mytld` with the actual FQDN of one of your public agents
* The `gitlab` subdomain on the public agent needs to be resolvable via DNS
* For the usage of mapped host volumes, you'll have to create the directories (in this example `/opt/gitlab` and `/opt/gitlab-data`) on the specific agent where you want to run GitLab
* Replace the `192.168.1.100` address with the hostname or ip address on which you created the folders for GitLab

The following labels are important for the service discovery/exposure via marathon-lb:

* `HAPROXY_0_BACKEND_HTTP_OPTIONS`
* `HAPROXY_0_HTTP_FRONTEND_HEAD`
* `HAPROXY_0_VHOST`
* `HAPROXY_0_REDIRECT_TO_HTTPS`
* `HAPROXY_GROUP`

```javascript
{
  "id": "/gitlab",
  "cmd": null,
  "env": {
    "GITLAB_OMNIBUS_CONFIG": "external_url 'http://gitlab.dcos-public-agent-1.mydomain.mytld/'; registry_external_url 'http://gitlab.dcos-public-agent-1.mydomain.mytld:50000/'; gitlab_rails['gitlab_ssh_host'] = 'gitlab.dcos-public-agent-1.mydomain.mytld:22222';  unicorn['worker_processes'] = 2; manage_accounts['enable'] = true; user['home'] = '/gitlab-data/home'; git_data_dir '/gitlab-data/git-data'; gitlab_rails['shared_path'] = '/gitlab-data/shared'; gitlab_rails['uploads_directory'] = '/gitlab-data/uploads'; gitlab_ci['builds_directory'] = '/gitlab-data/builds';"
  },
  "instances": 1,
  "cpus": 1,
  "mem": 2048,
  "disk": 0,
  "gpus": 0,
  "executor": null,
  "constraints": [
    [
      "hostname",
      "CLUSTER",
      "192.168.1.100"
    ]
  ],
  "backoffSeconds": 1,
  "backoffFactor": 1.15,
  "maxLaunchDelaySeconds": 3600,
  "container": {
    "docker": {
      "image": "gitlab/gitlab-ce:8.11.5-ce.0",
      "forcePullImage": false,
      "privileged": false,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        },
        {
          "containerPort": 443,
          "protocol": "tcp"
        },
        {
          "containerPort": 22,
          "protocol": "tcp"
        },
        {
          "containerPort": 50000,
          "protocol": "tcp"
        }
      ],
      "network": "BRIDGE"
    },
    "type": "DOCKER",
    "volumes": [
      {
        "containerPath": "/var/opt/gitlab",
        "hostPath": "/opt/gitlab/gitlab/opt",
        "mode": "RW"
      },
      {
        "containerPath": "/var/log/gitlab",
        "hostPath": "/opt/gitlab/gitlab/log",
        "mode": "RW"
      },
      {
        "containerPath": "/etc/gitlab",
        "hostPath": "/opt/gitlab-data/gitlab/config",
        "mode": "RW"
      },
      {
        "containerPath": "/gitlab-data",
        "hostPath": "/opt/gitlab-data/gitlab/data",
        "mode": "RW"
      }
    ]
  },
  "healthChecks": [
    {
      "protocol": "COMMAND",
      "command": {
        "value": "curl --fail ${HOST}:${PORT0}/help > /dev/null"
      },
      "gracePeriodSeconds": 300,
      "intervalSeconds": 60,
      "timeoutSeconds": 20,
      "maxConsecutiveFailures": 5
    }
  ],
  "upgradeStrategy": {
    "minimumHealthCapacity": 0,
    "maximumOverCapacity": 0
  },
  "labels": {
    "DCOS_PACKAGE_RELEASE": "1",
    "DCOS_PACKAGE_SOURCE": "https://universe.mesosphere.com/repo",
    "DCOS_PACKAGE_METADATA": "eyJwYWNrYWdpbmdWZXJzaW9uIjoiMy4wIiwibmFtZSI6ImdpdGxhYiIsInZlcnNpb24iOiIxLjAtOC4xMS41IiwibWFpbnRhaW5lciI6InN1cHBvcnRAZ2l0bGFiLmNvbSIsImRlc2NyaXB0aW9uIjoiQ29sbGFib3JhdGlvbiBhbmQgc291cmNlIGNvbnRyb2wgbWFuYWdlbWVudDogY29kZSwgdGVzdCwgYW5kIGRlcGxveSB0b2dldGhlciEiLCJ0YWdzIjpbImNvbnRpbnVvdXMtaW50ZWdyYXRpb24iLCJjaSIsInZjcyIsInZlcnNpb24tY29udHJvbC1zb2Z0d2FyZSJdLCJzZWxlY3RlZCI6dHJ1ZSwic2NtIjoiaHR0cHM6Ly9naXRsYWIuY29tL2dpdGxhYi1vcmcvZ2l0bGFiLWNlIiwid2Vic2l0ZSI6Imh0dHBzOi8vYWJvdXQuZ2l0bGFiLmNvbS8iLCJmcmFtZXdvcmsiOmZhbHNlLCJwcmVJbnN0YWxsTm90ZXMiOiJIYXZpbmcgTWFyYXRob24tbGIgaW5zdGFsbGVkIGFuZCBzZXR0aW5nIGEgdmlydHVhbCBob3N0IGluIHRoZSBjb25maWcgaXMgcmVxdWlyZWQgZm9yIGJlaW5nIGFibGUgdG8gYWNjZXNzIEdpdExhYi4iLCJwb3N0SW5zdGFsbE5vdGVzIjoiR2l0TGFiIGhhcyBiZWVuIGluc3RhbGxlZC4iLCJwb3N0VW5pbnN0YWxsTm90ZXMiOiJHaXRMYWIgaGFzIGJlZW4gdW5pbnN0YWxsZWQuIE5vdGUgdGhhdCBhbnkgZGF0YSBwZXJzaXN0ZWQgdG8gYSBORlMgc2hhcmUgc3RpbGwgZXhpc3RzIGFuZCB3aWxsIG5lZWQgdG8gYmUgbWFudWFsbHkgcmVtb3ZlZC4iLCJsaWNlbnNlcyI6W3sibmFtZSI6Ik1JVCBMaWNlbnNlIiwidXJsIjoiaHR0cHM6Ly9naXRsYWIuY29tL2dpdGxhYi1vcmcvZ2l0bGFiLWNlL3Jhdy9tYXN0ZXIvTElDRU5TRSJ9LHsibmFtZSI6IkVFIExpY2Vuc2UiLCJ1cmwiOiJodHRwczovL2dpdGxhYi5jb20vZ2l0bGFiLW9yZy9naXRsYWItZWUvcmF3L21hc3Rlci9MSUNFTlNFIn1dLCJpbWFnZXMiOnsiaWNvbi1zbWFsbCI6Imh0dHBzOi8vc2VjdXJlLmdyYXZhdGFyLmNvbS9hdmF0YXIvNmVkZDBhY2FmODBmNzg0ZmFiM2RkMmMzMWQ2MDRlNzQuanBnP3M9NDAmcj1nJmQ9bW0iLCJpY29uLW1lZGl1bSI6Imh0dHBzOi8vc2VjdXJlLmdyYXZhdGFyLmNvbS9hdmF0YXIvNmVkZDBhY2FmODBmNzg0ZmFiM2RkMmMzMWQ2MDRlNzQuanBnP3M9ODAmcj1nJmQ9bW0iLCJpY29uLWxhcmdlIjoiaHR0cHM6Ly9zZWN1cmUuZ3JhdmF0YXIuY29tL2F2YXRhci82ZWRkMGFjYWY4MGY3ODRmYWIzZGQyYzMxZDYwNGU3NC5qcGc/cz0yMDAmcj1nJmQ9bW0ifX0=",
    "DCOS_PACKAGE_REGISTRY_VERSION": "3.0",
    "DCOS_SERVICE_NAME": "gitlab",
    "DCOS_PACKAGE_VERSION": "1.0-8.11.5",
    "DCOS_PACKAGE_NAME": "gitlab",
    "DCOS_PACKAGE_IS_FRAMEWORK": "false",
    "MARATHON_SINGLE_INSTANCE_APP": "true",
    "HAPROXY_0_BACKEND_HTTP_OPTIONS": "  option httplog\n  option forwardfor\n  no option http-keep-alive\n  http-request set-header X-Forwarded-Port %[dst_port]\n",
    "HAPROXY_0_HTTP_FRONTEND_HEAD": "  option httplog\n",
    "HAPROXY_0_VHOST": "gitlab.dcos-public-agent-1.mydomain.mytld",
    "HAPROXY_0_REDIRECT_TO_HTTPS": "false",
    "HAPROXY_GROUP": "external"
  },
  "acceptedResourceRoles": [
    "*"
  ],
  "portDefinitions": [
    {
      "port": 10155,
      "protocol": "tcp",
      "labels": {}
    },
    {
      "port": 10156,
      "protocol": "tcp",
      "labels": {}
    },
    {
      "port": 10159,
      "protocol": "tcp",
      "labels": {}
    },
    {
      "port": 10160,
      "protocol": "tcp",
      "labels": {}
    }
  ],
  "requirePorts": false
}
```