# frozen_string_literal: true

module CveTriage
  # trivy CLI へのコマンド組み立てだけを担当する。
  class Trivy
    def initialize(runner: CommandRunner.new)
      @runner = runner
    end

    def fs_vulnerabilities(path:, output:, severity:, ignore_unfixed: false)
      command("fs", "--scanners", "vuln", *json_output(output),
              *severity_args(severity, ignore_unfixed), path.to_s)
    end

    def fs_sbom(path:, output:)
      command("fs", *cyclonedx_output(output), path.to_s)
    end

    def config(path:, output:, severity:)
      command("config", *json_output(output), "--severity", severity,
              "--exit-code", "0", path.to_s)
    end

    def image_vulnerabilities(image:, output:, severity:, ignore_unfixed: false)
      command("image", "--scanners", "vuln", *json_output(output),
              *severity_args(severity, ignore_unfixed), image)
    end

    def image_sbom(image:, output:)
      command("image", *cyclonedx_output(output), image)
    end

    private

    def command(*args)
      @runner.run("trivy", *args)
    end

    def json_output(path)
      ["--format", "json", "--output", path.to_s]
    end

    def cyclonedx_output(path)
      ["--format", "cyclonedx", "--output", path.to_s]
    end

    def severity_args(severity, ignore_unfixed)
      args = ["--severity", severity, "--exit-code", "0"]
      args << "--ignore-unfixed" if ignore_unfixed
      args
    end
  end
end
