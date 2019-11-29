# -*- encoding : utf-8 -*-
# == Schema Information
#
# Table name: events
#
#  id              :bigint(8)        not null, primary key
#  domain          :string(255)
#  payload         :text(65535)
#  type            :string(255)
#  uuid            :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  current_user_id :integer
#  user_id         :integer
#
# Indexes
#
#  index_events_on_current_user_id  (current_user_id)
#  index_events_on_domain_and_uuid  (domain,uuid)
#  index_events_on_user_id          (user_id)
#  index_events_on_uuid             (uuid)
#
module ActiveAggregate
  class EventBase < ApplicationRecord
    self.abstract_class = true
    self.table_name     = 'events'

    has_many :event_applications, foreign_key: 'event_id', class_name: 'ActiveAggregate::EventApplication'

    def self.save_and_apply(opts)
      new(opts).save_and_apply
    end

    def self.domains(*domains)
      domains.present? ? where(domain: domains) : all
    end

    # executed within create transaction
    before_create :set_event_values
    before_create :set_unique_uuid
    after_create_commit :set_checksum

    def after_initialize_block
      # overwrite
    end

    def save_and_apply
      if save
        EventHandler.current
        return true
      end
      false
    end

    def initialize(pars = {})
      super
      after_initialize_block
    end

    # Create object using only my attributes
    def self.safe_new(pars)
      obj = new
      # find all setters
      mykeys         = obj.methods \
          .select { |m| m.to_s.ends_with?("=") } \
          .collect { |m| m.to_s[0..-2] }
      mypars         = pars.stringify_keys.slice(*mykeys)
      obj.attributes = mypars
      obj.after_initialize_block
      obj
    end

    def self.event_domain
      "unknown"
    end

    # never link directly to the event
    # Instead always link to the uuid of the aggregate
    def to_param
      uuid
    end

    # used in forms
    def event_id
      [self.class.name.underscore, id || 'new'].join("_")
    end

    # fetch aggregate uuid, defaults to uuid
    # can be overwritten when handling an event in an other domain
    # Example when tx event is handled by sale eventh handler it shall use the
    # sale_uuid rather than uuid.
    # @param d represents the event handler domain that is calling this method
    #
    def get_aggregate_uuid(d = domain)
      uuid
    end

    # set missing default values called before_create
    def set_event_values
      self.domain ||= self.class.event_domain
    end

    def fresh_uuid
      SecureRandom.uuid
    end

    # check if the new uuid is not used in the db
    # name clash is highly unlikely
    def set_unique_uuid
      while (uuid.blank?)
        fresh = fresh_uuid
        if ActiveAggregate::EventBase.where(uuid: fresh).present?
          puts "Event with uuid = #{fresh} found!"
        else
          self.uuid = fresh
        end
      end
    end

    def set_checksum
      if checksum.blank?
        update_attribute :checksum, calculate_checksum
      end
    end

    def previous_event
      old = id || EventBase::maximum(:id).to_i
      EventBase.find_by_id(old - 1)
    end

    # calculate checksum using this event params (except id, updated_at, checksum) and
    # using previous event checksum to achieve a block chain like event chain where no events
    # can be altered without breaking the checksum chain link
    def calculate_checksum
      last_checksum = previous_event&.checksum
      attrs         = attributes.except("checksum", "id", "updated_at").merge(last_checksum: last_checksum)
      cs            = Digest::SHA256.hexdigest(attrs.to_s)
      puts "#{id} calculate_checksum: #{cs} <- #{attrs} " if Rails.env.development?
      Rails.logger.info("#{id} calculate_checksum: #{cs} <- #{attrs} ")
      return cs
    end
  end
end