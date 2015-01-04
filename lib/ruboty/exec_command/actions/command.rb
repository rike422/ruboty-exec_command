module Ruboty
  module ExecCommand
    module Actions
      class Command < Ruboty::Actions::Base
        def call
          # TODO: add timeout
          c = Ruboty::ExecCommand::Command.new(command_args: command_body)
          run_and_monitor(c)
        end

        def command_slot
          message.robot.brain.data[:command_slot] ||= Ruboty::ExecCommand::CommandSlot.new
        end

        def list_commands
          message.reply(command_slot.list_commands)
        end

        def kill_command
          # TODO: command list lock
          # kill running process, command is "kill command <index>"
          killed = command_slot.kill(message.body.split.last.to_i)

          if killed.nil?
            message.reply("Command [#{message.body.split.last}] not found.")
          end
        end

        def run_and_monitor(comm)
          pid = command_slot.run(comm)
          message.reply("[#{comm.command_name}] invoked.")

          # Waiter thread
          thread = Thread.new do
            ignore_pid, status = Process.wait2(pid)
            command_slot.forget(pid)

            if status.exitstatus == 0
              message.reply("[#{comm.command_name}] completed successfully.")
              message.reply(comm.stdout_log.chomp)
            elsif status.signaled?
              message.reply("[#{comm.command_name}] killed by signal #{status.termsig}")
            else
              message.reply("[#{comm.command_name}] exit status with #{status}\n" +
                          comm.stdout_log +
                          "stderr: " + comm.stderr_log.chomp
                        )
            end
          end

          if ENV['RUBOTY_ENV'] == 'blocked_test'
            thread.join
          end
        end

        def robot_prefix_pattern
          Ruboty::Action.prefix_pattern(message.original[:robot].name)
        end

        def command_body
          message.body.sub(robot_prefix_pattern,'')
        end
      end
    end
  end
end
