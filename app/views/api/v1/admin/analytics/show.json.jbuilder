json.period do
  json.from @from.to_s
  json.to   @to.to_s
end

# ── Crescimento diário ──────────────────────────────────────────
json.growth do
  json.daily @growth.map { |date, count| { date: date.to_s, count: count } }
  json.total_period @growth.values.sum
  json.daily_average @growth.any? ? (@growth.values.sum.to_f / @growth.size).round(1) : 0
end

# ── Retenção ────────────────────────────────────────────────────
json.retention do
  %i[d1 d7 d30].each do |key|
    data = @retention[key]
    json.set! key do
      json.rate     data[:rate]
      json.base     data[:base]
      json.returned data[:returned]
      json.label    key.to_s.upcase
    end
  end
end

# ── Engajamento ─────────────────────────────────────────────────
json.engagement do
  json.matches                @engagement[:matches]
  json.messages               @engagement[:messages]
  json.avg_messages_per_match @engagement[:avg_messages_per_match]
end

# ── Demografia ──────────────────────────────────────────────────
json.demographics do
  json.by_plan   @demographics[:by_plan]
  json.by_gender @demographics[:by_gender]
end

# ── Alertas de Bot ──────────────────────────────────────────────
json.bot_alerts @bot_alerts do |alert|
  json.user_id      alert[:user_id]
  json.email        alert[:email]
  json.name         alert[:name]
  json.like_count_1h alert[:like_count_1h]
end
