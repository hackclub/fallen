namespace :db do
  # The web and worker containers both migrate on boot, and whichever is second finds the migration lock taken.
  # It waits for the first to finish instead of failing, then runs db:prepare again, which finds nothing to do.
  desc "db:prepare, waiting up to 10 minutes for another process's migrations to finish"
  task prepare_or_wait: :load_config do
    deadline = 10.minutes.from_now
    begin
      Rake::Task["db:prepare"].reenable
      Rake::Task["db:prepare"].invoke
    rescue ActiveRecord::ConcurrentMigrationError
      raise if Time.current > deadline

      puts "Another process is migrating; waiting"
      sleep 5
      retry
    end
  end
end
