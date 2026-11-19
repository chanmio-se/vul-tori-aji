# frozen_string_literal: true

module CveTriage
  # 直前のスナップショットと今回のスキャン結果を比較し、CVE の追加/更新/削除を検出する。
  class Differ
    STATUS_ORDER = { added: 0, updated: 1, removed: 2 }.freeze

    Change = Struct.new(:status, :current, :previous, keyword_init: true)

    Result = Struct.new(:changes, :snapshot, :previous_snapshot, :first_run, keyword_init: true) do
      # bin/diff が書き出した diff.json を bin/triage で読み戻すための復元メソッド。
      def self.from_h(hash)
        changes = Array(hash["changes"]).map do |change|
          Change.new(
            status: change["status"].to_s.to_sym,
            current: finding_from(change["current"]),
            previous: finding_from(change["previous"])
          )
        end
        new(
          changes: changes,
          snapshot: hash["snapshot"],
          previous_snapshot: hash["previous_snapshot"],
          first_run: hash["first_run"]
        )
      end

      def self.finding_from(hash)
        return nil unless hash.is_a?(Hash)

        Finding.new(
          source: hash["source"],
          target: hash["target"],
          id: hash["id"],
          package: hash["package"],
          installed_version: hash["installed_version"],
          fixed_version: hash["fixed_version"],
          severity: hash["severity"],
          title: hash["title"],
          extra: hash.slice("PrimaryURL", "PublishedDate", "LastModifiedDate")
        )
      end
      private_class_method :finding_from

      def added
        changes.select { |change| change.status == :added }
      end

      def updated
        changes.select { |change| change.status == :updated }
      end

      def removed
        changes.select { |change| change.status == :removed }
      end

      def any?
        !changes.empty?
      end

      def triage_targets
        (added + updated).map(&:current)
      end

      def counts
        { added: added.length, updated: updated.length, removed: removed.length }
      end

      def to_h
        {
          snapshot: snapshot,
          previous_snapshot: previous_snapshot,
          first_run: first_run,
          counts: counts,
          changes: changes.map do |change|
            {
              status: change.status.to_s,
              current: change.current&.to_h,
              previous: change.previous&.to_h
            }
          end
        }
      end
    end

    def initialize(previous:, current:, snapshot: nil, previous_snapshot: nil)
      @previous = index(previous)
      @current = index(current)
      @snapshot = snapshot
      @previous_snapshot = previous_snapshot
    end

    def call
      changes = []
      previous.each do |key, old|
        now = current[key]
        if now.nil?
          changes << Change.new(status: :removed, current: nil, previous: old)
        elsif now.fingerprint != old.fingerprint
          changes << Change.new(status: :updated, current: now, previous: old)
        end
      end
      current.each_key do |key|
        changes << Change.new(status: :added, current: current[key], previous: nil) unless previous.key?(key)
      end

      Result.new(
        changes: sort(changes),
        snapshot: snapshot,
        previous_snapshot: previous_snapshot,
        first_run: previous_snapshot.nil?
      )
    end

    private

    attr_reader :previous, :current, :snapshot, :previous_snapshot

    def index(findings)
      Array(findings).to_h { |finding| [finding.key, finding] }
    end

    def sort(changes)
      changes.sort_by do |change|
        finding = change.current || change.previous
        [
          STATUS_ORDER.fetch(change.status, 99),
          CveTriage::Config::SEVERITIES.index(finding.severity) || 99,
          finding.id.to_s,
          finding.key
        ]
      end
    end
  end
end
