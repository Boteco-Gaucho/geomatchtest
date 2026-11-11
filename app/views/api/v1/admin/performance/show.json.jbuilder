json.generated_at Time.current.iso8601

json.database do
  json.status     @db_latency ? 'ok' : 'error'
  json.latency_ms @db_latency
  json.pool do
    json.size    @pool_stat[:size]
    json.busy    @pool_stat[:busy]
    json.idle    @pool_stat[:idle]
    json.waiting @pool_stat[:waiting]
  end
  json.cache_adapter @cache_stat[:adapter]
end

json.revenue do
  json.total_brl       @revenue[:total_brl]
  json.mrr_brl         @revenue[:mrr_brl]
  json.paid_payments   @revenue[:paid_payments]
  json.premium_users   @revenue[:premium_users]
  json.free_users      @revenue[:free_users]
  json.total_users     @revenue[:total_users]
  json.conversion_rate @revenue[:conversion_rate]
end
