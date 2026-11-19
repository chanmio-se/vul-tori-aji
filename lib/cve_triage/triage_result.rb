# frozen_string_literal: true

module CveTriage
  # AI トリアージ結果を永続化・描画するための値オブジェクト。
  class TriageResult
    def initialize(diff:, assessments:, model:, generated_at:, status: "ok", error: nil)
      @diff = diff
      @assessments = assessments
      @model = model
      @generated_at = generated_at
      @status = status
      @error = error
    end

    def to_h
      {
        status: status,
        model: model,
        generated_at: generated_at,
        snapshot: diff.snapshot,
        previous_snapshot: diff.previous_snapshot,
        counts: diff.counts.merge(triaged: assessments.length),
        error: error,
        findings: assessments.map { |assessment| row(assessment) }
      }
    end

    def render
      lines = []
      lines << "# CVE triage: #{diff.snapshot || '-'}"
      lines << ""
      lines << "- Status: **#{status}**"
      lines << "- Model: `#{model || '(default)'}`"
      lines << "- Generated at: **#{generated_at}**"
      lines << "- Previous snapshot: `#{diff.previous_snapshot || '(none)'}`"
      lines << ""
      if status == "error"
        lines << "AI triage failed: #{escape(error.to_s.lines.first&.chomp)}"
        lines << ""
        return lines.join("\n")
      end
      if status == "skipped"
        lines << "新規・更新 CVE がないため AI トリアージをスキップしました。"
        lines << ""
        return lines.join("\n")
      end
      if assessments.empty?
        lines << "AI から有効な評価を取得できませんでした。"
        lines << ""
        return lines.join("\n")
      end

      lines << "| Priority | CVE | Package | Severity | Rationale | Recommended action | Confidence |"
      lines << "|---|---|---|---|---|---|---|"
      assessments.each do |assessment|
        finding = findings_by_key[assessment.key]
        lines << "| #{assessment.priority} | #{finding&.id || '-'} | #{finding&.package || '-'} | " \
                 "#{finding&.severity || '-'} | #{escape(assessment.rationale)} | " \
                 "#{escape(assessment.recommended_action)} | #{assessment.confidence} |"
      end
      lines << ""
      lines.join("\n")
    end

    private

    attr_reader :diff, :assessments, :model, :generated_at, :status, :error

    def findings_by_key
      @findings_by_key ||= diff.triage_targets.to_h { |finding| [finding.key, finding] }
    end

    def row(assessment)
      finding = findings_by_key[assessment.key]
      assessment.to_h.merge(
        cve: finding&.id,
        package: finding&.package,
        severity: finding&.severity
      )
    end

    def escape(value)
      value.to_s.gsub("|", "\\|").gsub("\n", " ")
    end
  end
end
