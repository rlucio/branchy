# loads mkmf which is used to make makefiles for Ruby extensions
require 'mkmf'

$CFLAGS << " -std=c99"

create_makefile('branchy/branchy')

