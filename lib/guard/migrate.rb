require 'guard'
require 'guard/guard'
require 'fileutils'

module Guard
  class Migrate < Guard
    attr_reader :seed, :rails_env

    def initialize(watchers=[], options={})
      super
      
      @reset = true if options[:reset] == true
      @test_clone = true unless options[:test_clone] == false
      @run_on_start = true if options[:run_on_start] == true
      @rails_env = options[:rails_env]
      @seed = options[:seed]
			
			@engine_dummy_path = options[:engine_dummy_path]
			
			unless @engine_dummy_path.nil?
				UI.info "engine dummy application path: #{@engine_dummy_path}"
				
				@engine_name = File.basename(Dir.pwd)
				UI.info "engine name: #{@engine_name}"
			end
    end

    def bundler?
      @bundler ||= File.exist?("#{Dir.pwd}/Gemfile")
    end

    def run_on_start?
      !!@run_on_start
    end

    def test_clone?
      !!@test_clone
    end

    def reset?
      !!@reset
    end

    # =================
    # = Guard methods =
    # =================

    # If one of those methods raise an exception, the Guard::GuardName instance
    # will be removed from the active guards.

    # Called once when Guard starts
    # Please override initialize method to init stuff
    def start
      self.migrate if self.run_on_start?
    end

    # Called on Ctrl-C signal (when Guard quits)
    def stop
      true
    end

    # Called on Ctrl-Z signal
    # This method should be mainly used for "reload" (really!) actions like reloading passenger/spork/bundler/...
    def reload
      self.migrate if self.run_on_start?
    end

    # Called on Ctrl-/ signal
    # This method should be principally used for long action like running all specs/tests/...
    def run_all
      self.migrate if self.run_on_start?
    end

    # Called on file(s) modifications
    def run_on_changes(paths)
      self.migrate(paths.map{|path| path.scan(%r{^db/migrate/(\d+).+\.rb}).flatten.first})
    end

    def migrate(paths = [])
      return if !self.reset? && paths.empty?

			if self.reset?
				migrate_reset
			end

			# unless @engine_dummy_path.nil?
			# 	system "rm db/migrate/*.#{@engine_name}.rb", {:chdir => @engine_dummy_path}
			# end
			# 
			# exec_rake if self.reset?
			
      paths.each do |path|
        UI.info "Running #{self.rake_string(path)}"
				exec_rake(path)
      end
    end

		def migrate_reset
			unless @engine_dummy_path.nil?
				UI.info "rm db/migrate/*.#{@engine_name}.rb"
				FileUtils.rm Dir.glob("#{@engine_dummy_path}/db/migrate/*.#{@engine_name}.rb")
				
				if @seed
					FileUtils.cp "db/seeds.rb", "#{@engine_dummy_path}/db"
					FileUtils.cp_r "db/default", "#{@engine_dummy_path}/db"
				end
			end
			
			exec_rake
		end

		def exec_rake(path = nil)
			if @engine_dummy_path.nil?
				UI.info "Dir.pwd: #{Dir.pwd} 2"
				system self.rake_string(path)
			else
				system "rm #{path}", {:chdir => @engine_dummy_path}
				system self.rake_string(path), {:chdir => @engine_dummy_path}
			end
		end

    def rake_string(path = nil)
			@rake_string = ''
      @rake_string += 'bundle exec ' if self.bundler?
      @rake_string += 'rake'
			@rake_string += " #{@engine_name}:install:migrations" unless @engine_dummy_path.nil?
      @rake_string += ' db:migrate'
      @rake_string += ':reset' if self.reset?
      @rake_string += ":redo VERSION=#{path}" if !self.reset? && path && !path.empty?
      @rake_string += ' db:test:clone' if self.test_clone?
      @rake_string += " RAILS_ENV=#{self.rails_env}" if self.rails_env
      @rake_string += " db:seed" if @seed
      @rake_string
    end
  end
end

