json.generated_at Time.current.iso8601
json.period_days  @days.to_i

# ── KPIs Globais ─────────────────────────────────────
kpis = @kpis || {}
json.kpis do
  json.total_users    kpis[:total_users].to_i
  json.active_users   kpis[:active_users].to_i
  json.match_rate     kpis[:match_rate].to_f
  json.total_likes    kpis[:total_likes].to_i
  json.total_matches  kpis[:total_matches].to_i
  json.total_messages kpis[:total_messages].to_i
end

# ── Por Gênero ───────────────────────────────────────
json.by_gender (@by_gender || []) do |g|
  json.gender        g[:gender]
  json.active_users  g[:active_users].to_i
  json.share_pct     g[:share_pct].to_f
  json.messages_sent g[:messages_sent].to_i
  json.likes_given   g[:likes_given].to_i
end

# ── Swipes ───────────────────────────────────────────
json.swipe_stats (@swipe_stats || []) do |s|
  json.gender         s[:gender]
  json.likes_given    s[:likes_given].to_i
  json.likes_received s[:likes_received].to_i
  json.matches        s[:matches].to_i
  json.match_rate     s[:match_rate].to_f
end

# ── Velocidade de Resposta ────────────────────────────
json.response_time (@response_time || []) do |r|
  json.gender          r[:gender]
  json.response_count  r[:response_count].to_i
  json.avg_minutes     r[:avg_minutes].to_f
  json.avg_formatted   r[:avg_formatted].to_s
end

# ── Uso por Turno ─────────────────────────────────────
json.by_shift (@by_shift || []) do |s|
  json.shift        s[:shift].to_s
  json.messages     s[:messages].to_i
  json.active_users s[:active_users].to_i
end

# ── Rankings ─────────────────────────────────────────
rankings = @top_rankings || {}
json.top_rankings do
  json.top_engaged (rankings[:top_engaged] || []) do |u|
    json.id       u[:id]
    json.username u[:username].to_s
    json.gender   u[:gender].to_s
    json.plan     u[:plan].to_s
    json.score    u[:score].to_f
    json.extra    (u[:extra] || {})
  end

  json.top_liked (rankings[:top_liked] || []) do |u|
    json.id       u[:id]
    json.username u[:username].to_s
    json.gender   u[:gender].to_s
    json.plan     u[:plan].to_s
    json.score    u[:score].to_f
  end

  json.top_liking (rankings[:top_liking] || []) do |u|
    json.id       u[:id]
    json.username u[:username].to_s
    json.gender   u[:gender].to_s
    json.plan     u[:plan].to_s
    json.score    u[:score].to_f
  end

  # avg_minutes está em u[:score]; response_count está no extra com chave string
  json.top_responders (rankings[:top_responders] || []) do |u|
    json.id             u[:id]
    json.username       u[:username].to_s
    json.gender         u[:gender].to_s
    json.plan           u[:plan].to_s
    json.avg_minutes    u[:score].to_f
    json.response_count u[:extra]&.[]('response_count').to_i
  end
end
