# frozen_string_literal: true

module HathifilesDatabase
  # A class responsible for the list of ids used to cull unnecessary updates to the hf table
  # during a monthly update, and used for deleting entries that no longer exist.
  # It answers the related questions:
  # 1. Was the metadata for this HTID changed or added since the last update?
  # 2. Was this HTID deleted since the last update?
  # Both parameters to the initializer are text files with one HTID per line
  # without any sorting requirements.
  # Can be called with nil for one or both of the files and the behavior will be
  # as if the corresponding file was empty.
  class Delta
    attr_reader :updates, :deletes
    def initialize(updates_file: nil, deletes_file: nil)
      if updates_file.nil?
        @updates = InfiniteSet.new
      else
        @updates = Set.new
        File.readlines(updates_file, chomp: true).each do |htid|
          updates << htid
        end
      end
      @deletes = Set.new
      unless deletes_file.nil?
        File.readlines(deletes_file, chomp: true).each do |htid|
          deletes << htid
        end
      end
    end

    def updated?(htid)
      updates.include? htid
    end

    def deleted?(htid)
      deletes.include? htid
    end

    # A Set that (claims to) contain everything in the universe
    class InfiniteSet < Set
      def include?(arg)
        true
      end
    end
  end
end
