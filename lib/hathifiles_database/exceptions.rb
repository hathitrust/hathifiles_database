# frozen_string_literal: true

module HathifilesDatabase
  class WrongNumberOfColumns < StandardError
    attr_accessor :htid

    def initialize(*args, htid:)
      super(*args)
      @htid = htid
    end
  end
end
