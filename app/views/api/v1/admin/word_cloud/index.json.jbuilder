json.period_from    @result[:period_from]
json.period_to      @result[:period_to]
json.total_messages @result[:total_messages]

json.top_words @result[:top_words] do |item|
  json.word  item[:word]
  json.count item[:count]
end

json.blacklist_alerts @result[:blacklist_alerts] do |alert|
  json.word  alert[:word]
  json.count alert[:count]
end
