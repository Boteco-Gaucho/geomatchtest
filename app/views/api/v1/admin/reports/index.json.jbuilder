json.stats do
  json.pending  @stats[:pending]
  json.resolved @stats[:resolved]
  json.banned   @stats[:banned]
end

json.by_category @by_category

json.pagination do
  json.current_page @pagination[:current_page]
  json.total_pages  @pagination[:total_pages]
  json.total_count  @pagination[:total_count]
end

json.reports @reports do |r|
  json.id          r.id
  json.description r.description
  json.category    r.category || 'other'
  json.resolved    r.resolved?
  json.resolved_at r.resolved_at&.iso8601
  json.created_at  r.created_at.iso8601
  if r.reporter
    json.reporter do
      json.id    r.reporter.id
      json.name  r.reporter.display_name
      json.email r.reporter.email
    end
  else
    json.reporter nil
  end
end
