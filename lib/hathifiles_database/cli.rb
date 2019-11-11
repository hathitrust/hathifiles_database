require 'date'
require 'hanami/cli'

module HathifilesDatabase
  module CLI
    module Commands
      extend Hanami::CLI::Registry

      class Date8 < Date

        def to_s
          self.strftime('%Y%m%d')
        end

        def self.range_since(dt)
          dateify(dt).upto self.today
        end

        def self.dateify(dt)
          if dt.respond_to? :to_date
            dt.to_date
          else
            self.parse(dt.to_s)
          end
        end
      end

      class Update



      end

    end
  end
end
