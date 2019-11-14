# -*- encoding : utf-8 -*-
# == Schema Information
#
# Table name: event_applications
#
#  id             :bigint(8)        not null, primary key
#  aggregate_type :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  aggregate_id   :integer
#  event_id       :integer
#
# Indexes
#
#  index_event_applications_on_aggregate_type_and_aggregate_id  (aggregate_type,aggregate_id)
#

# Stores each applications of an event to an aggregate
# It's there for traceability purpose
module ActiveAggregate

  class EventApplication < ApplicationRecord
    self.table_name = 'event_applications'
    belongs_to :event, foreign_key: :event_id, class_name: 'ActiveAggregate::EventBase'
    # belongs_to :aggregate_record, polymorphic: true
  end

end