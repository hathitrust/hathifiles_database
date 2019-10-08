# frozen_string_literal: true

module HathifilesDatabase
  module Exception
    class WrongNumberOfColumns < StandardError
      attr_accessor :htid

      def initialize(*args, htid:)
        super(*args)
        @htid = htid
      end

      def to_s
        super + "\nhtid = #{@htid}"
      end
    end
  end
end
