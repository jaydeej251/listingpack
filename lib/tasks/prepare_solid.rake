namespace :db do
  desc "Load Solid Queue/Cache/Cable schemas when they share DATABASE_URL"
  task prepare_solid: :environment do
    {
      "queue" => [ "db/queue_schema.rb", "solid_queue_recurring_tasks" ],
      "cache" => [ "db/cache_schema.rb", "solid_cache_entries" ],
      "cable" => [ "db/cable_schema.rb", "solid_cable_messages" ]
    }.each do |name, (schema, table)|
      config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
      next unless config

      ActiveRecord::Base.establish_connection(config)
      if ActiveRecord::Base.connection.data_source_exists?(table)
        puts "==> #{name} already has #{table}"
        next
      end

      puts "==> Loading #{schema} (#{name})"
      load Rails.root.join(schema)
    end
  ensure
    primary = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
    ActiveRecord::Base.establish_connection(primary) if primary
  end
end

# Hatchbox runs `db:migrate`, not `db:prepare`. Attach Solid schemas so queue/cache/cable
# tables exist when they share DATABASE_URL (the usual single-Postgres setup).
if Rake::Task.task_defined?("db:migrate")
  Rake::Task["db:migrate"].enhance do
    Rake::Task["db:prepare_solid"].invoke
  end
end
