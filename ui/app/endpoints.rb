class MAPTheApp < Sinatra::Base

  Endpoint.get('/') do
    if Ctx.session
      # These tags get escaped...
      Templates.emit(:hello, :name => "<b>World</b>")
    else
      Templates.emit_with_layout(:login, 'layout')
    end
  end

  Endpoint.get('/js/*') do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('js', filename))
      send_file file
    elsif File.exist?(file = File.join('buildjs', filename))
      send_file file
    else
      [404]
    end
  end

  Endpoint.get('/css/*') do
    filename = request.path.split('/').last
    if File.exist?(file = File.join('css', filename))
      send_file file
    else
      [404]
    end
  end

end
