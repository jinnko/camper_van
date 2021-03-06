module CamperVan

  # The core EventMachine server instance that listens for IRC
  # connections and maps them to IRCD instances.
  module Server
    # Public: start the server
    #
    # bind_address - what address to bind to
    # port         - what port to listen on
    # log_options  - an optional hash of additional configuration
    #                options for the logger (see .initialize_logging)
    def self.run(bind_address="localhost", port=6667, log_options={})

      initialize_logging log_options

      EM.run do
        logger = Logging.logger[self.name]
        logger.info "starting server on #{bind_address}:#{port}"
        EM.start_server bind_address, port, self
        trap("INT") do
          logger.info "SIGINT, shutting down"
          EM.stop
        end
      end
    end

    # Initialize the logging system
    #
    # opts - Hash of logging options
    #        - :log_level (default :info)
    #        - :log_to - where to log to (default STDOUT), can be IO or
    #                    String for log filename
    def self.initialize_logging(opts={})
      Logging.consolidate("CamperVan")

      Logging.logger.root.level = opts[:log_level] || :info

      appender = case opts[:log_to]
      when String
        Logging.appenders.file(opts[:log_to])
      when IO
        Logging.appenders.io(opts[:log_to])
      when nil
        Logging.appenders.stdout
      end

      # YYYY-MM-DDTHH:MM:SS 12345 LEVEL LoggerName : The Log message
      appender.layout = Logging::Layouts::Pattern.new(:pattern => "%d %5p %5l %c : %m\n")

      Logging.logger.root.add_appenders appender
    end

    # Using a line-based protocol
    include EM::Protocols::LineText2

    include Logger

    # Public: returns the instance of the ircd for this connection
    attr_reader :ircd

    # Public callback once a server connection is established.
    #
    # Initializes an IRCD instance for this connection.
    def post_init(*args)
      logger.info "got connection from #{remote_ip}"

      # initialize the line-based protocol: IRC is \r\n
      @lt2_delimiter = "\r\n"

      # start up the IRCD for this connection
      @ircd = IRCD.new(self)
    end

    # Public: callback for when a line of the protocol has been
    # received. Delegates the received line to the ircd instance.
    #
    # line - the line received
    def receive_line(line)
      logger.debug "irc -> #{line.strip}"
      ircd.receive_line(line)
    end

    # Public: send a line to the connected client.
    #
    # line - the line to send, sans \r\n delimiter.
    def send_line(line)
      logger.debug "irc <- #{line}"
      send_data line + "\r\n"
    end

    # Public: callback when a client disconnects
    def unbind
      logger.info "closed connection from #{remote_ip}"
    end

    # Public: return the remote ip address of the connected client
    #
    # Returns an IP address string
    def remote_ip
      @remote_ip ||= get_peername[4,4].unpack("C4").map { |q| q.to_s }.join(".")
    end

  end

end
