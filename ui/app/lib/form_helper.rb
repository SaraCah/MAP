class FormHelper
  def self.hidden_authenticity_token
    '<input type="hidden" name="authenticity_token" value="%s" />' % [csrf_token]
  end

  def self.csrf_token
    Ctx.session[:csrf]
  end
end
