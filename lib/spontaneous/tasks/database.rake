
namespace :spot do
  desc "Migrate the core Spontaneous database"
  task :migrate do
    Spontaneous.database.logger = Spontaneous.logger
    Sequel.extension :migration
    Sequel::Migrator.apply(Spontaneous.database, Spontaneous.gem_dir('db/migrations'))
  end
end

namespace :db do
  desc "Make a dump of the current database"
  task :dump do
    dumpfilename = ENV['dumpfile']
    if dumpfilename.nil?
      dumpfilename = "#{Time.now.to_i}.mysql.gz"
    end
    dump_file = "tmp/#{dumpfilename}"
    dumper = Spontaneous::Utils::Database.dumper_for_database
    # Spontaneous::Cli::Site::MySQL.new(Spontaneous.database)
    dumper.dump(dump_file)
  end

  desc "Load a database dump into the local database"
  task :load do
    dumpfile = ENV['dumpfile']
    if dumpfile.nil?
      $stderr.puts "Usage: rake spot:database:load dumpfile=/path/to/dump.mysql.gz"
      exit 1
    end
    dumper = Spontaneous::Utils::Database.dumper_for_database
    # dumper = Spontaneous::Cli::Site::MySQL.new(Spontaneous.database)
    dumper.load(dumpfile)
  end
end
