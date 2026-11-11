class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USERNAME", "suporte@geomatchbr.com")
  layout "mailer"
end
