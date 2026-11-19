# frozen_string_literal: true

module CveTriage
  module Reports
    # Trivy config スキャンの検出件数を返す。
    class Misconfigurations
      def initialize(path)
        @path = Pathname.new(path)
        @data = JSON.parse(@path.read)
      end

      def count
        Array(@data["Results"]).sum { |result| Array(result["Misconfigurations"]).length }
      end
    end
  end
end
