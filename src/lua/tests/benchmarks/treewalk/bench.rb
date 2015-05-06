#!/usr/bin/ruby

require 'optparse'

################################### Output ###################################

@@counter = 0

def show_progress_start()
  @@counter = 0
end

def show_progress(full)
  @@counter += 1
  if @@counter % 1000 == 0 then
    $stdout.write('.'); $stdout.flush()
  end
end

def show_progress_end()
  puts()
  puts('<' + @@counter.to_s + ' files>')
end

##############################################################################

def rcrs(dir)
  Dir.new(dir).each { |file|
    next if (file == '.' || file == '..')
    full = dir + '/' + file
    show_progress(full)
    if File.directory?(full) and !File.symlink?(full) then
      rcrs(full)
    end
  }
end

flavors = {
  'default' => :rcrs
}

args = {
  :flavor => 'default',
  :times => 1,
}

OptionParser.new do |opts|
  opts.on('-f', '--flavor TYPE', 'Flavor') do |flavor|
    raise "Unknown flavor #{flavor}" if !flavors[flavor]
    args[:flavor] = flavor
  end
  opts.on('-t', '--times n', Integer, 'How many times to run the test') do |n|
    args[:times] = n
  end
end.parse!

if ARGV[0] then
  1.upto(args[:times]) {
    show_progress_start()
    self.send(flavors[args[:flavor]], ARGV[0])
    show_progress_end()
  }
end
