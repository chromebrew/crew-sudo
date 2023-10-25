def send_event(sock, event, args = {})
  sock.puts({ event: event }.merge(args).to_json)
end

def message(message, loglevel: :verbose)
  return unless $log || $verbose || loglevel != :verbose

  warn "[#{$mode}]: #{message}"
end