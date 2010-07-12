module DataMapper
  module Persevere
    module JSONSupport
      module Core
        def to_json(id = nil)
          to_json_hash(id).to_json
        end
    
        def to_json_hash(id = nil)
          return {
            'id' => id || self.to_s
          }
        end
      end # Core
    end # JSONSupport
  end # Persevere
end # DataMapper