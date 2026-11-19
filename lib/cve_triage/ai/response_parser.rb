# frozen_string_literal: true

module CveTriage
  module Ai
    # Copilot の応答（JSON または ```json フェンス付き JSON）を TriageResult 用に正規化する。
    class ResponseParser
      class ResponseError < CveTriage::Error; end

      PRIORITIES = %w[P0 P1 P2 P3].freeze
      CONFIDENCES = %w[high medium low].freeze
      MAX_TEXT = 1_000

      class Assessment < Struct.new(:key, :priority, :rationale, :recommended_action, :confidence, keyword_init: true)
        def to_h
          { key: key, priority: priority, rationale: rationale,
            recommended_action: recommended_action, confidence: confidence }
        end
      end

      def self.call(text, keys:)
        new(text, keys: keys).call
      end

      def initialize(text, keys)
        @text = text.to_s
        @keys = Array(keys).map(&:to_s)
      end

      def call
        entries = extract_entries
        raise ResponseError, "no findings in AI response" if entries.empty?

        entries.filter_map { |entry| assessment(entry) }
               .uniq(&:key)
               .tap { |result| raise ResponseError, "no valid findings in AI response" if result.empty? }
      end

      private

      attr_reader :text, :keys

      def extract_entries
        data = JSON.parse(extract_json(text))
        case data
        when Array then data
        when Hash then Array(data["findings"] || data["assessments"])
        else []
        end
      rescue JSON::ParserError => e
        raise ResponseError, "AI response is not valid JSON (#{e.message.lines.first&.chomp})"
      end

      # モデルが ```json ... ``` で返してくることがあるので、最初の { から最後の } だけを読む。
      def extract_json(value)
        start = [value.index("{"), value.index("[")].compact.min
        finish = [value.rindex("}"), value.rindex("]")].compact.max
        raise ResponseError, "AI response contains no JSON" unless start && finish && finish >= start

        value[start..finish]
      end

      def assessment(entry)
        return nil unless entry.is_a?(Hash)

        key = entry["key"].to_s
        return nil if key.empty? || !keys.include?(key)

        Assessment.new(
          key: key,
          priority: normalize(entry["priority"], PRIORITIES, "P3"),
          rationale: clamp(entry["rationale"]),
          recommended_action: clamp(entry["recommended_action"]),
          confidence: normalize(entry["confidence"], CONFIDENCES, "low")
        )
      end

      def normalize(value, allowed, fallback)
        normalized = value.to_s.strip
        allowed.find { |candidate| candidate.casecmp?(normalized) } || fallback
      end

      def clamp(value)
        value.to_s.strip[0, MAX_TEXT]
      end
    end
  end
end
