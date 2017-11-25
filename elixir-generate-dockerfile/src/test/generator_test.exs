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

defmodule GeneratorTest do
  use ExUnit.Case
  alias GenerateDockerfile.Generator

  @test_dir __DIR__
  @cases_dir Path.join(@test_dir, "app_config")
  @tmp_dir Path.join(@test_dir, "tmp")
  @template_path Path.expand("../../app/Dockerfile.eex", @test_dir)

  @minimal_config """
    env: flex
    runtime: gs://elixir-runtime/elixir.yaml
    """

  test "minimal directory with minimal config" do
    run_generator("minimal", @minimal_config)
    assert_ignore_line("Dockerfile")
    assert_dockerfile_line("## Service: default")
    assert_dockerfile_line("## Project: (unknown)")
    assert_dockerfile_line("FROM gcr.io/gcp-elixir/runtime/base AS augmented-base")
    assert_dockerfile_line("#     && apt-get install -y -q package-name")
    assert_dockerfile_line("COPY --from=gcr.io/gcp-elixir/runtime/build-tools")
    assert_dockerfile_line("# RUN gcloud config set project my-project-id")
    assert_dockerfile_line("# ENV NAME=\"value\"")
    assert_dockerfile_line("# RUN mkdir /cloudsql")
    assert_dockerfile_line("CMD exec mix run --no-halt")
  end

  test "minimal directory with custom service" do
    config = @minimal_config <> """
      service: elixir_app
      """
    run_generator("minimal", config)
    assert_dockerfile_line("## Service: elixir_app")
  end

  test "minimal directory with custom project" do
    run_generator("minimal", @minimal_config, project: "actual-project")
    assert_dockerfile_line("## Project: actual-project")
    assert_dockerfile_line("RUN gcloud config set project actual-project")
  end

  test "minimal directory with custom entrypoint" do
    config = @minimal_config <> """
      entrypoint: my-entrypoint.sh
      """
    run_generator("minimal", config)
    assert_dockerfile_line("CMD exec my-entrypoint.sh")
  end

  test "minimal directory with environment variables" do
    config = @minimal_config <> """
      env_variables:
        VAR1: value1
        VAR2: value2
        VAR3: 123
      """
    run_generator("minimal", config)
    assert_file_contents(Path.join(@tmp_dir, "Dockerfile"),
      """
      ENV VAR1="value1" \\
          VAR2="value2" \\
          VAR3="123"
      """)
  end

  test "minimal directory with cloudsql instances" do
    config = @minimal_config <> """
      beta_settings:
        cloud_sql_instances:
          - cloud-sql-instance-name,instance2:hi:there
          - instance3
      """
    run_generator("minimal", config)
    assert_dockerfile_line("RUN mkdir /cloudsql")
  end

  test "minimal directory with build scripts" do
    config = @minimal_config <> """
      runtime_config:
        build:
          - npm install
          - brunch build
      """
    run_generator("minimal", config)
    assert_dockerfile_line("RUN npm install")
    assert_dockerfile_line("RUN brunch build")
  end

  test "minimal directory with package installations" do
    config = @minimal_config <> """
      runtime_config:
        packages: libgeos
      """
    run_generator("minimal", config)
    assert_dockerfile_line("    && apt-get install -y -q libgeos")
  end

  defp run_generator(dir, config, args \\ []) do
    config_file = Keyword.get(args, :config_file, nil)
    project = Keyword.get(args, :project, nil)

    File.rm_rf!(@tmp_dir)
    if dir do
      full_dir = Path.join(@cases_dir, dir)
      File.cp_r!(full_dir, @tmp_dir)
    else
      File.mkdir!(@tmp_dir)
    end
    if config_file do
      System.put_env("GAE_APPLICATION_YAML_PATH", config_file)
    else
      System.delete_env("GAE_APPLICATION_YAML_PATH")
    end
    if project do
      System.put_env("PROJECT_ID", project)
    else
      System.delete_env("PROJECT_ID")
    end
    if config do
      @tmp_dir
      |> Path.join(config_file || "app.yaml")
      |> File.write!(config)
    end
    Generator.execute(workspace_dir: @tmp_dir, dockerfile_template: @template_path)
  end

  defp assert_file_contents(path, expectations) do
    expectations = List.wrap(expectations)
    contents = File.read!(path)
    Enum.each(expectations, fn expectation ->
      assert(contents =~ expectation,
        "File #{path} did not contain #{inspect(expectation)}")
    end)
    contents
  end

  defp assert_dockerfile_line(line) do
    line = Regex.escape(line)
    path = Path.join(@tmp_dir, "Dockerfile")
    assert_file_contents(path, ~r{^#{line}}m)
  end

  defp assert_ignore_line(line) do
    line = Regex.escape(line)
    path = Path.join(@tmp_dir, ".dockerignore")
    assert_file_contents(path, ~r{^#{line}}m)
  end

end
