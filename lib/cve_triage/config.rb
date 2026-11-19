# frozen_string_literal: true

module CveTriage
  # スキャン実行に必要な設定を ENV から組み立て、検証する値オブジェクト。
  class Config
    class ValidationError < Error; end

    SEVERITIES = %w[CRITICAL HIGH MEDIUM LOW UNKNOWN].freeze
    SCAN_TYPES = %w[fs image both].freeze
    SAFE_NAME = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/.freeze

    attr_reader :target_name, :out_dir, :target_dir, :scan_type, :scan_ref,
                :image_refs, :severity

    def self.from_env(env = ENV)
      new(
        target_name: required(env, "TARGET_NAME"),
        out_dir: required(env, "OUT_DIR"),
        target_dir: required(env, "TARGET_DIR"),
        scan_type: env.fetch("SCAN_TYPE", "fs"),
        scan_ref: env.fetch("SCAN_REF", "."),
        image_refs: env.fetch("IMAGE_REFS", ""),
        enable_misconfig: truthy?(env.fetch("ENABLE_MISCONFIG", "true")),
        ignore_unfixed: truthy?(env.fetch("IGNORE_UNFIXED", "false")),
        severity: env.fetch("SEVERITY", SEVERITIES.join(","))
      )
    end

    def self.required(env, key)
      value = env[key].to_s.strip
      raise ValidationError, "#{key} is required" if value.empty?

      value
    end
    private_class_method :required

    def self.truthy?(value)
      %w[true 1 yes on].include?(value.to_s.strip.downcase)
    end
    private_class_method :truthy?

    def initialize(target_name:, out_dir:, target_dir:, scan_type: "fs",
                   scan_ref: ".", image_refs: "", enable_misconfig: true,
                   ignore_unfixed: false, severity: SEVERITIES.join(","))
      @target_name = target_name
      @out_dir = Pathname.new(out_dir)
      @target_dir = Pathname.new(target_dir)
      @scan_type = scan_type
      @scan_ref = scan_ref
      @image_refs = image_refs
      @enable_misconfig = enable_misconfig
      @ignore_unfixed = ignore_unfixed
      @severity = severity
      validate!
    end

    def images
      image_refs.lines.map(&:strip).reject(&:empty?)
    end

    def fs_scan?
      scan_type == "fs" || scan_type == "both"
    end

    def image_scan?
      scan_type == "image" || scan_type == "both"
    end

    def enable_misconfig?
      @enable_misconfig
    end

    def ignore_unfixed?
      @ignore_unfixed
    end

    private

    def validate!
      unless SCAN_TYPES.include?(scan_type)
        raise ValidationError, "SCAN_TYPE must be one of #{SCAN_TYPES.join(', ')} (got: #{scan_type})"
      end
      unless SAFE_NAME.match?(target_name)
        raise ValidationError, "invalid TARGET_NAME: #{target_name.inspect}"
      end
      if image_scan? && images.empty?
        raise ValidationError, "IMAGE_REFS is required when SCAN_TYPE is image or both"
      end

      unknown = severity.split(",").map(&:strip) - SEVERITIES
      raise ValidationError, "unknown severity: #{unknown.join(', ')}" unless unknown.empty?
    end
  end
end
