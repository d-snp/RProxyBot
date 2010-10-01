module RProxyBot
	class ProxyBot
    include Singleton
    attr_accessor :allow_user_control,
      :complete_information,
      :display_agent_commands,
      :display_terrain_analysis

		attr_accessor :player_id, :map, :player, :players, :unit_types,
			:starting_locations, :units, :tech_types,
			:upgrade_types, :command_queue, :max_commands_per_message, :frame,
      :stopping

		def run(port, *settings)
      @allow_user_control,
      @complete_information,
      @display_agent_commands,
      @display_terrain_analysis,
      @max_commands_per_message = settings

			run_server port
			puts "Done running server!"
		end

		def run_server(port)
			server = TCPServer.new(port)

			#We wait for a client to connect to us.
			puts "Waiting for client"
			socket = server.accept
			puts "Client accepted."

			#The first thing it sends us is the player information:
			ack, data = socket.gets.split(';', 2)
      puts "bot says: #{ack}"
      player_id, data = data.split(':', 2)
      self.player_id = player_id.to_i

			puts "player id is: #{player_id}"

			parse_players(data)

			#We reply that with our cheat flags
			socket.puts(@allow_user_control +
                  @complete_information +
                  @display_agent_commands +
                  @display_terrain_analysis)

			#It continues with sending us data.
			parse_locations(socket.gets)
			parse_map(socket.gets)
      parse_chokes(socket.gets)
      parse_base_locations(socket.gets)
			#parse_tech_types(socket.gets)
			#parse_upgrade_types(socket.gets)
			#parse_unit_types(socket.gets)

      #TODO this is ugly, we're storing max_commands in two places, should only be CommandQueue
      @command_queue = CommandQueue.instance
      @command_queue.max_commands = @max_commands_per_message
      @frame = 0

      @stopping = false
      while(not @stopping)
        if parse_update(socket.gets)
          #hier moeten we een thread maken die daarna
          #coole dingen doet met de gamestate.
          #Zoals een REPL:
          if @frame == 0
            Thread.new do
              puts "Welcome in the interactive AI:"
              while (not @stopping)
                '> '.display
                e = gets
                begin
                  puts(eval(e,binding))
                rescue => e
                  puts "Oops error: #{e.message} \n #{e.backtrace.join('\n')}"
                end
              end
            end
            BasicAI.start
          end
          @frame += 1

          socket.puts @command_queue.fetch
        else
          stopping = true
        end
      end

      #we moeten ook de bot stoppen hier.

      #clean up after ourselves
      socket.close
      server.close
    end

    def parse_update(data)
      if data.nil?
        false
      else
        player_data, units_data = data.split(':', 2)
        #update player
        @player.update(player_data)
        #update units
        @units ||= Units.new
        @units.update(units_data)
        @players.each do |p|
          p.update_units(@units[p.id]) unless @units[p.id].nil?
        end
        true
      end
    end

    def parse_players(data)
			@players = Player.parse(data)
      @player = @players[@player_id]
		end

		def parse_unit_types(data)
			@unit_types = UnitType.parse(data)
		end

		def parse_locations(data)
			@starting_locations = StartingLocation.parse(data)
		end

		def parse_map(data)
			@map = Map.parse(data)
		end

		def parse_tech_types(data)
			@tech_types = TechType.parse(data)
		end

		def parse_upgrade_types(data)
			@upgrade_types = UpgradeType.parse(data)
		end

    def parse_chokes(data)
      @map.chokes = Choke.parse(data)
    end

    def parse_base_locations(data)
      @map.base_locations = BaseLocation.parse(data)
    end
	end
end

p = RProxyBot::ProxyBot.instance
p.run(12345,"1","1","1","1", 20)
