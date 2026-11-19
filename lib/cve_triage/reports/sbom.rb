# frozen_string_literal: true

module CveTriage
  module Reports
    # CycloneDX SBOM のコンポーネント数を返す。
    class Sbom
      def initialize(path)
        @path = Pathname.new(path)
        @data = JSON.parse(@path.read)
      end

      def component_count
        Array(@data["components"]).length
      end
    end
  end
end
