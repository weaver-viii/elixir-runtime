#!/bin/bash

# Copyright 2017 Google Inc.
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


set -e

# Container Builder changes the home directory, so make sure the global
# .tool-versions file is replicated there.
test "${HOME}" = "/root" || cp /root/.tool-versions ${HOME}/

WORKSPACE_DIR=$(/bin/pwd)
cd /app
./generate_dockerfile \
    --template-dir=/app \
    --workspace-dir=${WORKSPACE_DIR} \
    --debian-image=${ELIXIR_DEBIAN_IMAGE} \
    --asdf-image=${ELIXIR_ASDF_IMAGE} \
    --builder-image=${ELIXIR_BUILDER_IMAGE} \
    --prebuilt-erlang-image-base=${PREBUILT_ERLANG_IMAGE_BASE} \
    --prebuilt-erlang-image-tag=${PREBUILT_ERLANG_IMAGE_TAG} \
    --prebuilt-erlang-versions=${PREBUILT_ERLANG_VERSIONS} \
    --default-erlang-version=${DEFAULT_ERLANG_VERSION} \
    --default-elixir-version=${DEFAULT_ELIXIR_VERSION} \
    "$@"
