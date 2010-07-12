#
#  Override BigDecimal to_json because it's ugly and doesn't work for us
# 
class BigDecimal
  alias to_json_old to_json
  
  def to_json
    to_s
  end
end