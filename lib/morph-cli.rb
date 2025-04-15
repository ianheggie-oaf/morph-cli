require "morph-cli/version"
require 'yaml'
require 'find'
require 'filesize'

module MorphCLI
  REQUEST_DUMP_FILENAME = "tmp/dump-data-sqlite"
  DATABASE_DUMP = "tmp/data.sql"

  def self.execute(directory, _development, env_config)
    flag_filename = File.join(directory, REQUEST_DUMP_FILENAME)
    dump_filename = File.join(directory, DATABASE_DUMP)
    db_filename = File.join(directory, 'data.sqlite')
    all_paths = MorphCLI.all_paths(directory)

    unless all_paths.find { |file| /scraper\.\w+$/ =~ file }
      $stderr.puts "Can't find scraper to upload. Expected to find a file called scraper.rb, scraper.php, scraper.py, scraper.pl, scraper.js, etc to upload"
      FileUtils.rm_f(flag_filename)
      exit(1)
    end

    # Flag the dumping of the database to log
    FileUtils.mkdir_p(File.dirname(flag_filename))
    File.write(flag_filename, Time.now.to_s)
    all_paths << REQUEST_DUMP_FILENAME

    size = MorphCLI.get_dir_size(directory, all_paths)
    puts "Uploading #{size}..."

    file = MorphCLI.create_tar(directory, all_paths)
    buffer = ""
    dump_state = { path: dump_filename }
    block = Proc.new do |http_response|
      if http_response.code == "200"
        http_response.read_body do |line|
          before, match, after = line.rpartition("\n")
          buffer += before + match
          buffer.split("\n").each do |l|
            log(l, dump_state)
          end
          buffer = after
        end
        if dump_state[:found_dump]
          puts "Database dump saved to #{DATABASE_DUMP} and restored to data.sqlite"
          FileUtils.rm_f(db_filename)
          system "sqlite3 '#{db_filename}' < '#{dump_filename}'"
        end
      elsif http_response.code == "401"
        raise RestClient::Unauthorized
      else
        puts http_response.body
        exit(1)
      end
    end
    if env_config.key?(:timeout)
      timeout = env_config[:timeout]
    else
      timeout = 600 # 10 minutes should be "enough for everyone", right?
      # Setting to nil will disable the timeout entirely.
      # Default is 60 seconds.
    end
    puts "Running on morph.io with timeout #{timeout} seconds ..."
    RestClient::Request.execute(:method => :post, :url => "#{env_config[:base_url]}/run",
                                :payload => { :api_key => env_config[:api_key], :code => file },
                                :block_response => block,
                                :timeout => timeout)
  ensure
    FileUtils.rm_f(flag_filename)
  end

  def self.log(line, dump_state)
    unless line.empty?
      a = JSON.parse(line)
      s = case a["stream"]
          when "stdout", "internalout"
            handle_dump(a, dump_state)
            $stdout
          when "stderr"
            $stderr
          else
            raise "Unknown stream"
          end

      s.puts a["text"]
    end
  end

  def self.config_path
    File.join(Dir.home, ".morph")
  end

  def self.save_config(config)
    File.open(config_path, "w") { |f| f.write config.to_yaml }
    File.chmod(0600, config_path)
  end

  DEFAULT_CONFIG = {
    development: {
      base_url: "http://127.0.0.1:3000"
    },
    production: {
      base_url: "https://morph.io"
    }
  }

  def self.load_config
    if File.exists?(config_path)
      YAML.load(File.read(config_path))
    else
      DEFAULT_CONFIG
    end
  end

  def self.in_directory(directory)
    cwd = FileUtils.pwd
    FileUtils.cd(directory)
    yield
  ensure
    FileUtils.cd(cwd)
  end

  def self.create_tar(directory, paths)
    _tempfile = File.new('/tmp/out', 'wb')

    in_directory(directory) do
      begin
        tar = Archive::Tar::Minitar::Output.new("/tmp/out")
        paths.each do |entry|
          Archive::Tar::Minitar.pack_file(entry, tar)
        end
      ensure
        tar.close
      end
    end
    File.new('/tmp/out', 'r')
  end

  def self.get_dir_size(directory, paths)
    size = 0
    in_directory(directory) do
      paths.each { |entry| size += File.size(entry) }
    end
    Filesize.from("#{size} B").pretty
  end

  # Relative paths to all relevant the files in the given directory (recursive)
  # Uses git ls-files if .git directory exists, otherwise falls back to Find
  # Ignores /screenshots, /spec (and other test) directories and *.md files in both cases
  def self.all_paths(directory)
    result = []
    if File.directory?(File.join(directory, '.git'))
      # Use git ls-files to get all tracked files
      result = []
      in_directory(directory) do
        git_files = `git ls-files`.split("\n")
        result = git_files.reject do |path|
          path.start_with?('features/') ||
            path.start_with?('spec/') ||
            path.start_with?('screenshots/') ||
            path.start_with?('test/') ||
            path.end_with?('.md')
        end
      end
      result
    else
      Find.find(directory) do |path|
        if FileTest.directory?(path)
          if File.basename(path).start_with?(".") ||
            path.end_with?("/coverage") ||
            path.end_with?("/screenshots") ||
            path.end_with?("/features") ||
            path.end_with?("/spec") ||
            path.end_with?("/test") ||
            path.end_with?("/tmp")
            Find.prune
          end
        else
          next if path.end_with?("data.sqlite") || path.end_with?(".md")

          result << Pathname.new(path).relative_path_from(Pathname.new(directory)).to_s
        end
      end
    end
    result
  end

  # Relative path of database file (if it exists)
  def self.database_path(directory)
    path = "data.sqlite"
    path if File.exists?(File.join(directory, path))
  end

  private

  def self.handle_dump(a, dump_state)
    file = dump_state[:file]
    if file
      file.puts a["text"]
      if a["text"].strip == "-- end of sql dump --"
        file.close
        dump_state[:file] = nil
        dump_state[:found_dump] = true
      end
    elsif a[:text].strip == "-- dump of data.sqlite --"
      dump_state[:file] = File.open(dump_state[:path], "w")
    end
  end
end
