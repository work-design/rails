# frozen_string_literal: true

require "active_record/middleware/database_selector/resolver/session"

module ActiveRecord
  module Middleware
    class DatabaseSelector
      # The Resolver class is used by the DatabaseSelector middleware to
      # determine which database the request should use.
      #
      # To change the behavior of the Resolver class in your application,
      # create a custom resolver class that inherits from
      # DatabaseSelector::Resolver and implements the methods that need to
      # be changed.
      #
      # By default the Resolver class will send read traffic to the replica
      # if it's been 2 seconds since the last write.
      class Resolver # :nodoc:
        SEND_TO_REPLICA_DELAY = 2.seconds

        def self.call(resolver, options = {})
          new(resolver, options)
        end

        def initialize(resolver, options = {})
          @resolver = resolver
          @options = options
          @delay = @options && @options[:delay] ? @options[:delay] : SEND_TO_REPLICA_DELAY
          @instrumenter = ActiveSupport::Notifications.instrumenter
        end

        attr_reader :resolver, :delay, :instrumenter

        def read(&blk)
          if read_from_primary?
            read_from_primary(&blk)
          else
            read_from_replica(&blk)
          end
        end

        def write(&blk)
          write_to_primary(&blk)
        end

        private

          def read_from_primary(&blk)
            ActiveRecord::Base.connection.while_preventing_writes do
              ActiveRecord::Base.connected_to(role: :writing) do
                instrumenter.instrument("database_selector.active_record.read_from_primary") do
                  yield
                end
              end
            end
          end

          def read_from_replica(&blk)
            ActiveRecord::Base.connected_to(role: :reading) do
              instrumenter.instrument("database_selector.active_record.read_from_replica") do
                yield
              end
            end
          end

          def write_to_primary(&blk)
            ActiveRecord::Base.connected_to(role: :writing) do
              instrumenter.instrument("database_selector.active_record.wrote_to_primary") do
                yield
              ensure
                resolver.update_last_write_timestamp
              end
            end
          end

          def read_from_primary?
            !time_since_last_write_ok?
          end

          def send_to_replica_delay
            delay
          end

          def time_since_last_write_ok?
            Time.now - resolver.last_write_timestamp >= send_to_replica_delay
          end
      end
    end
  end
end
