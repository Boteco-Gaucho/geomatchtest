json.generated_at    Time.current.iso8601
json.period_days     @days.to_i
json.topic_filter    @topic_filter.to_s
json.lgpd_threshold  Api::V1::Admin::PoliticalIntelligenceController::LGPD_MIN_USERS
json.terms_monitored (@terms || [])

# ── Headline Insights ──────────────────────────────────────────────────────
json.headline_insights (@headline_insights || []) do |i|
  json.topic            i[:topic].to_s
  json.trend_pct        i[:trend_pct].to_i
  json.current_mentions i[:current_mentions].to_i
  json.unique_users     i[:unique_users].to_i
  json.sentiment_label  i[:sentiment_label].to_s
  json.description      i[:description].to_s
end

# ── Sentimento Geral ───────────────────────────────────────────────────────
sent = @sentiment_overall || {}
json.sentiment_overall do
  json.positive sent[:positive].to_f
  json.negative sent[:negative].to_f
  json.neutral  sent[:neutral].to_f
  json.total    sent[:total].to_i
end

# ── Por Tópico ─────────────────────────────────────────────────────────────
json.by_topic (@by_topic || []) do |t|
  json.topic        t[:topic].to_s
  json.mentions     t[:mentions].to_i
  json.unique_users t[:unique_users].to_i
  json.trend_pct    t[:trend_pct]
  json.sentiment do
    s = t[:sentiment] || {}
    json.positive s[:positive].to_f
    json.negative s[:negative].to_f
    json.neutral  s[:neutral].to_f
    json.total    s[:total].to_i
  end
end

# ── Menções a Candidatos/Termos ────────────────────────────────────────────
json.candidate_mentions (@candidate_mentions || []) do |c|
  json.term         c[:term].to_s
  json.mentions     c[:mentions].to_i
  json.unique_users c[:unique_users].to_i
  json.trend_pct    c[:trend_pct]
  json.sentiment do
    s = c[:sentiment] || {}
    json.positive s[:positive].to_f
    json.negative s[:negative].to_f
    json.neutral  s[:neutral].to_f
    json.total    s[:total].to_i
  end
  json.by_region (c[:by_region] || []) do |r|
    json.region   r[:region].to_s
    json.mentions r[:mentions].to_i
    json.users    r[:users].to_i
  end
end

# ── Mapa de Calor Temático ─────────────────────────────────────────────────
json.thematic_heatmap (@thematic_heatmap || []) do |h|
  json.lat       h[:lat].to_f
  json.lng       h[:lng].to_f
  json.intensity h[:intensity].to_i
end
