require 'rubygems'
require 'dm-core'
require 'dm-aggregates'
require 'dm-types'
require 'dm-migrations'
require 'dm-migrations/auto_migration'
require 'dm-validations'
require 'extlib'
require 'bigdecimal'
require 'digest/md5'


# Require Persevere http client
require 'persevere_client'


# Require in Adapter modules
require 'persevere_adapter/query'
# require 'persevere_adapter/associations/many_to_many.rb'
# require 'persevere_adapter/associations/relationship.rb'
require 'persevere_adapter/resource'

require 'persevere_adapter/support/big_decimal'

require 'persevere_adapter/json_support'
require 'persevere_adapter/enhance'

require 'persevere_adapter/adapter'
require 'persevere_adapter/migrations'
require 'persevere_adapter/aggregates'

