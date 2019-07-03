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

  ERROR_LABELS_FOR_CODE = {
    'UNIQUE_CONSTRAINT' => "name is already in use.  Please choose another.",
    'AGENCY_NOT_FOUND' => "the requested agency could not be found.",
    'REQUIRED_VALUE_MISSING' => "can't be blank",
  }

  def self.render_errors(errors)
    return "" if errors.empty?

    result = ""

    result << '<div class="form-errors card-panel red lighten-4">'
    result << '<ul>'
    result << errors.map {|error|
      '<li class="error-item"><span class="error-field">%s</span> - <span class="error-text">%s</span></li>' % [
        CGI::escapeHTML(error.fetch('field_label', error.fetch('field'))),
        CGI::escapeHTML(error.fetch('validation_code', ERROR_LABELS_FOR_CODE[error.fetch('code')])),
      ]
    }.join("\n")
    result << '</ul>'
    result << '</div>'

    result
  end
end
