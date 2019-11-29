namespace :aggregates do

  task :clean => :environment do
    # set share counter to reply all events
    ActiveAggregate::EventHandler.set_handler_last_id(-1)

    classes = ActiveAggregate::Base.descendants.select do |k|
      !k.abstract_class?
    end
    classes << ActiveAggregate::EventApplication

    ActiveRecord::Base.connection.execute "SET FOREIGN_KEY_CHECKS = 0;"
    classes.each { |klass|
      puts "Truncating table:\t #{klass.name} / #{klass.table_name}"
      klass.destroy_all # triggers model callbacks
      klass.connection.truncate(klass.table_name)
    }
    ActiveRecord::Base.connection.execute "SET FOREIGN_KEY_CHECKS = 1;"
  end

  task :clear_all => :environment do
    raise("Not allowed in production") if Rails.env.production?
    ActiveRecord::Base.connection.execute "SET FOREIGN_KEY_CHECKS = 0;"
    ActiveAggregate::EventApplication.destroy_all
    ActiveRecord::Base.connection.execute("TRUNCATE events;")
    # ActiveAggregate::EventBase.destroy_all
    ActiveRecord::Base.connection.execute "SET FOREIGN_KEY_CHECKS = 1;"
  end

end
