class FormHelper
  def self.hidden_authenticity_token
    '<input type="hidden" name="authenticity_token" value="%s" />' % [Ctx.session[:csrf]]
  end
end
