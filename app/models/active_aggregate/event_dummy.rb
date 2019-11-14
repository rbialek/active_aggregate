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
  class EventDummy < EventBase
  end
end