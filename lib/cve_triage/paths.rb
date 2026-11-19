# frozen_string_literal: true

module CveTriage
  # 成果物のファイル名を一箇所で定義する。
  class Paths
    attr_reader :out_dir

    def initialize(out_dir)
      @out_dir = Pathname.new(out_dir)
    end

    def prepare!
      out_dir.mkpath
      self
    end

    def vuln_fs
      out_dir.join("vuln-fs.json")
    end

    def sbom_fs
      out_dir.join("sbom-fs.cdx.json")
    end

    def misconfig_fs
      out_dir.join("misconfig-fs.json")
    end

    def vuln_image(slug)
      out_dir.join("vuln-image-#{slug}.json")
    end

    def sbom_image(slug)
      out_dir.join("sbom-image-#{slug}.cdx.json")
    end

    def summary
      out_dir.join("summary.md")
    end

    def meta
      out_dir.join("meta.json")
    end

    # trivy が失敗した際に古い成果物が残らないよう、実行前に該当ファイルを消す。
    def clean!(path)
      FileUtils.rm_f(path)
    end
  end
end
