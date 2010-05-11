module DataMapper
  class Property
    
    alias initialize_without_reference_class initialize

    def initialize_with_reference_class(model, name, type, options = {})
      @_reference_class = options.delete(:reference)
      
      initialize_without_reference_class(model, name, type, options)
    end

    alias initialize initialize_with_reference_class
        
    def reference_class
      return @_reference_class if @_reference_class.kind_of?(Class)
      
      # TODO: Revisit this when we move to ActiveSupport.
      @_reference_class = Extlib::Inflection.constantize(@_reference_class.to_s)
      
      return @_reference_class
    end

    def to_json_schema_hash(repo)
      tm = repository(repo).adapter.type_map
      json_hash = Hash.new
      json_hash = {      "type"      => tm[type][:primitive] }
      json_hash.merge!({ "optional"  => true })       unless required?
      json_hash.merge!({ "unique"    => true})        if     unique?
      json_hash.merge!({ "position"  => @position })  unless @position.nil?
      json_hash.merge!({ "prefix"    => @prefix })    unless @prefix.nil?
      json_hash.merge!({ "separator" => @separator }) unless @separator.nil?
      json_hash.merge!(  tm[type].reject{ |key,value| key == :primitive } )

      json_hash
    end
    
  end
end