# frozen_string_literal: true

module Gtn
  # Module for obtaining modification times of files.
  # It walks the git history to record the last time a file was modified.
  # This is faster than talking to the file system.
  module ModificationTimes
    @@TIME_CACHE = nil
    @@COMMIT_COUNT_CACHE = nil

    def self.init_cache
      return unless @@TIME_CACHE.nil?

      @@TIME_CACHE = {}
      @@COMMIT_COUNT_CACHE = Hash.new(0)
      Jekyll.logger.info '[GTN/Time/Mod] Filling Time Cache'
      self.cached_command
        .split('GTN_GTN:')
        .map { |x| x.split("\n\n") }
        .select { |x| x.length > 1 }
        .each do |date, files|
        files.split(/\n/).each do |f|
          @@TIME_CACHE[f] = Time.at(date.to_i) if !@@TIME_CACHE.key? f
          @@COMMIT_COUNT_CACHE[f] += 1
        end
      end
    end

    def self.discover_caches
      # Really there should only be one, but maybe someone's been silly so
      # we'll just take the first one we find.
      Dir.glob('metadata/git-mod-*.txt').first
    end

    def self.generate_cache
      rev = `git rev-list -n 1 main`.strip

      if discover_caches.nil?
        File.write("metadata/git-mod-#{rev}.txt", self.command)
      else
        prev = discover_caches
        File.write("metadata/git-mod-#{rev}.txt", self.cached_command)
        File.delete(prev)
      end
    end

    def self.cached_command
      if discover_caches.nil?
        return self.command
      end

      Jekyll.logger.info '[GTN/Time/Mod] Using cached modification times'

      previous_commit = discover_caches.split('-').last.split('.').first
      previous = File.read(discover_caches)

      `git log --name-only --pretty='GTN_GTN:%ct' #{previous_commit}..` + previous
    end

    def self.command
      `git log --name-only --pretty='GTN_GTN:%ct'`
    end

    def self.time_cache
      @@TIME_CACHE
    end

    def self.commit_count_cache
      @@COMMIT_COUNT_CACHE
    end

    def self.obtain_modification_count(f)
      init_cache
      if @@COMMIT_COUNT_CACHE.key? f
        @@COMMIT_COUNT_CACHE[f]
      else
        0
      end
    end

    def self.obtain_time(f)
      init_cache
      if @@TIME_CACHE.key? f
        @@TIME_CACHE[f]
      else
        begin
          # Non git file.
          @@TIME_CACHE[f] = File.mtime(f)
          Jekyll.logger.warning "[GTN/Time/Mod] No git cached time available for #{f}, defaulting to checkout"
          @@TIME_CACHE[f]
        rescue StandardError
          Time.at(0)
        end
      end
    end
  end

  # Module for obtaining original publication times of files.
  # It walks the git history to record the last time a file was modified.
  # This is faster than talking to the file system.
  module PublicationTimes
    @@TIME_CACHE = nil

    def self.chase_rename(renames, path)
      if renames.key? path
        chase_rename(renames, renames[path])
      else
        path
      end
    end

    def self.init_cache
      return unless @@TIME_CACHE.nil?

      @@TIME_CACHE = {}
      renames = {}

      Jekyll.logger.info '[GTN/Time/Pub] Filling Publication Time Cache'
      self.cached_command
        .split('GTN_GTN:')
        .map { |x| x.split("\n\n") }
        .select { |x| x.length > 1 }
        .each do |date, files|
        files.split("\n").grep(/\.(md|html)$/).each do |f|
          modification_type, path = f.split("\t")
          if modification_type == 'A'
            # Chase the renames.
            final_filename = chase_rename(renames, path)
            @@TIME_CACHE[final_filename] = Time.at(date.to_i)
          elsif modification_type[0] == 'R'
            _, moved_from, moved_to = f.split("\t")
            renames[moved_from] = moved_to # Point from the 'older' version to the newer.
          end
        end
      end
      # pp renames
    end

    def self.discover_caches
      # Really there should only be one, but maybe someone's been silly so
      # we'll just take the first one we find.
      Dir.glob('metadata/git-pub-*.txt').first
    end

    def self.generate_cache
      rev = `git rev-list -n 1 main`.strip

      if discover_caches.nil?
        File.write("metadata/git-pub-#{rev}.txt", self.command)
      else
        prev = discover_caches
        File.write("metadata/git-pub-#{rev}.txt", self.cached_command)
        File.delete(prev)
      end
    end

    def self.cached_command
      if discover_caches.nil?
        return self.command
      end

      Jekyll.logger.info '[GTN/Time/Pub] Using cached publication times'

      previous_commit = discover_caches.split('-').last.split('.').first
      previous = File.read(discover_caches)

      `git log --first-parent --name-status --diff-filter=AR --pretty='GTN_GTN:%ct' #{previous_commit}..` + previous
    end

    def self.command
      `git log --first-parent --name-status --diff-filter=AR --pretty='GTN_GTN:%ct' `
    end

    def self.time_cache
      @@TIME_CACHE
    end

    def self.obtain_time(f)
      init_cache
      if @@TIME_CACHE.key? f
        @@TIME_CACHE[f]
      else
        begin
          # Non git file.
          @@TIME_CACHE[f] = File.mtime(f)
          Jekyll.logger.warning "[GTN/Time/Pub] No git cached time available for #{f}, defaulting to checkout"
          @@TIME_CACHE[f]
        rescue StandardError
          Time.at(0)
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # Gtn::ModificationTimes.init_cache
  # pp Gtn::ModificationTimes.commit_count_cache

  puts ' Moved to bin/list-recently-modified.rb'
  # Gtn::PublicationTimes.init_cache
  # Gtn::PublicationTimes.time_cache.select do |_, v|
  #   # Things in last 6 months
  #   v > Time.now - (6 * 30 * 24 * 60 * 60)
  # end.map { |k, v| puts "#{v} #{k}" }
end
