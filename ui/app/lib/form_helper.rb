class FormHelper
  def self.hidden_authenticity_token
    '<input type="hidden" name="authenticity_token" value="%s" />' % [csrf_token]
  end

  def self.csrf_token
    Ctx.session[:csrf]
  end

  def self.lock_version(dto, path = nil)
    if path.nil?
      path = 'lock_version'
    else
      path = "#{path}[lock_version]"
    end

    '<input type="hidden" name="%s" value="%s" />' % [path, dto.fetch('lock_version', 0)]
  end
end
