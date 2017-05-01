require 'mkmf'

extension_name = 'testenv'
dir_config(extension_name)

have_library('xml2', 'xmlParseFile')
create_makefile(extension_name)
