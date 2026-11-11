json.total_users_with_location @total
json.cluster_count             @clusters.size

json.radius_filter do
  if @radius_applied
    json.center_lat @radius_applied[0]
    json.center_lng @radius_applied[1]
    json.radius_km  @radius_applied[2]
  else
    json.null!
  end
end

# max_count usado pelo frontend para normalizar a intensidade do heatmap
max = @clusters.map { |c| c[:count] }.max || 1
json.max_count max

json.clusters @clusters do |c|
  json.lat       c[:lat]
  json.lng       c[:lng]
  json.count     c[:count]
  json.intensity (c[:count].to_f / max).round(4)
end
