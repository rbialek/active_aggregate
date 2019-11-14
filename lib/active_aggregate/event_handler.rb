# -*- encoding : utf-8 -*-
require 'singleton'

#
# Main event handler. current called before accessing any aggregates
#
module ActiveAggregate
  class EventHandler
    include Singleton

    attr_accessor :last_event_id, :listen_to_domains

    def self.current(domains = nil, last_id = nil)
      last_id                    = get_handler_last_id if last_id.to_i < get_handler_last_id
      instance.last_event_id     = last_id
      instance.last_event_id     = 0 if get_handler_last_id < 0 # resetting
      start                      = instance.last_event_id.to_i
      instance.listen_to_domains = domains if domains
      instance.apply_events

      if instance.last_event_id > start && Rails.env.development?
        puts "EventHandler applied events #{start} - #{instance.last_event_id}"
      end
    end

    EVENT_HANDLER_LAST_ID_KEY = "__HANDLER_LAST_ID_#{Rails.env}__"

    def self.set_handler_last_id(id)
      Rails.cache.write(EVENT_HANDLER_LAST_ID_KEY, id)
    end

    def self.get_handler_last_id
      Rails.cache.read(EVENT_HANDLER_LAST_ID_KEY) || ActiveAggregate::EventApplication.maximum(:event_id) || -1
    end

    # list all the sub classes of ActiveAggregate
    # def all_handler_names
    #   return @all_handlers if @all_handlers
    #   @all_handlers = ActiveAggregate::ActiveAggregate.descendants.select do |k|
    #     !k.abstract_class?
    #   end
    # end

    def active_aggregate_handlers(domain)
      # all_handler_names.select do |k|
      #   list = k.listen_to_domains
      #   list.include?(domain)
      # end
      EventSubscriber.instance.get_handlers(domain)
    end

    def apply_events(save = true)
      if applying_events? # avoid recursive application
        return self
      end

      fresh_events.find_in_batches(batch_size: 1000) do |group|
        group.each { |evt|
          apply_event(evt, save)
        }
      end
    end

    def apply_event(evt, doSave = false)
      set_applying_flag true
      # find all handlers that events
      # handlers = EventSubscriber.global.get_handlers(evt.domain)
      handlers = active_aggregate_handlers(evt.domain)
      handlers.collect do |handler|
        handle_and_save(handler, evt, doSave)
      end
    ensure
      set_applying_flag false
    end

    def handle_and_save(handler, evt, doSave = false)
      aggr = handle(evt, handler.aggregate_class)
      if aggr
        # if an evt was applied then record the change in the db
        # toSave.add([aggr, evt])
        save_aggregate(aggr, evt) if doSave
      end
    end

    def handle(evt, klass)
      aggr        = find_aggregate(evt, klass, :allow_new)
      handlerName = ActiveAggregate::Base.handler_name("handle", evt.type)

      self.last_event_id = evt.id
      EventHandler.set_handler_last_id(evt.id) # shared cache value
      has_handler = aggr.class.method_defined?(handlerName)
      if has_handler && apply_event?(aggr, evt) # we only apply events that were not applied
        Rails.logger.debug("#{self} handle apply #{evt.type}.#{evt.id} on #{aggregate_name(aggr)}")
        aggr.send(handlerName, evt) # call aggr.handleSaleNew(evt)

        klass.set_last_event_id(evt.id)

        aggr.created_at ||= evt.created_at
        aggr.updated_at = evt.created_at
        aggr.set_last_event_id(evt.id) # remember last id on the Aggregate

        return aggr
      elsif !Rails.env.production? && has_handler
        Rails.logger.debug("#{self} handle skip #{evt.id} on #{aggregate_name(aggr)}")
      end
      # apply last event to avoid re-querying events table even if not applied
      aggr.set_last_event_id(evt.id) if aggr
      return false
    end

    # @return true if the event should be applied to this aggregate
    # (it hasn't been applied yet)
    def apply_event?(aggr, event)
      ok1 = event.id > aggr.get_last_event_id
      ok2 = aggr.class.listen_to_domains.include?(event.domain)
      ok1 && ok2
    end

    def save_aggregate(aggr, evt)
      aggr.saving_from_event_handler = true
      EventApplication.transaction do
        if aggr.save
          record_applied_event(aggr, evt)
          Rails.logger.debug("save_aggregate: #{aggregate_name(aggr)}")
        else
          msg = aggr.errors.to_json
          record_failed_event(aggr, evt, msg)
          Rails.logger.error("Error saving Aggregate for evt.id =  #{evt.id} #{msg}")
        end
      end
    end

    # finds aggregate using uuid or a previous evt
    def find_aggregate(event_or_uuid, klass = aggregate_class, allow_new = false)
      return nil unless event_or_uuid

      uuid = event_or_uuid
      # if we extract uuid from previous evt
      if event_or_uuid.is_a?(ActiveAggregate::EventBase)
        uuid = event_or_uuid.get_aggregate_uuid(klass.listen_to_domains.first)
      end
      aggr ||= klass.find_by_uuid(uuid) # then load from db
      if !aggr && allow_new
        aggr = klass.new_aggregate(uuid)
      end
      return aggr
    end

    def fresh_events
      scoped = ActiveAggregate::EventBase.where("events.id > ?", get_last_event_id)
      scoped = scoped.where(domain: listen_to_domains) if (listen_to_domains && listen_to_domains != '*')
      scoped
    end

    def record_applied_event(aggr, evt)
      # record related events only if aggregate is already saved
      if aggr.persisted?
        pars = {aggregate_type: aggr.class.name,
                aggregate_id:   aggr.id,
                event_id:       evt.id}
        ea   = EventApplication.unscoped.create(pars)
        return ea
      end
    end

    def record_failed_event(aggr, evt, error)
      pars = {aggregate_type: aggr.class.name,
              aggregate_id:   aggr.id,
              event_id:       evt.id,
              error:          error}
      ea   = EventApplicationError.unscoped.create(pars)
      return ea
    end

    private

    def aggregate_name(aggr)
      "#{aggr.class.name}.#{aggr.id || 'NEW'} last_id: #{last_event_id}"
    end

    def get_last_event_id
      self.last_event_id ||= 0
      self.last_event_id
    end

    def set_applying_flag(val)
      @applying_events = val
    end

    def applying_events?
      !!@applying_events
    end

  end
end