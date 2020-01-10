# -*- encoding : utf-8 -*-
#
# Aggregate records are models that can change their states by applying
# events to them
#
module ActiveAggregate

  class Base < ActiveRecord::Base
    self.abstract_class = true

    include EventHandlerUtils
    include LastEventConcern
    include HandlerConcern

    cattr_accessor :listen_to_domains, :last_event_ids

    def self.all_handler_names
      raise("Overwrite in subclass")
    end

    # Called at boot time
    def self.load_all_children
      subscriber = EventSubscriber.instance
      puts "Loading ActiveAggregate handlers: #{all_handler_names.join(',')}"
      all_handler_names.each do |name|
        k = name.constantize
        subscriber.add_handler(k)
      end
    end


    # apply all created events before returning self
    def self.current
      ActiveAggregate::EventHandler.current
      self
    end

    # default active aggregate primary key
    def self.uuid_key
      :uuid
    end

    def to_param
      uuid
    end

    def self.new_aggregate(uuid = nil)
      new(uuid_key => uuid)
    end

    def self.aggregate_class
      self
    end

    def self.find_by_uuid(uuid)
      id = uuid || -1
      where(uuid_key => id).first
    end

    def info(extended = false)
      str = "#{self.name} applied last_event_id: #{get_last_event_id} no_aggregates: #{count}"
      # str += " [ #{aggregate_keys.join(',')} ]" if extended
      puts str
      str
    end

    attr_writer :saving_from_event_handler

    def save(*args, &block)
      raise Exceptions::Exception("persistence? returned false for #{self.class.name}") unless self.class.persistent_aggregate?

      if @saving_from_event_handler
        @saving_from_event_handler = false
        super
      else
        raise Exceptions::Exception('Save allowed only by applying events')
      end
    rescue => e
      return false
    end

    # @return events directly linked and applied to this aggregate
    def events
      ActiveAggregate::EventBase.where(uuid: uuid)
    end

    # @return all events applied to this aggregate using event_applications
    def applied_events(name = self.class.name)
      ActiveAggregate::EventNoSti.includes(:event_applications)
          .where('event_applications.aggregate_id'   => id,
                 'event_applications.aggregate_type' => name)
          .order("events.id DESC")

    end

  end
end