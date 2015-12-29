import os
import sys
import optparse

################################### Output ###################################

counter = 0

def show_progress_start():
  global counter
  counter = 0

def show_progress():
  global counter
  counter += 1
  if counter % 1000 == 0:
    sys.stdout.write('.')
    sys.stdout.flush()

def show_progress_end():
  global counter
  print
  print "<" + str(counter) + ">"

##############################################################################

# http://rosettacode.org/wiki/Walk_a_directory/Recursively#Python
# also: http://rosettacode.org/wiki/Walk_a_directory/Non-recursively#Python
def rcrs(dr):
  for root, dirs, files in os.walk(dr):
    for filename in files:
      show_progress()

def none(dr):
  pass

flavors = {
  'default': rcrs,
  'none': none,
}

parser = optparse.OptionParser()
parser.set_defaults(flavor='default',times=1)
parser.add_option('--times', type='int')
parser.add_option('--flavor', type='string')
(options, args) = parser.parse_args()

if not options.flavor in flavors:
  raise Exception("no flavor " + options.flavor)

#print(options)

if len(args) == 1:
  for _ in xrange(1, options.times + 1):
    show_progress_start()
    flavors[options.flavor](args[0])
    show_progress_end()
