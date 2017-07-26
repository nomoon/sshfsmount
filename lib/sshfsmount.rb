# frozen_string_literal: true

require "json"
require "shellwords"
require "fileutils"

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

  #
  # Locate config file.
  #
  def find_config_file
    [
      File.join(Dir.home, ".sshfsmount.json"),
      File.join(Dir.home, ".config", "sshfsmount.json"),
      File.join(Dir.home, ".config", "sshfsmount", "sshfsmount.json"),
    ].select { |f| File.exist?(f) }.first
  end

  #
  # Parse config file
  #
  def config
    config_file = find_config_file
    if config_file.nil?
      STDERR.puts "No config file found"
      {}
    else
      JSON.parse(File.read(config_file), symbolize_names: true)
    end
  rescue JSON::ParserError => e
    STDERR.puts "Parse error in config file `#{config_file}`: #{e}"
    {}
  end

  #
  # Create Mount-point Directory
  #
  def mkmountpoint(name)
    local = File.expand_path(name)
    if !Dir.exist?(local)
      STDERR.puts "Creating mount-point directory #{local}"
      FileUtils.mkdir_p(local)
    elsif !Dir.empty?(local)
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
    local = File.expand_path(name)
    if !Dir.exist?(local)
      STDERR.puts "Mount-point directory not found" if @verbose
    elsif !Dir.empty?(local)
      raise "Mount-point directory #{local} is not empty"
    else
      STDERR.puts "Deleting mount-point directory #{local}"
      FileUtils.rmdir(local)
    end
    local
  end

  #
  # Mount an SSHFS volume
  #
  def mount(mount_name, params)
    local = mkmountpoint(params[:local])
    volname = params[:volname] || mount_name
    p_remote = Shellwords.escape(params[:remote])
    p_local = Shellwords.escape(local)
    p_volname = Shellwords.escape(volname)
    port = (params[:port] || 22).to_i
    cmd = "/usr/local/bin/sshfs #{p_remote} #{p_local} " \
          "-o volname=\"#{p_volname}\" #{SSHFS_FLAGS.join(' ')} -p #{port}"
    pgrep = `pgrep -f \"#{cmd}\"`
    unless pgrep.empty?
      raise "SSHFS process for #{mount_name} running already (PID: #{pgrep.strip}, " \
            "Mount-point: #{p_local})"
    end
    puts "Mounting #{params[:remote]} to #{params[:local]} as \"#{volname}\""
    STDERR.puts "> #{cmd}" if @verbose
    system(cmd)
  end

  #
  # Unmount an SSHFS volume
  #
  def unmount(mount_name, params)
    local = File.expand_path(params[:local])
    p_local = Shellwords.escape(local)
    cmd = "diskutil unmount #{p_local}"
    pgrep = `pgrep -f \"#{p_local}\"`
    if pgrep.empty?
      raise "No SSHFS process found with the mount-point for #{mount_name} (#{p_local})"
    end
    puts "Unmounting #{local}"
    STDERR.puts "> #{cmd}" if @verbose
    system(cmd)
    rmmountpoint(local)
  end
end
