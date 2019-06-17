#!/usr/bin/env ruby

File.open(File.join(File.dirname($0), '..', '.typescript_last_output.txt'), 'w') do |fh|
  loop do
    line = $stdin.gets

    if line && line.start_with?("\x1bc")
      # Clear screen.  New build
      line = line[2..-1]
      fh.rewind
      fh.truncate(0)
    end

    fh.puts line
    fh.flush
    puts line
    STDOUT.flush
  end
end
