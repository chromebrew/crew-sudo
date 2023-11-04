def send_event(sock, event, args = {})
  sock.puts({ event: event }.merge(args).to_json)
end

def message(m, loglevel: :verbose)
  return unless $log || $verbose || loglevel != :verbose

  warn m.lines(chomp: true).map {|line| "[#{$mode}]: #{line}" }
end