PagedResults = Struct.new(:results, :current_page, :max_page) do
  def to_json(*args)
    to_h.to_json
  end
end
