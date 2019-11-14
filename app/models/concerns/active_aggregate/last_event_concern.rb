require 'active_support/concern'
module ActiveAggregate
  module LastEventConcern
    extend ActiveSupport::Concern

    class_methods do
      def last_event_id
        @@last_event_ids       ||= {}
        @@last_event_ids[name] ||= 0
      end

      def set_last_event_id(id)
        @@last_event_ids       ||= {}
        @@last_event_ids[name] ||= id
      end
    end

    included do
      # if we don't have an attribute in the db, set it there
      # attr_accessor :last_event_id unless has_attribute?("last_event_id")
    end

    def set_last_event_id(new_id, reset = false)
      if has_attribute?(:last_event_id)
        #puts "set_last_event_id #{self.to_s}.last_event_id = #{new_id}"
        self.last_event_id = new_id if reset || get_last_event_id.to_i < new_id
      end
    end

    def get_last_event_id
      if has_attribute?(:last_event_id)
        self.last_event_id ||= 0 # self.class.last_event_id
      else
        self.class.last_event_id
      end
    end

  end
end