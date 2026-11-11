json.pagination do
  json.current_page @users.current_page
  json.total_pages  @users.total_pages
  json.total_count  @users.total_count
  json.per_page     @users.limit_value
end

json.users @users do |user|
  json.id           user.id
  json.name         user.display_name
  json.email        user.email
  json.plan_id      user.plan_id
  json.plan         user.plan&.name
  json.plan_is_admin_grant user.latest_approved_payment&.admin_grant? || false
  json.city         user.city
  json.state        user.state
  json.zip_code     user.zip_code
  json.education_level  user.education_level
  json.education_label  case user.education_level
                        when 'high_school'        then 'Ensino Médio'
                        when 'college_incomplete' then 'Superior Incompleto'
                        when 'college_complete'   then 'Superior Completo'
                        else '—'
                        end
  json.admin        user.admin?
  json.verified     user&.verified?
  json.banned       user.banned?
  json.banned_at    user.banned_at&.iso8601
  json.created_at   user.created_at.iso8601
  json.last_seen_at user.last_seen_at&.iso8601
  json.status       user.banned? ? 'banned' : 'active'
end
