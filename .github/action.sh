#!/bin/bash

# Copyright (c) 2020, Mathias Lüdtke
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This is the entrypoint for GitHub Actions only.

# 2016/05/18 http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
DIR_THIS="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export TARGET_REPO_PATH=$GITHUB_WORKSPACE
export TARGET_REPO_NAME=${GITHUB_REPOSITORY##*/}
export _FOLDING_TYPE=github_actions

if [ -n "$INPUT_CONFIG" ]; then
    vars=$(jq -r 'keys[] as $k | "export \($k)=\(.[$k]|tojson)" | gsub("\\$\\$";"\\$")' <<< "$INPUT_CONFIG"  | grep "^export [A-Z][A-Z_]*=")
    echo "$vars"
    eval "$vars"
fi

if [ -z "$DOCKER_IMAGE" ] && [ -n "$ROS_DISTRO" ] ; then
  # Create Dockerfile for base image
  cat > ../Dockerfile << EOF
    FROM ros:${ROS_DISTRO}-ros-base
    RUN \\
        --mount=target=/tmp/repo,type=bind,source=${TARGET_REPO_NAME} \\
        # Update apt package list and upgrade system
        apt-get -qq update && \\
        apt-get -qq dist-upgrade && \\
        #
        # Install basic build dependencies
        apt-get -qq install --no-install-recommends -y \\
            git python-catkin-tools clang clang-format-10 clang-tidy clang-tools ccache && \\
        # Install workspace dependencies
        rosdep update && \\
        DEBIAN_FRONTEND=noninteractive \\
        rosdep install -y --from-paths /tmp/repo --ignore-src --rosdistro ${ROS_DISTRO} --as-root=apt:false && \\
        #
        # Clear apt-cache to reduce image size
        rm -rf /var/lib/apt/lists/*
EOF
  sudo docker buildx build --quiet --file ../Dockerfile --tag ci:base ..
  export DOCKER_IMAGE=ci:base
  export DOCKER_PULL=false
fi

env "$@" bash "$DIR_THIS/../industrial_ci/src/ci_main.sh"
