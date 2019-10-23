# frozen_string_literal: true

module HathifilesDatabase
  module Exception
    class WrongNumberOfColumns < StandardError
      attr_accessor :htid, :count, :expected

      def initialize(*args, htid:, count:, expected:)
        super(*args)
        @htid = htid
        @count = count
        @expected = expected
      end

      def to_s
        super + " htid = #{@htid} has #{@count} items (expected #{@expected})"
      end
    end
  end
end
