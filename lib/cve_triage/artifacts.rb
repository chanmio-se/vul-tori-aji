# frozen_string_literal: true

module CveTriage
  # スキャンで生成された成果物のパスをまとめた値オブジェクト。
  Artifacts = Struct.new(:vulnerabilities, :sboms, :misconfigurations, keyword_init: true) do
    def self.discover(out_dir)
      dir = Pathname.new(out_dir)
      new(
        vulnerabilities: dir.glob("vuln-*.json").sort,
        sboms: dir.glob("sbom-*.cdx.json").sort,
        misconfigurations: dir.glob("misconfig-*.json").sort
      )
    end

    def all
      vulnerabilities + sboms + misconfigurations
    end
  end
end
