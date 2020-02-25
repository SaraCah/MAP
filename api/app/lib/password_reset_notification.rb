require 'mail'

class PasswordResetNotification

  def initialize(token, user)
    @reset_link = URI.join(AppConfig[:service_url], '/new-password')
    @reset_link.query = "token=#{token}"

    @user = user

  end

  def send!
    to = AppConfig.has_key?(:email_override_recipient) ? Array(AppConfig[:email_override_recipient]) : [@user[:email]]
    subject = AppConfig[:password_reset_subject]

    body = ERBRenderer
             .new(File.join(File.dirname(__FILE__), '../emails/password_reset_notification.erb.html'))
             .render(binding)

    plaintext_body = Html2Text.convert(body)

    msg = Mail.new do
      to to
      from AppConfig[:email_from_address]
      reply_to reply_to
      subject subject
      html_part do
        content_type 'text/html;charset=UTF-8'
        body body
      end

      text_part do
        body plaintext_body
      end
    end

    if AppConfig[:email_enabled]
      msg.deliver
    else
      $LOG.info(msg)
    end
  end


  class ERBRenderer
    def initialize(erb_file)
      @file = erb_file
    end

    def render(b)
      renderer = ERB.new(File.read(@file))
      renderer.result(b).strip
    end
  end

end
