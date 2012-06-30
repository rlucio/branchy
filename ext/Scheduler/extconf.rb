# loads mkmf which is used to make makefiles for Ruby extensions
require 'mkmf'

# give it a name
extension_name = 'Scheduler'

# the destination
dir_config(extension_name)

# do the work
create_makefile(extension_name)

