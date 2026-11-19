# frozen_string_literal: true

module CveTriage
  # Trivy の 1 件の脆弱性を、スナップショット間で比較できる形に正規化した値オブジェクト。
  #
  # key         : 同一性（どの成果物のどのターゲットで、どのパッケージのどのバージョンか）
  # fingerprint : 更新判定（修正版・重要度・タイトルが変わったら updated とみなす）
  Finding = Struct.new(
    :source, :target, :id, :package, :installed_version,
    :fixed_version, :severity, :title, :extra,
    keyword_init: true
  ) do
    def key
      [source, target, id, package, installed_version].map(&:to_s).join("|")
    end

    def fingerprint
      [severity, fixed_version, title].map(&:to_s).join("|")
    end

    def to_h
      {
        key: key,
        source: source,
        target: target,
        id: id,
        package: package,
        installed_version: installed_version,
        fixed_version: fixed_version,
        severity: severity,
        title: title
      }.merge(extra || {})
    end

    # AI への入力は最小限にする（プロンプトの肥大化と機微情報の流出を防ぐ）。
    def to_prompt_h
      {
        key: key,
        id: id,
        package: package,
        installed_version: installed_version,
        fixed_version: fixed_version,
        severity: severity,
        title: title.to_s[0, 300],
        primary_url: (extra || {})["PrimaryURL"]
      }.compact
    end
  end
end
