# frozen_string_literal: true

require "json"
require "shellwords"
require "pathname"

require "sshfsmount/version"

module Sshfsmount
  #
  # Basic SSHFS flags
  #
  SSHFS_FLAGS = [
    "-o local",
    "-o workaround=nonodelaysrv",
    "-o transform_symlinks",
    "-o idmap=user",
    "-C",
  ].freeze

  module_function

  def verbose
    @verbose
  end

  def verbose=(val)
    @verbose = val ? true : false
  end

  def sshfs_cmd
    sshfs_cmd = `command -v sshfs`.strip
    raise "sshfs command not found in path" if sshfs_cmd.empty?
    sshfs_cmd
  end

  #
  # Locate config file.
  #
  def find_config_file
    @config_file ||= begin
      [
        Pathname.new(File.join(Dir.home, ".sshfsmount.json")),
        Pathname.new(File.join(Dir.home, ".config", "sshfsmount.json")),
        Pathname.new(File.join(Dir.home, ".config", "sshfsmount", "sshfsmount.json")),
      ].select(&:file?).first
    end
  end

  #
  # Parse config file
  #
  def config
    @config ||= begin
      config_file = find_config_file
      if config_file.nil?
        STDERR.puts "No config file found"
        {}
      else
        JSON.parse(config_file.read, symbolize_names: true)
      end
    rescue JSON::ParserError => e
      STDERR.puts "Parse error in config file `#{config_file}`: #{e}"
      {}
    end
  end

  def active_mounts
    @active_mounts ||= begin
      `mount`.lines.each_with_object({}) do |line, mounts|
        regex = %r{^(?<remote>.+@[^:]+\:/.*?) on (?<local>/.*?) (?<options>\(\b(?:fuse|osxfuse)\b.*?\))$}
        info = line.match(regex)
        next if info.nil?
        pid = `pgrep -f "/sshfs #{Shellwords.escape(info[:remote])} #{Shellwords.escape(info[:local])} "`.strip
        pid = "None found" if pid.empty?
        mounts[Pathname.new(info[:local]).expand_path] = {
          local: info[:local],
          remote: info[:remote],
          options: info[:options],
          pid: pid,
          str: "#{info[:remote]} on #{info[:local]} (PID: #{pid})",
        }
      end
    end
  end

  # Fails if the mount-path is already in use.
  def dupe_check!(mount_name, params)
    local = Pathname.new(params[:local]).expand_path
    dupe = active_mounts[local]
    return if dupe.nil?
    raise "\"#{mount_name}\" already mounted?\n* #{dupe[:str]}"
  end

  #
  # Create Mount-point Directory
  #
  def mkmountpoint(name)
    local = Pathname.new(name).expand_path
    if !local.exist?
      STDERR.puts "Creating mount-point directory #{local}"
      local.mkpath
    elsif !local.directory
      raise "Mount point #{local} exists and is not a directory"
    elsif !local.empty?
      raise "Mount point #{local} already exists and is not empty"
    elsif @verbose
      STDERR.puts "Mount-point directory #{local} already exists and is empty"
    end
    local
  end

  #
  # Delete mount-point directory
  #
  def rmmountpoint(name)
    local = Pathname.new(name).expand_path
    if !local.exist?
      STDERR.puts "Mount-point directory not found" if @verbose
    elsif !local.directory?
      raise "Mount point #{local} is not a directory"
    elsif !local.empty?
      raise "Mount-point directory #{local} is not empty"
    else
      STDERR.puts "Deleting mount-point directory #{local}"
      local.rmdir
      return true
    end
  end

  #
  # Mount an SSHFS volume
  #
  def mount(mount_name, params)
    dupe_check!(mount_name, params)
    local = mkmountpoint(params[:local])
    volname = params[:volname] || mount_name
    cmd = "#{sshfs_cmd} " \
          "#{Shellwords.escape(params[:remote])} " \
          "#{Shellwords.escape(local)} " \
          "-o volname=\"#{Shellwords.escape(volname)}\" " \
          "#{SSHFS_FLAGS.join(' ')} " \
          "-p #{(params[:port] || 22).to_i}"
    puts "Mounting \"#{mount_name}\"\n" \
      " * #{params[:remote]} on #{local} as \"#{volname}\""
    STDERR.puts "> #{cmd}" if @verbose
    system(cmd)
  end

  #
  # Unmount an SSHFS volume
  #
  def unmount(mount_name, params)
    local = Pathname.new(params[:local]).expand_path
    info = active_mounts[local]
    raise "No active mount-point found for #{local}" if info.nil?
    STDERR.puts "No active SSHFS process found for #{local}" if info[:pid] == "None found"
    cmd = "umount #{Shellwords.escape(local)}"
    puts "Unmounting \"#{mount_name}\" (#{local})"
    STDERR.puts "> #{cmd}" if @verbose
    raise "Unmount error, skipping removal of mount-point." unless system(cmd)
    rmmountpoint(local)
  end
end
