# frozen_string_literal: true

require "gli"
require "json"
require "shellwords"
require "fileutils"

module Sshfsmount
  module CLI
    extend GLI::App
    #
    # GLI command-line app definition
    #
    program_desc "A simple front-end CLI to SSHFS"
    version Sshfsmount::VERSION

    switch %i[u unmount], desc: "Unmount the volume", negatable: false
    switch %i[v verbose], desc: "Show verbose output", negatable: false

    desc "List active SSHFS processes"
    command :active do |c|
      c.action do
        system("pgrep -fl sshfs")
      end
    end

    config = Sshfsmount.config

    #
    # Define commands from data-file
    #
    extant_commands = commands.keys
    config.reject { |name, _| extant_commands.include?(name) }.each do |mount_name, params|
      desc "mount #{params[:remote]} to #{params[:local]}"
      command mount_name do |c|
        c.switch %i[u unmount], desc: "Unmount the volume", negatable: false
        c.switch %i[v verbose], desc: "Show verbose output", negatable: false
        c.action do |global_options, cmd_options|
          @verbose = global_options[:v] || cmd_options[:v]
          if global_options[:u] || cmd_options[:u]
            Sshfsmount.unmount(mount_name, params)
          else
            Sshfsmount.mount(mount_name, params)
          end
        end
      end
    end
  end
end
