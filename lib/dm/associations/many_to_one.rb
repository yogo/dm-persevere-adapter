module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        def child_key
          super
        end
      end
    end
  end
end