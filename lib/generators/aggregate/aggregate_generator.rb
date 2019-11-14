require "rails/generators/active_record/model/model_generator"
# require "rails/generators/model_helpers"
class AggregateGenerator < ActiveRecord::Generators::ModelGenerator
  source_root File.expand_path('templates', __dir__)
end
