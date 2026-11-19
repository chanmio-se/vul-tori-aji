# frozen_string_literal: true

module CveTriage
  # Trivy の各スキャンを順番に実行し、生成された成果物を返す。
  class Scanner
    class Error < CveTriage::Error; end

    def initialize(config:, paths:, trivy: Trivy.new, logger: nil)
      @config = config
      @paths = paths
      @trivy = trivy
      @logger = logger || ->(message) { $stderr.puts(message) }
    end

    def run
      paths.prepare!
      artifacts = Artifacts.new(vulnerabilities: [], sboms: [], misconfigurations: [])

      scan_filesystem(artifacts) if config.fs_scan?
      scan_images(artifacts) if config.image_scan?

      artifacts
    end

    private

    attr_reader :config, :paths, :trivy, :logger

    def scan_filesystem(artifacts)
      source = config.target_dir.join(config.scan_ref)
      raise Error, "scan path not found: #{source}" unless source.exist?

      logger.call("==> Trivy filesystem vulnerability scan (#{source})")
      paths.clean!(paths.vuln_fs)
      trivy.fs_vulnerabilities(path: source, output: paths.vuln_fs,
                               severity: config.severity,
                               ignore_unfixed: config.ignore_unfixed?)
      artifacts.vulnerabilities << paths.vuln_fs

      logger.call("==> Trivy filesystem SBOM (CycloneDX)")
      paths.clean!(paths.sbom_fs)
      trivy.fs_sbom(path: source, output: paths.sbom_fs)
      artifacts.sboms << paths.sbom_fs

      return unless config.enable_misconfig?

      logger.call("==> Trivy config scan (#{source})")
      paths.clean!(paths.misconfig_fs)
      begin
        trivy.config(path: source, output: paths.misconfig_fs, severity: config.severity)
        artifacts.misconfigurations << paths.misconfig_fs if paths.misconfig_fs.exist?
      rescue CommandRunner::Error => e
        logger.call("warning: config scan did not complete; continuing. (#{e.message.lines.first&.chomp})")
      end
    end

    def scan_images(artifacts)
      config.images.each do |image|
        slug = Slugger.call(image)

        logger.call("==> Trivy image vulnerability scan (#{image})")
        vuln_path = paths.vuln_image(slug)
        paths.clean!(vuln_path)
        trivy.image_vulnerabilities(image: image, output: vuln_path,
                                    severity: config.severity,
                                    ignore_unfixed: config.ignore_unfixed?)
        artifacts.vulnerabilities << vuln_path

        logger.call("==> Trivy image SBOM (CycloneDX) (#{image})")
        sbom_path = paths.sbom_image(slug)
        paths.clean!(sbom_path)
        trivy.image_sbom(image: image, output: sbom_path)
        artifacts.sboms << sbom_path
      end
    end
  end
end
