# frozen_string_literal: true

module CveTriage
  # イメージ参照を成果物ファイル名に使える文字列へ変換する。
  module Slugger
    module_function

    def call(value)
      value.to_s.gsub(/[^A-Za-z0-9._-]+/, "_")
    end
  end
end
